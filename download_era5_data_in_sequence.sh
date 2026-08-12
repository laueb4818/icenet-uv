#!/bin/bash

set -e

uv run icenet/download_era5_data.py --var tas
uv run icenet/download_era5_data.py --var tos
uv run icenet/download_era5_data.py --var ta500
uv run icenet/download_era5_data.py --var rsds_and_rsus
uv run icenet/download_era5_data.py --var psl
uv run icenet/download_era5_data.py --var zg500
uv run icenet/download_era5_data.py --var zg250
uv run icenet/download_era5_data.py --var ua10
uv run icenet/download_era5_data.py --var uas
uv run icenet/download_era5_data.py --var vas
