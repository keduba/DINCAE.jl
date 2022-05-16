
ENV["CUDA_VISIBLE_DEVICES"]=""

using Test
using DINCAE
using Base.Iterators
using Random
using NCDatasets

const F = Float32
Atype = Array{F}

Random.seed!(123)

#filename = "avhrr_sub_add_clouds_small.nc"
filename = "avhrr_sub_add_clouds_n10.nc"

if !isfile(filename)
#    download("https://dox.ulg.ac.be/index.php/s/b3DWpYysuw6itOz/download", filename)
    download("https://dox.ulg.ac.be/index.php/s/2yFgNMkpsGumVSM/download", filename)
end


data = [
   (filename = filename,
    varname = "SST",
    obs_err_std = 1,
    jitter_std = 0.05,
    isoutput = true,
   )
]
data_test = data;
data_all = [data,data_test]

epochs = 2
batch_size = 5
save_each = 10
skipconnections = [1,2]
enc_nfilter_internal = round.(Int,32 * 2 .^ (0:3))
clip_grad = 5.0
regularization_L2_beta = 0
save_epochs = [epochs]
is3D = false
ntime_win = 3

for (upsampling_method,is3D,truth_uncertain) = ((:nearest,false,false),
                                (:bilinear,false,false),
                                (:nearest,true,false),
                                (:nearest,false,true))

    fnames_rec = [tempname()]

    losses = DINCAE.reconstruct(
        Atype,data_all,fnames_rec;
        epochs = epochs,
        batch_size = batch_size,
        truth_uncertain = truth_uncertain,
        enc_nfilter_internal = enc_nfilter_internal,
        clip_grad = clip_grad,
        save_epochs = save_epochs,
        is3D = is3D,
        upsampling_method = upsampling_method,
        ntime_win = ntime_win,
    )


    @test isfile(fnames_rec[1])

    NCDataset(fnames_rec[1]) do ds
        losses = ds["losses"][:]
        @test length(losses) == epochs
    end
    rm(fnames_rec[1])
end




data = [
   (filename = filename,
    varname = "SST",
    obs_err_std = 1,
    jitter_std = 0.05,
    isoutput = true,
   )
]

ntime_win = 3
cycle_periods = (365.25,) # days
is3D = false
remove_mean = true

data_source = DINCAE.NCData(
    data,train = true,
    ntime_win = ntime_win,
    is3D = is3D,
    cycle_periods = cycle_periods,
    remove_mean = remove_mean,
)

batch_size = 32
sz = size(data_source.data_full)[1:2]

xin = zeros(sz[1],sz[2],10)
xtrue = zeros(sz[1],sz[2],2)

# 312 µs
#@btime DINCAE.getxy!(data_source,1,xin,xtrue);

Atype = Array
data_iter = DINCAE.DataBatches(Atype,data_source,batch_size)

size(first(data_iter)[2])

# mirlo: 3.645 ms
#@btime first($data_iter);
