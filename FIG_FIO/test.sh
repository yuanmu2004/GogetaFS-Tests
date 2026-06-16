#!/usr/bin/env bash

# shellcheck source=/dev/null
source "../common.sh"
ABS_PATH=$(where_is_script "$0")
mkdir -p "$ABS_PATH"/M_DATA
DUP_RATES=( 0 25 50 75 )
FILE_SIZE=( $((1 * 1024)) ) # 4 * 1024
NUM_JOBS=( 1 )

FILE_SYSTEMS=( "f2fs" "GogetaFS" "GogetaFS" )
TIMERS=( "fio_f2fs.sh" "fio_f2fs.sh" "fio_f2fs.sh" )
SETUPS=( "setup_f2fs.sh" "setup_f2fs.sh" "setup_f2fs.sh" )
BRANCHES=( "main" "main" "lightdedup" )

TABLE_NAME="$ABS_PATH/performance-comparison-table"
table_create "$TABLE_NAME" "file_system dup_rate num_job bandwidth(MiB/s)"

loop=1
if [ "$1" ]; then
    loop=$1
fi

for ((i = 1; i <= loop; i++)); do
    for dup_rate in "${DUP_RATES[@]}"; do
        STEP=0
        for file_system in "${FILE_SYSTEMS[@]}"; do
            for fsize in "${FILE_SIZE[@]}"; do
                for job in "${NUM_JOBS[@]}"; do
                    TIMER=${TIMERS[$STEP]}
                    SETUP=${SETUPS[$STEP]}

                    echo 1 > /proc/sys/vm/drop_caches
                    echo 2 > /proc/sys/vm/drop_caches
                    echo 3 > /proc/sys/vm/drop_caches

                    if ((dup_rate == 100)); then
                        EACH_SIZE=$(split_workset $((fsize / 2)) "$job")
                        bash ../TOOLS/"$SETUP" "$file_system" "${BRANCHES[$STEP]}" 0
                        sudo mkdir -p /mnt/nvme0n1/first
                        _=$(sudo fio -directory=/mnt/nvme0n1/first -fallocate=none -iodepth 1 -rw=write -ioengine=sync -bs=4K -thread -numjobs="$job" -size="${EACH_SIZE}M" -name=test --dedupe_percentage=0 -group_reporting -randseed="$i" | grep WRITE: | awk '{print $2}' | sed 's/bw=//g' | ../TOOLS/to_MiB_s)
                        sudo mkdir -p /mnt/nvme0n1/second
                        BW=$(sudo fio -directory=/mnt/nvme0n1/second -fallocate=none -iodepth 1 -rw=write -ioengine=sync -bs=4K -thread -numjobs="$job" -size="${EACH_SIZE}M" -name=test --dedupe_percentage=0 -group_reporting -randseed="$i" -fsync=1 -runtime=10s | grep WRITE: | awk '{print $2}' | sed 's/bw=//g' | ../TOOLS/to_MiB_s)
                    else
                        EACH_SIZE=$(split_workset "$fsize" "$job")
                        BW=$(bash ../TOOLS/"$TIMER" "$file_system" "$job" "${EACH_SIZE}"M "$dup_rate" "${BRANCHES[$STEP]}" "0" | grep WRITE: | awk '{print $2}' | sed 's/bw=//g' | ../TOOLS/to_MiB_s)
                    fi

                    fs_name="$file_system"-"${BRANCHES[$STEP]}"
                    table_add_row "$TABLE_NAME" "$fs_name $dup_rate $job $BW"
                done
            done
            STEP=$((STEP + 1))
        done
    done
done
