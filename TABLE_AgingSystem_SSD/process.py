#!/usr/bin/env python3

import csv
import pandas as pd

OUTPUT_TABLE = "table-calculated"


def effective_file_size(row: dict) -> int:
    return int(row["file_size"])


def calc_amp(base: dict, row: dict, kind: str) -> float:
    num_blks = effective_file_size(row) * 1024 * 256
    return (int(row[kind]) - int(base[kind])) / num_blks


def calc_bw(row: dict) -> float:
    file_size = effective_file_size(row)
    return (file_size * 1024) / (float(row["time"]) / 1000)


def calc_lat(row: dict) -> float:
    num_blks = effective_file_size(row) * 1024 * 256
    return (float(row["time"]) * 1000 * 1000) / num_blks


def process_table(table: str, writer) -> None:
    with open(table, "r", encoding="utf-8") as handle:
        df = pd.read_csv(handle, delim_whitespace=True, engine="python")

    for blk_size in df["block_size"].unique():
        rows = df[df["block_size"] == blk_size].to_dict("records")
        base = rows[0]
        for row in rows[1:]:
            writer.writerow(
                [
                    "System",
                    row["file_system"],
                    blk_size,
                    calc_amp(base, row, "read"),
                    calc_amp(base, row, "write"),
                    calc_bw(row),
                    calc_lat(row),
                ]
            )


with open(OUTPUT_TABLE, "w", encoding="utf-8", newline="") as output:
    writer = csv.writer(output, delimiter=" ")
    writer.writerow(
        [
            "system",
            "file_system",
            "blk_sz",
            "read_amp",
            "write_amp",
            "throughput(MiB/s)",
            "latency(ns)",
        ]
    )
    process_table("newly_table", writer)
