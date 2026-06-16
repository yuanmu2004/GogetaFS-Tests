#!/usr/bin/env bash

set -e

# shellcheck source=/dev/null
source "../common.sh"
ABS_PATH=$(where_is_script "$0")
mkdir -p "$ABS_PATH"/M_DATA

FILE_SYSTEMS=( "f2fs" "GogetaFS" "GogetaFS" )
SETUPS=( "setup_f2fs.sh" "setup_f2fs.sh" "setup_f2fs.sh" )
BRANCHES=( "main" "main" "lightdedup" )

TRACE_DIR=${REALWORLD_TRACE_DIR:-/home/ubuntu/RealWorld_Traces}
CP_SRC=${REALWORLD_CP_SRC:-/usr/src/linux-headers-$(uname -r)}

NAMES=(
    "cp"
    "homes-2022-fall-50.hitsztrace"
    "webmail+online.cs.fiu.edu-110108-113008.1-21.blkparse"
    "cheetah.cs.fiu.edu-110108-113008.1.blkparse"
)
TYPES=( "cp" "trace" "trace" "trace" )
TRACES=(
    "$CP_SRC"
    "$TRACE_DIR/homes-2022-fall-50.hitsztrace"
    "$TRACE_DIR/webmail+online.cs.fiu.edu-110108-113008.1-21.blkparse"
    "$TRACE_DIR/cheetah.cs.fiu.edu-110108-113008.1.blkparse"
)
FMTS=( "" "hitsz" "fiu" "fiu" )
MODES=( "" "rw" "rw" "rw" )

MAX_C_BLKS=( 1 )
NUM_JOBS=( 1 )

TABLE_NAME="$ABS_PATH/performance-comparison-table-no-sync"
table_create "$TABLE_NAME" "file_system workload cblks job bandwidth(MiB/s)"

loop=1
if [ "$1" ]; then
    loop=$1
fi

measure_cp_bw() {
    local src=$1
    local job=$2
    local dst="/mnt/nvme0n1/realworld-cp-$job"
    local size_mib
    local seconds

    if [ ! -e "$src" ]; then
        echo "missing cp source: $src" >&2
        exit 1
    fi

    size_mib=$(du -sm "$src" | awk '{print $1}')
    sudo rm -rf "$dst"
    seconds=$(/usr/bin/time -f %e sudo cp -a "$src" "$dst" 2>&1 >/dev/null)
    python3 - "$size_mib" "$seconds" <<'PY'
import sys
size = float(sys.argv[1])
seconds = float(sys.argv[2])
print(f"{size / seconds:.2f}")
PY
}

run_trace() {
    local trace=$1
    local mode=$2
    local fmt=$3
    local job=$4
    local cblks=$5

    if [ ! -f "$trace" ]; then
        echo "missing trace: $trace" >&2
        exit 1
    fi

    ../TOOLS/replay -f "$trace" -d /mnt/nvme0n1/ -o "$mode" -g null -t "$job" -c "$cblks" -m "$fmt" |
        awk '/Bandwidth:/ {print $9}'
}

echo 4 > /proc/sys/vm/dirty_ratio
echo 2 > /proc/sys/vm/dirty_background_ratio

for ((i=1; i <= loop; i++)); do
    for cblks in "${MAX_C_BLKS[@]}"; do
        for job in "${NUM_JOBS[@]}"; do
            STEP=0
            for file_system in "${FILE_SYSTEMS[@]}"; do
                WORKLOAD_ID=0
                for workload in "${NAMES[@]}"; do
                    echo 1 > /proc/sys/vm/drop_caches
                    echo 2 > /proc/sys/vm/drop_caches
                    echo 3 > /proc/sys/vm/drop_caches
                    sleep 1

                    bash ../TOOLS/"${SETUPS[$STEP]}" "$file_system" "${BRANCHES[$STEP]}" 0

                    if [ "${TYPES[$WORKLOAD_ID]}" = "cp" ]; then
                        BW=$(measure_cp_bw "${TRACES[$WORKLOAD_ID]}" "$job")
                    else
                        BW=$(run_trace "${TRACES[$WORKLOAD_ID]}" "${MODES[$WORKLOAD_ID]}" "${FMTS[$WORKLOAD_ID]}" "$job" "$cblks")
                    fi

                    table_add_row "$TABLE_NAME" "$file_system-${BRANCHES[$STEP]} $workload $cblks $job $BW"
                    WORKLOAD_ID=$((WORKLOAD_ID + 1))
                done
                STEP=$((STEP + 1))
            done
        done
    done
done

echo 20 > /proc/sys/vm/dirty_ratio
echo 10 > /proc/sys/vm/dirty_background_ratio
