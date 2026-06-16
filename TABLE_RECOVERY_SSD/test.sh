#!/usr/bin/env bash

set -e

# shellcheck source=/dev/null
source "../common.sh"

ABS_PATH=$(where_is_script "$0")
mkdir -p "$ABS_PATH"/M_DATA

FS_LABELS=(
    "Gogeta-NORMAL" "Gogeta-FAILURE"
    "Light-Dedup-NORMAL" "Light-Dedup-FAILURE"
)
FS_DIRS=(
    "GogetaFS" "GogetaFS"
    "GogetaFS" "GogetaFS"
)
BRANCHES=(
    "main" "main-failure"
    "lightdedup" "lightdedup-failure"
)

WORKLOAD_NAMES=( "fio" "homes" "os" "web" "mail" )
WORKLOAD_DUP_RATES=( "75" "69" "84" "47" "95" )
WORKLOAD_TYPES=( "fio" "trace" "trace" "trace" "trace" )

TABLE_NAME="$ABS_PATH/performance-comparison-table"
table_create "$TABLE_NAME" "file_system workload umount_time recovery"

loop=1
if [ "$1" ]; then
    loop=$1
fi

measure_real_seconds() {
    local cmd=$1
    { time -p bash -lc "$cmd"; } 2>&1 | awk '/^real/ {print $2}'
}

run_workload() {
    local fs_dir=$1
    local branch=$2
    local workload_type=$3
    local dup_rate=$4

    if [ "$workload_type" = "fio" ]; then
        bash ../TOOLS/fio_f2fs.sh "$fs_dir" 1 "1024M" "$dup_rate" "$branch" "0" 4K 1 >/dev/null
    else
        bash ../TOOLS/fio_f2fs_trace.sh "$fs_dir" 1 "1024M" "$dup_rate" "$branch" "0" 4K 1 1 >/dev/null
    fi
}

for ((i=1; i <= loop; i++)); do
    STEP=0
    for fs_label in "${FS_LABELS[@]}"; do
        for workload_idx in "${!WORKLOAD_NAMES[@]}"; do
            bash ../TOOLS/setup_f2fs.sh "${FS_DIRS[$STEP]}" "${BRANCHES[$STEP]}" 0 >/dev/null
            run_workload "${FS_DIRS[$STEP]}" "${BRANCHES[$STEP]}" "${WORKLOAD_TYPES[$workload_idx]}" "${WORKLOAD_DUP_RATES[$workload_idx]}"
            sync
            umount_time=$(measure_real_seconds "sudo umount /mnt/nvme0n1")
            recovery_time=$(measure_real_seconds "sudo mount -t f2fs /dev/nvme0n1 /mnt/nvme0n1")
            table_add_row "$TABLE_NAME" "$fs_label ${WORKLOAD_NAMES[$workload_idx]} $umount_time $recovery_time"
        done
        STEP=$((STEP + 1))
    done
done
