#!/usr/bin/env bash

BLOCK_SIZE=4096
SPLIT_PATH=./dbdump
SPLIT_FILE=

GZ_LOWER=1
GZ_UPPER=9


err() {
    echo >&2 "$1"
    exit 1
}

compress() {
    if [ ! -e "$SPLIT_PATH/$1_gzip.csv" ]; then
        echo "gzipLevel,blockSize,originalSize,compressedSize,totalBlock,rs0,rs10,rs20,rs30,rs40,rs50,rs60,rs70,rs80,rs90,rs100" > "$SPLIT_PATH/$1_gzip.csv"
    fi

    for ((GZIP_CMPLV=GZ_LOWER; GZIP_CMPLV<=GZ_UPPER; GZIP_CMPLV++)); do
        echo "$0: Compressing $1 with GZIP level $GZIP_CMPLV, block size $BLOCK_SIZE"
        compressor "$GZIP_CMPLV" "$BLOCK_SIZE" "$SPLIT_PATH/$1" >> "$SPLIT_PATH/$1_gzip.csv"
    done
}

compbench() {
    if [ -n "$SPLIT_FILE" ]; then
        compress "$SPLIT_FILE"
    else
        for file in "$SPLIT_PATH"/*.bin; do
            compress "$(basename "$file")"
        done
    fi
}


while [ $# -gt 0 ]; do
    case $1 in
        -p|--path)
            SPLIT_PATH=$2
            shift 2
            ;;
        -s|--split-size)
            BLOCK_SIZE=$2
            shift 2
            ;;
        -r|--range)
            GZ_LOWER=$2
            GZ_UPPER=$3
            shift 3
            ;;
        -h|--help)
            err "Usage: $0 [-p split_path] [-s BLOCK_SIZE] [-r GZ_LOWER GZ_UPPER] [filename]"
            ;;
        *)
            SPLIT_FILE=$1
            shift
            ;;
    esac
done

if [ -n "$SPLIT_FILE" ]; then
    echo "$0: File specified, use single file mode"
    stat "$SPLIT_PATH/$SPLIT_FILE" > /dev/null\
        || err "$0: Cannot access $SPLIT_PATH/$SPLIT_FILE"
fi

stat compressor > /dev/null || err "$0: Compressor not detected, did you run 'cargo install'?"
stat "$SPLIT_PATH" > /dev/null || err "$0: Cannot access $SPLIT_PATH"

trap exit INT

compbench
