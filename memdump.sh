#!/bin/bash

CARGO_BIN="."
OUTPUT_DIR="~/"
DSS_PATH="./dbqgen/dss_df.ddl"
SQL_DIR="./queries"
QUERY_ID=0
DF_PID=-5
DUMP_PERIOD=0.1

err() {
    echo >&2 "$1"
    exit 1
}

cleanup() {
    if [ $DF_PID -ge 0 ]; then
        kill -9 $DF_PID
    fi
    rm dfpipe
}

trap cleanup EXIT

heapdump() {
    kill -STOP $DF_PID || err "$0: Process not found, maybe exited. Stop"

    dumptime=$(date +%s%N | cut -b1-13)
    echo "$0: Process paused at $dumptime"

    grep 'rw-p' /proc/$DF_PID/maps | grep -v '/\|stack\|heap\|vdso'    \
    | sed -n 's/^\([0-9a-f]*\)-\([0-9a-f]*\) .*$/\1 \2/p'              \
    | while read start stop; do
        echo "$0: Got heap address: 0x$start, 0x$stop"
        gdb -q --batch --pid $DF_PID -ex                               \
            "append binary memory $OUTPUT_DIR/$QUERY_ID.$dumptime.bin  \
            0x$start 0x$stop" > /dev/null
    done

    pmap $DF_PID > $OUTPUT_DIR/$QUERY_ID.$dumptime.map

    kill -CONT $DF_PID
    echo "$0: Process resumed at $(date +%s%N | cut -b1-13)"
}

run() {
    mkfifo dfpipe
    echo "$0: Pipe created"

    tail -f dfpipe | $CARGO_BIN/datafusion-cli &
    DF_PID=$!
    echo "$0: Pipe connected to datafusion, pid $DF_PID"

    cat $DSS_PATH | while read dss; do
        if [ -n "$dss" ]; then
            echo "$dss" > dfpipe
        fi
    done
    sleep 5
    echo "$0: Databases loaded, start query execution"
    { cat $SQL_DIR/$QUERY_ID.sql; echo "\q"; echo ""; } > dfpipe

    while true; do
        sleep $DUMP_PERIOD
        heapdump
    done
}

# $1 cargo bin path, $2 dss path, $3 sql folder, $4 output folder, $5 queryid, $6 loop delay
if [ $EUID -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

if [ -z "$4" ]; then
    echo "Usage: $0 cargo_bin_path dss_path sql_path output_path queryid [dump_loop_sec]"
    echo "Example: $0 $HOME/.cargo/bin ./dbqgen/dss_df.ddl ./queries ./dbdump 19 0.1"
    exit 1
fi

CARGO_BIN="$1"
DSS_PATH="$2"
SQL_DIR="$3"
OUTPUT_DIR="$4"
QUERY_ID="$5"

if [ -n "$6" ]; then
    DUMP_PERIOD=$6
fi

stat "$DSS_PATH" > /dev/null || err "$0: DSS not found, $DSS_PATH"
stat "$SQL_DIR/$QUERY_ID.sql" > /dev/null || err "$0: Query Dir/SQL file not found"
stat "$CARGO_BIN/datafusion-cli" > /dev/null || err "$0: Datafusion not found"
stat "$OUTPUT_DIR" > /dev/null || mkdir $OUTPUT_DIR

run
