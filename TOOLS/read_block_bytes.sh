#!/usr/bin/env bash

set -e

if [ ! "$1" ]; then
    echo "Usage: $0 block_device_name_or_path"
    exit 1
fi

device_name=$(basename "$1")
stat_path="/sys/block/$device_name/stat"

if [ ! -r "$stat_path" ]; then
    echo "Cannot read block statistics from $stat_path" >&2
    exit 1
fi

read_bytes=$(awk '{print $3 * 512}' "$stat_path")
write_bytes=$(awk '{print $7 * 512}' "$stat_path")

echo "MediaReads $read_bytes"
echo "MediaWrites $write_bytes"
