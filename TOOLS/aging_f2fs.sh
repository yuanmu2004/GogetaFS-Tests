#!/usr/bin/env bash

set -e

if [ ! "$5" ]; then
    echo "Usage: $0 fs_dir branch_name file_size_gib aging_hole_percent block_size_bytes [device_name]"
    exit 1
fi

ABSPATH=$(cd "$( dirname "$0" )" && pwd)

fs_dir=$1
branch_name=$2
file_size_gib=$3
aging_hole=$4
block_size=$5
device_name=${6:-nvme0n1}

bash "$ABSPATH"/setup_f2fs.sh "$fs_dir" "$branch_name" 0
make -C "$ABSPATH" aging_system >/dev/null

sample_device_bytes() {
    bash "$ABSPATH"/read_block_bytes.sh "$device_name"
}

calc_delta() {
    local before=$1
    local after=$2
    paste "$before" "$after" | awk '{print $1, ($4 - $2)}'
}

sync
before_phase1=$(mktemp)
after_phase1=$(mktemp)

sample_device_bytes > "$before_phase1"
phase1_output=$(sudo "$ABSPATH"/aging_system -d /mnt/nvme0n1 -s "$file_size_gib" -o "$aging_hole" -b "$block_size" -p 1)
sync
sample_device_bytes > "$after_phase1"
calc_delta "$before_phase1" "$after_phase1"

newly_write_time=$(echo "$phase1_output" | grep NewlyWriteTime | awk '{print $2}')

echo "NewlyWriteTime $newly_write_time"

rm -f "$before_phase1" "$after_phase1"
