#!/usr/bin/env bash

CARGO_BIN="."
OUTPUT_DIR="~/"
DSS_PATH="./dbqgen/dss_df.ddl"
DSS_QUERY=
QUERY_ID=0
DF_PID=-5
DUMP_PERIOD=0.1

err() {
    echo >&2 "$1"
    exit 1
}

cleanup() {
    chown -R 1000:1000 $OUTPUT_DIR
    if [ $DF_PID -ge 0 ]; then
        kill -9 $DF_PID
    fi
    rm dfpipe
}

heapdump() {
    kill -STOP $DF_PID || err "$0: Process not found, maybe exited. Stop"
    dumpTime=$(date +%s%N | cut -b1-13)

    echo "$0: Process paused at $dumpTime"

    grep 'rw-p' /proc/$DF_PID/maps | grep -v '/\|stack\|heap\|vdso'    \
    | sed -n 's/^\([0-9a-f]*\)-\([0-9a-f]*\) .*$/\1 \2/p'              \
    | while read start stop; do
        echo "$0: Got heap address: 0x$start, 0x$stop"
        gdb -q --batch --pid $DF_PID -ex                               \
            "append binary memory $OUTPUT_DIR/$QUERY_ID.$dumpTime.bin  \
            0x$start 0x$stop" > /dev/null
    done

    pmap $DF_PID > $OUTPUT_DIR/$QUERY_ID.$dumpTime.map

    kill -CONT $DF_PID
    resumeTime=$(date +%s%N | cut -b1-13)
    echo "$0: Process resumed at $resumeTime" &
    echo "$dumpTime,$resumeTime" >> $OUTPUT_DIR/$QUERY_ID.csv &
}

run() {
    echo "dumpStartAt,dumpStopAt" >> $OUTPUT_DIR/$QUERY_ID.csv

    mkfifo dfpipe || err "$0: Failed to create pipe"
    echo "$0: Pipe created"

    tail -f dfpipe | $CARGO_BIN/datafusion-cli &
    DF_PID=$!
    echo "$0: Pipe connected to datafusion, pid $DF_PID"

    cat $DSS_PATH | while read dss; do
        if [ -n "$dss" ]; then
            echo "$dss" > dfpipe
        fi
    done

    [ -n $DSS_QUERY ] && {
        cat $DSS_QUERY | while read dss; do
            if [ -n "$dss" ]; then
                echo "$dss" > dfpipe
            fi
        done
    }

    sleep 5
    echo "$0: Databases loaded, start query execution"
    { cat $QUERY; echo "\q"; echo ""; } > dfpipe

    while true; do
        sleep $DUMP_PERIOD
        heapdump
    done
}

if [ $EUID -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

if [ -z "$4" ]; then
    echo "Usage: $0 cargo_bin_path dss_path output_path query_path dump_loop_sec [query_ddl]"
    echo "Example: $0 $HOME/.cargo/bin ./dbqgen/dss_df.ddl ./dbdump ./queries/19.sql 0.1"
    echo "Example: $0 $HOME/.cargo/bin ./dbqgen/dss_df_mem.ddl ./dbdump ./queries/19.sql 0.1 ./queries/19.ddl"
    exit 1
fi

trap cleanup EXIT

CARGO_BIN="$1"
DSS_PATH="$2"
OUTPUT_DIR="$3"
QUERY="$4"
QUERY_ID=$(basename $4 .sql)
DUMP_PERIOD=$5

if [ -n "$6" ]; then
    DSS_QUERY="$6"
fi

stat "$DSS_PATH" > /dev/null || err "$0: DSS not found, $DSS_PATH"
stat "$QUERY" > /dev/null || err "$0: SQL file not found"
stat "$CARGO_BIN/datafusion-cli" > /dev/null || err "$0: Datafusion not found"
stat "$OUTPUT_DIR" > /dev/null || mkdir $OUTPUT_DIR

run
