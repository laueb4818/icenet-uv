# Notes to changes in functionality of the IceNet repo

- 1) Scripts related to cmip6 data are not updated. The specific data that was used to create the IceNet paper results seem not to be available anymore.
- 2) Small changes in have been applied to the downloading functionality for SEAS5 forecasts. These should in theory now work, but specific permissions are required to access the MARS services. Subsequent processing of SEAS5 data (icenet/biascorrect_seas5_forecasts.py) is therefore ignored and not updated.
- 3) Model logic is incompatible with newer package versions. Either model has to be patched, but it is unclear if that will cause issuses later and lead to a tail of patches, or the dependencies have to be downgraded, whereas that might corrupt earlier parts of the pipeline that are working now.
