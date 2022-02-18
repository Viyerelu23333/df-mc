#!/bin/python3

import pyarrow as pa
import pyarrow.parquet as pp
import pyarrow.csv as pc
import sys

NATION =    (("N_NATIONKEY", pa.int32()),
             ("N_NAME", pa.string()),
             ("N_REGIONKEY", pa.int32()),
             ("N_COMMENT", pa.string()))

REGION =    (("R_REGIONKEY", pa.int32()),
             ("R_NAME", pa.string()),
             ("R_COMMENT", pa.string()))

PART =      (("P_PARTKEY", pa.int32()),
             ("P_NAME", pa.string()),
             ("P_MFGR", pa.string()),
             ("P_BRAND", pa.string()),
             ("P_TYPE", pa.string()),
             ("P_SIZE", pa.int32()),
             ("P_CONTAINER", pa.string()),
             ("P_RETAILPRICE", pa.decimal128(15, 2)),
             ("P_COMMENT", pa.string()))

SUPPLIER =  (("S_SUPPKEY", pa.int32()),
             ("S_NAME", pa.string()),
             ("S_ADDRESS", pa.string()),
             ("S_NATIONKEY", pa.int32()),
             ("S_PHONE", pa.string()),
             ("S_ACCTBAL", pa.decimal128(15, 2)),
             ("S_COMMENT", pa.string()))

PARTSUPP = (("PS_PARTKEY", pa.int32()),
            ("PS_SUPPKEY", pa.int32()),
            ("PS_AVAILQTY", pa.int32()),
            ("PS_SUPPLYCOST", pa.decimal128(15, 2)),
            ("PS_COMMENT", pa.string()))

CUSTOMER =  (("C_CUSTKEY", pa.int32()),
             ("C_NAME", pa.string()),
             ("C_ADDRESS", pa.string()),
             ("C_NATIONKEY", pa.int32()),
             ("C_PHONE", pa.string()),
             ("C_ACCTBAL", pa.decimal128(15, 2)),
             ("C_MKTSEGMENT", pa.string()),
             ("C_COMMENT", pa.string()))

ORDERS =    (("O_ORDERKEY", pa.int32()),
             ("O_CUSTKEY", pa.int32()),
             ("O_ORDERSTATUS", pa.string()),
             ("O_TOTALPRICE", pa.decimal128(15, 2)),
             ("O_ORDERDATE", pa.date32()),
             ("O_ORDERPRIORITY", pa.string()),
             ("O_CLERK", pa.string()),
             ("O_SHIPPRIORITY", pa.int32()),
             ("O_COMMENT", pa.string()))

LINEITEM =  (("L_ORDERKEY", pa.int32()),
             ("L_PARTKEY", pa.int32()),
             ("L_SUPPKEY", pa.int32()),
             ("L_LINENUMBER", pa.int32()),
             ("L_QUANTITY", pa.decimal128(15, 2)),
             ("L_EXTENDEDPRICE", pa.decimal128(15, 2)),
             ("L_DISCOUNT", pa.decimal128(15, 2)),
             ("L_TAX", pa.decimal128(15, 2)),
             ("L_RETURNFLAG", pa.string()),
             ("L_LINESTATUS", pa.string()),
             ("L_SHIPDATE", pa.date32()),
             ("L_COMMITDATE", pa.date32()),
             ("L_RECEIPTDATE", pa.date32()),
             ("L_SHIPINSTRUCT", pa.string()),
             ("L_SHIPMODE", pa.string()),
             ("L_COMMENT", pa.string()))


def convert_file(file_name : str, target_name : str, schema : tuple) -> tuple:
    pp.write_table(
        pc.read_csv(file_name,
                    pc.ReadOptions(column_names = [k[0].lower() for k in schema]),
                    pc.ParseOptions(delimiter = '|'),
                    pc.ConvertOptions(column_types = {k[0].lower(): k[1] for k in schema})
        ),
        target_name
    )

    return (file_name.split('/')[-1].split('.')[-2], target_name)


def convert_ddl(file_name : str, tables : tuple) -> None:
    fd = open(file_name, 'w')
    for tbl in tables:
        fd.write("CREATE EXTERNAL TABLE " + tbl[0] +
                 "\nSTORED AS PARQUET\nLOCATION '" + tbl[1] + "';\n\n")
    fd.close()


def parse_convert(directory : str, outputdir : str) -> None:
    parq = (convert_file(directory + "/nation.tbl", outputdir + "/nation.parquet", NATION),
            convert_file(directory + "/region.tbl", outputdir + "/region.parquet", REGION),
            convert_file(directory + "/part.tbl", outputdir + "/part.parquet", PART),
            convert_file(directory + "/supplier.tbl", outputdir + "/supplier.parquet", SUPPLIER),
            convert_file(directory + "/partsupp.tbl", outputdir + "/partsupp.parquet", PARTSUPP),
            convert_file(directory + "/customer.tbl", outputdir + "/customer.parquet", CUSTOMER),
            convert_file(directory + "/orders.tbl", outputdir + "/orders.parquet", ORDERS),
            convert_file(directory + "/lineitem.tbl", outputdir + "/lineitem.parquet", LINEITEM))

    convert_ddl(outputdir + "/dss_df.ddl", parq)


if __name__ == "__main__":
    directory = sys.argv[1]
    outputdir = sys.argv[2]
    parse_convert(directory, outputdir)
