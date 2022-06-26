#!/usr/bin/env bash

SF=2
OUT_DIR='./dbqgen'
EXEC_DIR='./dbgen'
CWD=$(pwd)
QGEND=''

err() {
    echo >&2 "$1"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--scale-factor)
            SF=$2
            shift 2
            ;;
        -o|--output-dir)
            OUT_DIR=$2
            shift 2
            ;;
        -e|--exec-dir)
            EXEC_DIR=$2
            shift 2
            ;;
        -qd|--qgen-default)
            QGEND='-d'
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Possible options: -s <ScaleFactor> -o <OutputDir> -e <ExecutableDir> [-qd]"
            exit 1
    esac
done

echo "$0: Switching to dbgen executable directory"
cd "$EXEC_DIR" || err "Failed to locate executable directory"

make -j"$(nproc)" || err "Failed to compile dbgen"

./dbgen -vf -s "$SF" || err "dbgen failed"

echo "$0: dbgen OK, moving databases"
mkdir --parents "$CWD/$OUT_DIR"
mv -f -- *.tbl "$_" || err "Move tables failed"

echo "$0: Move OK, starting qgen"
cd "queries" || err "Failed to locate queries directory"

mkdir --parents "$CWD/$OUT_DIR/queries" || err "Failed to make folder"

for sql in {1..22}; do
    ../qgen -b ../dists.dss -s "$SF" $QGEND "$sql" > "$CWD/$OUT_DIR/queries/$sql.sql" || err "Failed to qgen $sql.sql"
done

cd "../variants" || err "Failed to locate query variants"

for vsql in {8a,12a,13a,14a,15a}; do
    ../qgen -b ../dists.dss -s "$SF" $QGEND "$vsql" > "$CWD/$OUT_DIR/queries/$vsql.sql" || err "Failed to qgen $vsql.sql"
done

cd "$CWD"
echo "$0: Done"
