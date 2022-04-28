#!/usr/bin/env sh

BLOCK_SIZE=4096
SPLIT_PATH=./dbdump
SPLIT_FILE=

CMPRS=0
BENCH=0
RMFILE=1

GZ_LOWER=1
GZ_UPPER=9


err() {
    echo >&2 "$1"
    exit 1
}

benchmark() {
    echo "$0: Benchmarking $1"
    hyperfine -w 5 -m 5 --export-csv $SPLIT_PATH/$1_bench.csv          \
        -P GZIP_CMPLV $GZ_LOWER $GZ_UPPER -u millisecond               \
        "parallel --pipe-part --recend '' -a $SPLIT_PATH/$1            \
            --block $BLOCK_SIZE -q                                     \
                gzip -c -{GZIP_CMPLV} > /dev/null"
}

compress() {
    if [ ! -e "$SPLIT_PATH/$1_gzip.csv" ]; then
        echo "gzipLevel,blockSize,originalSize,compressedSize" > $SPLIT_PATH/$1_gzip.csv
    fi

    for ((GZIP_CMPLV=$GZ_LOWER; GZIP_CMPLV<=$GZ_UPPER; GZIP_CMPLV++)); do
        echo "$0: Compressing $1 with GZIP level $GZIP_CMPLV, block size $BLOCK_SIZE"

        echo -n "$GZIP_CMPLV,$BLOCK_SIZE," >> $SPLIT_PATH/$1_gzip.csv
        echo -n "$(du -b $SPLIT_PATH/$1 | awk '{print $1}')," >> $SPLIT_PATH/$1_gzip.csv
        parallel --pipe-part --recend '' -a $SPLIT_PATH/$1 --block $BLOCK_SIZE --eta -q \
            gzip -c -$GZIP_CMPLV | wc -c >> $SPLIT_PATH/$1_gzip.csv

        [ $RMFILE -eq 1 ] && rm -f $SPLIT_PATH/$1.$GZIP_CMPLV.gz
    done
}

compbench() {
    if [ -n "$SPLIT_FILE" ]; then
        [ $CMPRS -eq 1 ] && {
            compress $SPLIT_FILE
        }
        [ $BENCH -eq 1 ] && {
            benchmark $SPLIT_FILE
        }
    else
        for file in $SPLIT_PATH/*.bin; do
            [ $CMPRS -eq 1 ] && {
                compress $(basename $file)
            }
            [ $BENCH -eq 1 ] && {
                benchmark $(basename $file)
            }
        done
    fi
}

case $1 in
    compress)
        CMPRS=1
        ;;
    benchmark)
        BENCH=1
        ;;
    compbench)
        CMPRS=1
        BENCH=1
        ;;
    *)
        err "Usage: $0 compress|benchmark|compbench [-p split_path] [-s BLOCK_SIZE] [-k] [-r GZ_LOWER GZ_UPPER] [filename]"
        ;;
esac
shift

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
        -k|--keep-gz)
            RMFILE=0
            shift
            ;;
        -r|--range)
            GZ_LOWER=$2
            GZ_UPPER=$3
            shift 3
            ;;
        *)
            SPLIT_FILE=$1
            shift
            ;;
    esac
done

if [ -n "$SPLIT_FILE" ]; then
    echo "$0: File specified, use single file mode"
    stat $SPLIT_PATH/$SPLIT_FILE > /dev/null\
        || err "$0: Cannot access $SPLIT_PATH/$SPLIT_FILE"
fi

hyperfine -V > /dev/null || err "$0: Hyperfine not detected"
parallel -V > /dev/null || err "$0: GNU/Parallel not detected"
stat $SPLIT_PATH > /dev/null || err "$0: Cannot access $SPLIT_PATH"

trap exit INT

compbench
