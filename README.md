## Dependencies

- Cargo
  - hyperfine
- Conda
  - arrow

## Environment

- Cloning the Repo
```bash
git clone https://github.com/Viyerelu23333/df-mc
git submodule update --init --remote
```

- Installing Hyperfine
```bash
cargo install hyperfine
```

- Installing Datafusion-CLI
```bash
cd arrow-datafusion/datafusion-cli
cargo install --path .
```

- Installing PyArrow and Datafusion
```bash
conda create -n arrow python=3.9
conda activate arrow
conda install -c conda-forge pyarrow
pip install datafusion
```

## Usage

- Generating DB and Queries
```bash
chmod +x dbqgen.sh
./dbqgen.sh [-s ScaleFactor] [-o OutputDir] [-e DbgenDir] [-qd]
```

Examples:
```bash
# generate random queries with sf 0.25, output at `./dbqgen`,
# dbgen executable at `./dbgen`
./dbqgen.sh -s 0.25

# generate default queries with sf 0.25, output at `./dbqgen`,
# dbgen executable at `./dbgen`
./dbqgen.sh -s 0.25 -qd
```

- Parsing the Generated Tables to Parquets
```bash
python ./tblpar.py <SOURCE DIR> <OUTPUT DIR>
```

Examples:
```bash
# parse the `.tbl`s in `./dbqgen` and output `.parquet` and `dss_df.ddl`
# to `./dbqgen`
python ./tblpar.py ./dbqgen ./dbqgen
```

- Dumping the Memory with Specific Query
```bash
chmod +x memdump.sh
sudo ./memdump.sh <CARGO PATH> <DSS PATH> <DUMP FOLDER> <SQL PATH> <DUMP PERIOD>
```

Examples:
```bash
# dump the memory using datafusion-cli in user's cargo path, with `./queries/1.sql`
# the dumping occurs every 0.01s, and output binaries to `./dbdump`
sudo ./memdump.sh ~user/.cargo/bin ./dbqgen/dss_df.ddl ./queries ./dbdump 1 0.01

# dump the memory using df-cli in user's path, with `./queries/19.sql` and
# `./queries/19.dss`, the dumping occurs every 1s, and output to `~root`
sudo ./memdump.sh ~user/.cargo/bin ./queries/1.ddl ~
```

- Compressing and Benchmarking the Binaries with GZip
```bash
chmod +x compbench.sh
./compbench.sh compress|benchmark|compbench [-p split_path] [-s split_size] [filename]
```

Examples:
```bash
# Compress any binaries in `./dbdump` with 4096B block size and benchmark
./compbench.sh compbench

# Just compress `./dbdump/23.3333333333.bin` with 8192B block size level 4,
# keep the compressed files
./compbench.sh compress -p ./dbdump 23.3333333333.bin -s 8192 -k -r 4 4
```
