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

for var in "${vars[@]}"; do
    echo "Starting download: $var"

    uv run python icenet/download_era5_data.py --var "$var" 2>&1 \
        | tee "logs/era5_download_logs/${var}.txt" \
        | sed "s/^/[$var] /" &

    pids+=($!)
done

echo "Started ${#pids[@]} downloads"

# Wait for all jobs and report status
failed=0

for i in "${!pids[@]}"; do
    pid=${pids[$i]}
    var=${vars[$i]}

    if wait "$pid"; then
        echo "✓ Finished: $var"
    else
        echo "✗ Failed: $var"
        failed=1
    fi
done

if [ $failed -eq 0 ]; then
    echo "All downloads completed successfully."
else
    echo "Some downloads failed. Check logs/era5_download_logs/"
fi
