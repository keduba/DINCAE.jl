# DINCAE.jl


DINCAE (Data-Interpolating Convolutional Auto-Encoder) is a neural network to
reconstruct missing data in satellite observations. It can work with gridded data
(`DINCAE.reconstruct`) or a clouds of points (`DINCAE.reconstruct_points`).
In the later case, the data can be organized in e.g. tracks (or not).

The code is available at:
[https://github.com/gher-uliege/DINCAE.jl](https://github.com/gher-uliege/DINCAE.jl)

The method is described in the following articles:

* Barth, A., Alvera-Azcárate, A., Licer, M., & Beckers, J.-M. (2020). DINCAE 1.0: a convolutional neural network with error estimates to reconstruct sea surface temperature satellite observations. Geoscientific Model Development, 13(3), 1609–1622. https://doi.org/10.5194/gmd-13-1609-2020
* Barth, A., Alvera-Azcárate, A., Troupin, C., & Beckers, J.-M. (2022). DINCAE 2.0: multivariate convolutional neural network with error estimates to reconstruct sea surface temperature satellite and altimetry observations. Geoscientific Model Development, 15(5), 2183–2196. https://doi.org/10.5194/gmd-15-2183-2022

The neural network will be trained on the GPU. Note convolutional neural networks can require a lot of GPU memory depending on the domain size. 
So far, only NVIDIA GPUs are supported by the neural network framework `Knet.jl` used in DINCAE (beside training on the CPU but which is prohibitively slow).


## User API


In most cases, a user only needs to interact with the function `DINCAE.reconstruct` or `DINCAE.reconstruct_points`.

```@docs
DINCAE.reconstruct
DINCAE.reconstruct_points
```


## Internal functions

```@docs
DINCAE.load_gridded_nc
DINCAE.NCData
```

## Reducing GPU memory usage

Convolutional neural networks can require "a lot" of GPU memory. These parameters can affect GPU memory utilisation:

* reduce the mini-batch size
* use fewer layers (e.g. `enc_nfilter_internal` = [16,24,36] or [16,24])
* use less filters (reduce the values of the optional parameter enc_nfilter_internal)
* use a smaller domain or lower resolution


## Troubleshooting

### Installation of cuDNN

If you get the warniong `Package cuDNN not found in current path` or the error `Scalar indexing is disallowed`:

```
julia> using DINCAE
┌ Warning: Package cuDNN not found in current path.
│ - Run `import Pkg; Pkg.add("cuDNN")` to install the cuDNN package, then restart julia.
│ - If cuDNN is not installed, some Flux functionalities will not be available when running on the GPU.
```


You need to install and load cuDNN before calling a function in DINCAE.jl:

``` julia
using cuDNN
using DINCAE
# ...
```

### Dependencies of DINCAE.jl

`DINCAE.jl` depends on `Flux.jl` and `CUDA.jl` which will automatically be installed.
If you have some problems installing these package you might consult the
[documentation of `Flux.jl`](http://fluxml.ai/Flux.jl/stable/#Installation) or 
[`CUDA.jl`](https://cuda.juliagpu.org/stable/installation/overview/).
