# Updated Codebase for "IceNet: Seasonal Arctic sea ice forecasting with probabilistic deep learning"

This repository contains an updated version of the original [_IceNet implementation by Tom Andersson_](https://github.com/tom-andersson/icenet-paper), main author of the Nature Communications paper [_Seasonal Arctic sea ice forecasting with probabilistic deep learning_](https://www.nature.com/articles/s41467-021-25257-4).
Due to outdated packages and changes in the data structure which is provided by the API servers, the original implementation runs into several issues. Further, the repository does not support modern apple silicon chips of the M-series.
Thus, in this repository, we have updated the implementation and dependency structure by:

- updating from python 3.7 to 3.11,
- moving from conda to an uv managed environment,
- adding support for apple silicon with OS-agnostic package installation and GPU selection,
- modified downloading and pre-processing scripts to account for new data structure on server-side of the API and
- updated function calls according to newer package versions.

While the wider IceNet project has moved further, including daily forecasts and pytorch implementations (see [_official website_](https://icenet.ai/)), this codebase's aim is to reproduce the results of the original publication of IceNet while giving an out-of-the-box experience according to more modern standards. This way, IceNet will be more accessible and can better be used as baseline for future work. For additional convenience when working on an HPC system, we provide a [_docker image_](https://hub.docker.com/repository/docker/laueb4818/icenet-legacy/general) (laueb4818/icenet-legacy:latest) containing all required dependencies and CUDA support.
*Limitations:* For now, this repository does not guaramtee support for SEAS5 as additional baselines or CMIP6 climate simulation data for pretraining.


The flexibility of the code simplifies possible extensions of the study.
The data processing pipeline and custom `IceNetDataLoader` class lets you
dictate which variables are input to the networks, which climate simulations are
used for pre-training, and how far ahead to forecast.
The architecture of the IceNet model can be adapted in `icenet/models.py`.
The output variable to forecast could even be changed by refactoring the `IceNetDataLoader`
class.

<!--
### Status
- ✅ Works — tested
- ❌ Does not work
- ⚠️ May work — not tested
-->

![](figures/architecture.png)
*Image source: [Andersson et al. (2021)](https://www.nature.com/articles/s41467-021-25257-4).*

The guidelines below assume you're working in
the command line of a Unix-like machine with a GPU. If aiming to reproduce all the
results of the study, 1 TB of space should safely cover the storage requirements
from the data downloaded and generated.


## Steps to reproduce the paper's results from scratch

### 0) Preliminary setup

* The recommended package management tool for working with this repository is `uv`. If you are not familiar with uv, please see the [_official guide_](https://docs.astral.sh/uv/).
Alternatively, we refer to our [_docker image_](https://hub.docker.com/repository/docker/laueb4818/icenet-legacy/general), which contains all the dependencies and CUDA support. This setup is recommended when working on an HPC system.
Note: When working with a Docker container, the scripts should be run with `python ...` instead of `uv run ...` to use the environment which is set up inside the docker image. Otherwise, uv will try to activate an environment based on a local uv.lock file. When using any of the bash scripts of this repository in the docker container, we recommend the alternative versions with the name pattern "HPC_*.sh", which are already adjusted to the docker workflow.


* To be able to download ERA5 data, you must first set up a CDS
account and populate your `.cdsapirc` file. Follow the 'Install the CDS API key'
instructions [here](https://cds.climate.copernicus.eu/api-how-to#install-the-cds-api-key).

* To track training runs and perform Bayesian hyperparameter tuning with Weights
and Biases, sign up at https://wandb.ai/site. Obtain your API key from
[here](https://wandb.ai/authorize) and fill the Weights and Biases entries in `icenet/config.py`.
Ensure you are logged in by running `wandb login` after setting up the uv environment.

### 1) Set up uv environment

After cloning the repo, run the commands below in the root of the repository to
set up the uv environment:

- If you don't have `uv` installed, you can do so by running:
    - macOS / Linux: `curl -LsSf https://astral.sh/uv/install.sh | sh`
    - Windows: `powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"`
(For further information, please see the [_official installation guide_](https://docs.astral.sh/uv/getting-started/installation/).)

- Next, simply run `uv sync` inside the project root of the repository. This will create a virtual environment and install the dependencies. You do not need to activate the environment manually, as this is taken care of by uv automatically when running script via `uv run`.
- To upgrade and extend the environment, we recommend using `uv add`.


### 2) Download data

The [CMIP6 variable naming convention](https://docs.google.com/spreadsheets/d/1UUtoz6Ofyjlpx5LdqhKcwHFz2SGoTQV2_yekHyMfL9Y/edit#gid=1221485271) is used throughout this project - e.g. `tas` for surface air temperature, `siconca` for sea ice concentration, etc.

- `uv run icenet/gen_masks.py`. This obtains masks for land, the polar holes,
monthly maximum ice extent (the 'active grid cell region'), and the Arctic regions
& coastline.

- `uv run icenet/download_sic_data.py`. Downloads OSI-SAF SIC data. This computes monthly-averaged SIC server-side, downloads the results, and bilinearly interpolates missing grid cells (e.g. polar hole). Note this download can take anywhere from 1 to 12 hours to complete.

- `./download_era5_data_in_parallel.sh`. Downloads ERA5 reanalysis data.
This runs multiple parallel `uv run icenet/download_era5_data.py` commands in the background to acquire each ERA5 variable. The raw ERA5 data is downloaded in global latitude-longitude format and regridded to the EASE grid that OSI-SAF SIC data lies on. Logs are output to `logs/era5_download_logs/`.
Alternatively, to see live outputs while downloading the ERA5 data in sequence, use `./download_era5_data_in_sequence.sh`.

- `./rotate_wind_data_in_parallel.sh`. This rotates wind vector data onto the EASE grid. At this point, it just runs the `icenet/rotate_wind_data.py` script on the ERA5 data; but when including CMIP6 data, it can be used to run the same python script on multiple data instances in parallel. Note, that while the python script could also be executed directly without a bash file, storing the outputs in log files as done by the bash script is used for a safety check. Applying the rotation twice would corrupt the data, which is why the python script contains a simple safeguard and raises an error if the log file already exists.

### 3) Process data

#### 3.1) Set up IceNet's custom data loader

- `uv run icenet/gen_data_loader_config.py`. Sets up the data loader configuration.
This is saved as a JSON file dictating IceNet's input and output data,
train/val/test splits, etc. The config file is used to instantiate the
custom `IceNetDataLoader` class. Two example config files are provided in this repository
in `dataloader_configs/`. Each config file is identified by a
dataloader ID, determined by a timestamp and a user-provided name (e.g.
`2021_06_15_1854_icenet_nature_communications`). The data loader ID,
together with an architecture ID set in the training script, provides an 'IceNet ID'
which uniquely identifies an IceNet ensemble model by its data configuration and
architecture.

#### 3.2) Preprocess the raw data

- `uv run icenet/preproc_icenet_data.py`. Normalises the raw NetCDF data and saves it as
monthly NumPy files. The normalisation parameters (mean/std dev or min/max)
are saved as a JSON file so that new data can be preprocessed without
having to recompute the normalisation.

- The observational training & validation dataset for IceNet is just 23 GB,
which can fit in RAM on some systems and significantly speed up the fine-tuning
training phase compared with using the data loader. To benefit from this, run
`uv run icenet/gen_numpy_obs_train_val_datasets.py` to generate NumPy tensors
for the train/val input/output data. To further benefit from the training speed
improvements of `tf.data`, generate a TFRecords dataset from the NumPy tensors
using `uv run icenet/gen_tfrecords_obs_train_val_datasets.py`. Whether to use
the data loader, NumPy arrays, or TFRecords datasets for training is controlled by bools in
`icenet/train_icenet.py`.

### 4) Train IceNet

#### 4.1) OPTIONAL: Run the hyperparameter search (skip if using default values from paper)

- Set `icenet/train_icenet.py` up for hyperparameter tuning: Set pre-training
and temperature scaling bools to `False` in the user input section.
- `wandb sweep icenet/sweep.yaml`
- Then run the `wandb agent` command that is printed.
- Cancel the sweep after a sufficient picture on optimal hyperparameters is
built up on the [wandb.ai](https://wandb.ai/home) page.

#### 4.2) Run training

- Train IceNet networks with `uv run icenet/train_icenet.py`. This takes
hyperameter settings and the random seed for network weight initalisation as
command line inputs. Run this multiple times with different settings of `--seed`
to train an ensemble. Trained networks are saved in
`trained_networks/<dataloader_ID>/<architecture_ID>/networks/`. If working on a
shared machine and familiar with SLURM, you may want to wrap this command in a
SLURM script.

### 5) Produce forecasts

- `uv run icenet/predict_heldout_data.py`. Uses `xarray` to save predictions
over the validation and test years as (2012-2020) as NetCDFs for IceNet and the
linear trend benchmark. IceNet's forecasts are saved in
`data/forecasts/icenet/<dataloader_ID>/<architecture_ID>/`.
For IceNet, the full forecast dataset has dimensions
`(target date, y, x, lead time, ice class, seed)`, where `seed` specifies
a single ensemble member or the ensemble-mean forecast. An ensemble-mean
SIP forecast is also computed and saved as a separate, smaller file
(which only has the first four dimensions).

- Compute IceNet's ensemble-mean temperature scaling parameter for each lead time:
`uv run icenet/compute_ensemble_mean_temp_scaling.py`. The new, ensemble-mean
temperature-scaled SIP forecasts are saved to
`data/forecasts/icenet/<dataloader_ID>/<architecture_ID>/icenet_sip_forecasts_tempscaled.nc`.
These forecasts represent the final ensemble-mean IceNet model used for the paper.

### 6) Analyse forecasts

- `uv run icenet/analyse_heldout_predictions.py`. Loads the NetCDF forecast data and computes
forecast metrics, storing results in a global `pandas` DataFrame with
`MultiIndex` `(model, ensemble member, lead time, target date)` and columns
for each metric (binary accuracy and sea ice extent error). Uses
`dask` to avoid loading the entire forecast datasets into memory, processing
chunks in parallel to significantly speed up the analysis. Results are saved
as CSV files in `results/forecast_results/` with a timestamp to avoid overwriting.
Optionally pre-load the latest CSV file to append new models or metrics to the
results without needing to re-analyse existing models. Use this feature to append
forecast results from other IceNet models (identified by their dataloader ID
and architecture ID) to track the effect of design changes on forecast performance.

- `uv run icenet/analyse_uncertainty.py`. Assesses the calibration of IceNet and
SEAS5's SIP forecasts. Also determines IceNet's ice edge region and assesses
its ice edge bounding ability. Results are saved in `results/uncertainty_results/`.

### 7) Run the permute-and-predict method to explore IceNet's most important input variables

- `uv run icenet/permute_and_predict.py`. Results are stored in
`results/permute_and_predict_results/`.

### 8) Generate the paper figures and tables

- `uv run icenet/plot_paper_figures.py`. Figures are saved in `figures/paper_figures/`. Note, you will need the Sea Ice Outlook
error CSV file to plot Supp. Fig. 5:
```
wget -O data/sea_ice_outlook_errors.csv 'https://ramadda.data.bas.ac.uk/repository/entry/get/sea_ice_outlook_errors.csv?entryid=synth%3A71820e7d-c628-4e32-969f-464b7efb187c%3AL3Jlc3VsdHMvb3V0bG9va19lcnJvcnMvc2VhX2ljZV9vdXRsb29rX2Vycm9ycy5jc3Y%3D'
```

### Misc

- `icenet/utils.py` defines IceNet utility functions like the data preprocessor,
data loader, ERA5 and CMIP6 processing, learning rate decay, and video functionality.
- `icenet/models.py` defines network architectures.
- `icenet/config.py` defines globals.
- `icenet/losses.py` defines loss functions.
- `icenet/callbacks.py` defines training callbacks.
- `icenet/metrics.py` defines training metrics.

### Project structure: simplified output from `tree`

```
.
├── data
│   ├── obs
│   ├── cmip6
│   │   ├── EC-Earth3
│   │   │   ├── r10i1p1f1
│   │   │   ├── r12i1p1f1
│   │   │   ├── r14i1p1f1
│   │   │   ├── r2i1p1f1
│   │   │   └── r7i1p1f1
│   │   └── MRI-ESM2-0
│   │       ├── r1i1p1f1
│   │       ├── r2i1p1f1
│   │       ├── r3i1p1f1
│   │       ├── r4i1p1f1
│   │       └── r5i1p1f1
│   ├── forecasts
│   │   ├── icenet
│   │   │   ├── 2021_06_15_1854_icenet_nature_communications
│   │   │   │   └── unet_tempscale
│   │   │   └── 2021_06_30_0954_icenet_pretrain_ablation
│   │   │       └── unet_tempscale
│   │   ├── linear_trend
│   │   └── seas5
│   │       ├── EASE
│   │       └── latlon
│   ├── masks
│   └── network_datasets
│       └── dataset1
│           ├── meta
│           ├── obs
│           ├── transfer
│           └── norm_params.json
├── dataloader_configs
│   ├── 2021_06_15_1854_icenet_nature_communications.json
│   └── 2021_06_30_0954_icenet_pretrain_ablation.json
├── figures
├── icenet
├── logs
│   ├── cmip6_download_logs
│   ├── era5_download_logs
│   ├── seas5_download_logs
│   └── wind_rotation_logs
├── results
│   ├── forecast_results
│   │   └── 2021_07_01_183913_forecast_results.csv
│   ├── permute_and_predict_results
│   │   └── permute_and_predict_results.csv
│   └── uncertainty_results
│       ├── ice_edge_region_results.csv
│       ├── sip_bounding_results.csv
│       └── uncertainty_results.csv
└── trained_networks
    └── 2021_06_15_1854_icenet_nature_communications
        ├── obs_train_val_data
        │   ├── numpy
        │   └── tfrecords
        │       ├── train
        │       └── val
        └── unet_tempscale
            └── networks
                ├── network_tempscaled_36.h5
                ├── network_tempscaled_37.h5
                :
```

### Acknowledgements

Thanks to James Byrne (BAS) and Tony Phillips (BAS) for direct contributions to this codebase.
