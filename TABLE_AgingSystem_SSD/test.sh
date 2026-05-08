#!/usr/bin/env bash

set -e

# shellcheck source=/dev/null
source "../common.sh"

ABS_PATH=$(where_is_script "$0")
mkdir -p "$ABS_PATH"/M_DATA

FILE_SIZE=(16)
BSS=(4096 $((2 * 1024 * 1024)))

FS_LABELS=( "F2FS" "HFDedup" "SmartDedup" "FDM" "Light-Dedup" )
FS_DIRS=( "f2fs" "HFDedup2" "smartdedup" "GogetaFS" "GogetaFS" )
BRANCHES=( "main" "hfdedup" "smartdedup" "main" "lightdedup" )

TABLE_NAME="$ABS_PATH/newly_table"
table_create "$TABLE_NAME" "file_system file_size block_size read write time"

loop=1
if [ "$1" ]; then
    loop=$1
fi

for ((i=1; i <= loop; i++)); do
    for bs in "${BSS[@]}"; do
        STEP=0
        for fs_label in "${FS_LABELS[@]}"; do
            for fsize in "${FILE_SIZE[@]}"; do
                output=$(bash ../TOOLS/aging_f2fs.sh "${FS_DIRS[$STEP]}" "${BRANCHES[$STEP]}" "$fsize" 50 "$bs" "nvme0n1")

                read_bytes=$(echo "$output" | grep MediaReads | awk 'NR==1 {print $2}')
                write_bytes=$(echo "$output" | grep MediaWrites | awk 'NR==1 {print $2}')
                write_time=$(echo "$output" | grep NewlyWriteTime | awk '{print $2}')

                table_add_row "$TABLE_NAME" "$fs_label $fsize $bs $read_bytes $write_bytes $write_time"
            done
            STEP=$((STEP + 1))
        done
    done
done
