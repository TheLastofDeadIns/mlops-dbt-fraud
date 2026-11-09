"""Создаёт таблицу transactions_db.transactions в ClickHouse и загружает в неё CSV с транзакциями.

Нужен, если таблицы из домашки по ClickHouse под рукой нет. Понимает два формата файла:
train.csv из соревнования teta-ml-1-2025 (колонки уже названы как в таблице) и исходный датасет Sparkov
fraudTrain.csv / fraudTest.csv с Kaggle (kartik2112/fraud-detection), колонки которого переименовываются.
Файл можно передать как .csv или как .zip с одним csv внутри.

Пример:
    python scripts/load_transactions.py --csv data/train.csv --recreate
"""

import argparse
import os
import time

import clickhouse_connect
import pandas as pd

COLUMNS = [
    "transaction_time",
    "merch",
    "cat_id",
    "amount",
    "name_1",
    "name_2",
    "gender",
    "us_state",
    "lat",
    "lon",
    "merchant_lat",
    "merchant_lon",
    "target",
]

# переименование колонок датасета Sparkov в схему домашки по ClickHouse
SPARKOV_TO_COURSE = {
    "trans_date_trans_time": "transaction_time",
    "merchant": "merch",
    "category": "cat_id",
    "amt": "amount",
    "first": "name_1",
    "last": "name_2",
    "state": "us_state",
    "long": "lon",
    "merch_lat": "merchant_lat",
    "merch_long": "merchant_lon",
    "is_fraud": "target",
}

DDL = """
CREATE TABLE IF NOT EXISTS {database}.{table}
(
    transaction_time DateTime,
    merch String,
    cat_id String,
    amount Float64,
    name_1 String,
    name_2 String,
    gender String,
    us_state String,
    lat Float64,
    lon Float64,
    merchant_lat Float64,
    merchant_lon Float64,
    target UInt8
)
ENGINE = MergeTree
ORDER BY (us_state, transaction_time)
"""


def parse_args():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--csv", required=True, help="путь к train.csv, fraudTrain.csv или zip-архиву с ним")
    parser.add_argument("--host", default=os.getenv("CLICKHOUSE_HOST", "localhost"))
    parser.add_argument("--port", type=int, default=int(os.getenv("CLICKHOUSE_PORT", "8123")))
    parser.add_argument("--user", default=os.getenv("CLICKHOUSE_USER", "default"))
    parser.add_argument("--password", default=os.getenv("CLICKHOUSE_PASSWORD", ""))
    parser.add_argument("--database", default="transactions_db")
    parser.add_argument("--table", default="transactions")
    parser.add_argument("--recreate", action="store_true", help="удалить таблицу перед загрузкой")
    parser.add_argument("--limit", type=int, default=None, help="загрузить только первые N строк")
    parser.add_argument("--chunksize", type=int, default=200_000)
    return parser.parse_args()


def to_course_schema(chunk: pd.DataFrame) -> pd.DataFrame:
    chunk = chunk.rename(columns=SPARKOV_TO_COURSE)
    missing = [column for column in COLUMNS if column not in chunk.columns]
    if missing:
        raise ValueError(f"в файле нет колонок {missing}")
    chunk = chunk[COLUMNS].copy()
    chunk["transaction_time"] = pd.to_datetime(chunk["transaction_time"])
    for column in ["merch", "cat_id", "name_1", "name_2", "gender", "us_state"]:
        chunk[column] = chunk[column].fillna("").astype(str)
    for column in ["amount", "lat", "lon", "merchant_lat", "merchant_lon"]:
        chunk[column] = chunk[column].astype("float64")
    chunk["target"] = chunk["target"].astype("uint8")
    return chunk


def main():
    args = parse_args()
    client = clickhouse_connect.get_client(
        host=args.host, port=args.port, username=args.user, password=args.password
    )
    client.command(f"CREATE DATABASE IF NOT EXISTS {args.database}")
    if args.recreate:
        client.command(f"DROP TABLE IF EXISTS {args.database}.{args.table}")
    client.command(DDL.format(database=args.database, table=args.table))

    started = time.time()
    loaded = 0
    for chunk in pd.read_csv(args.csv, chunksize=args.chunksize, nrows=args.limit):
        frame = to_course_schema(chunk)
        client.insert_df(f"{args.database}.{args.table}", frame)
        loaded += len(frame)
        print(f"загружено {loaded} строк")

    total = client.command(f"SELECT count() FROM {args.database}.{args.table}")
    print(f"готово за {time.time() - started:.1f} с, в {args.database}.{args.table} сейчас {total} строк")


if __name__ == "__main__":
    main()
