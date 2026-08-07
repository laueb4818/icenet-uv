#!/bin/bash

mkdir -p logs/era5_download_logs/

vars=(
    tas
    tos
    ta500
    rsds_and_rsus
    psl
    zg500
    zg250
    ua10
    uas
    vas
)

pids=()

echo "Starting ERA5 downloads: ${vars[*]}"

for var in "${vars[@]}"; do
    echo "Started: $var"

    uv run python icenet/download_era5_data.py --var "$var" \
        >"logs/era5_download_logs/${var}.txt" \
        2>"logs/era5_download_logs/${var}_error.txt" &

    pids+=($!)
done

echo "All processes started."

failed=0

for i in "${!pids[@]}"; do
    pid=${pids[$i]}
    var=${vars[$i]}

    if wait "$pid"; then
        echo "Finished: $var"
    else
        echo "FAILED: $var (see logs/era5_download_logs/${var}_error.txt)"
        failed=1
    fi
done

if [ "$failed" -eq 0 ]; then
    echo "All ERA5 downloads finished."
else
    echo "Some ERA5 downloads failed."
fi
