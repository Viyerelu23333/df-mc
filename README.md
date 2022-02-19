## Environment
- Cloning the Repo
```bash
git clone https://github.com/Viyerelu23333/df-mc
git submodule update --init --remote
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

- Generating DB and Queries
```bash
chmod +x dbqgen.sh
./dbqgen.sh -s 0.25
```

- Execute Queries
```bash
datafusion-cli < dbqgen/dss_df.ddl < queries/{1,2,3,4,5}.sql
```
