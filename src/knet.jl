# upsampling
struct Upsample{TA,N}
    w::TA
    padding::NTuple{N,Int}
end

struct SkipConnection
    inner
    connection
end

function Upsample(sz::Tuple, nvar; atype = Knet.atype(), method = :nearest)
    N = length(sz)
    #nvar = sz[N+1]
    #ksize = (2,2,2)
    # (2,2,...) for as many spatial/temporal dimension there are
    ksize = ntuple(i -> 2, N)
    allst = ntuple(i -> :, N)
    println("size = $sz; nvar = $nvar, ksize = $ksize, method = $method")

    if method == :nearest
        w = atype(zeros(ksize...,nvar,nvar))
        for i = 1:nvar
            w[allst...,i,i] .= 1
        end
    elseif method == :bilinear
        if N !== 2
            error("bilinear work only in 2 dimensions")
        end
        w = atype(bilinear(Float32,2,2,nvar,nvar))
    else
        error("unsupported method $method")
    end

    padding = ntuple(i -> 0, N)
    return Upsample(w,padding)
end
function (m::Upsample)(x)
    y = Knet.deconv4(m.w,x,stride=2,padding = m.padding)
    if size(m.w,2) == 2
        # nearest
        return y
    else
        # bilinear
        return y[2:end-1,2:end-1,:,:]
    end
end

weights(m::Union{Function,Upsample}) = []

function upsample(x)
    N = ndims(x)
    nvar = size(x,N-1)
    #ksize = (2,2,2)
    # (2,2,...) for as many spatial/temporal dimension there are
    ksize = ntuple(i -> 2, N-2)
    allst = ntuple(i -> :, N-2)

    w = similar(x,ksize...,nvar,nvar)
    fill!(w,0)

    for i = 1:nvar
        #w[:,:,:,i,i] .= 1
        w[allst...,i,i] .= 1
    end
    return Knet.deconv4(w,x,stride=2)
end

export upsample

function (m::SkipConnection)(x)
    return m.connection(m.inner(x),x)
end

weights(m::Union{SkipConnection}) = weights(m.inner)

# dense layer
struct Dense
    w
    b
    f
    dropout_rate_train
end

(d::Dense)(x) = dropout(d.f.(d.w * mat(x) .+ d.b),d.dropout_rate_train)
Dense(i::Int,nout::Int,dropout_rate_train::AbstractFloat,f=relu) = Dense(param(nout,i), param0(nout), f, dropout_rate_train)
export Dense

# Define convolutional layer:
struct Conv
    w
    b
    f
end
export Conv

mse(x,y) = mean((x-y).^2)

(c::Conv)(x) = c.f.(conv4(c.w, x, padding = 1) .+ c.b)
# deprecated
#Conv(w1::Integer,w2::Integer,cx,cy,f = relu) = Conv(param(w1,w2,cx,cy), param0(1,1,cy,1), f)

Conv(w::NTuple{2},(cx,cy),f = relu) = Conv(param(w[1],w[2],cx,cy), param0(1,1,cy,1), f)
Conv(w::NTuple{3},(cx,cy),f = relu) = Conv(param(w[1],w[2],w[3],cx,cy), param0(1,1,1,cy,1), f)


# Define transposed convolutional layer:
struct ConvTranspose
    w
    b
    f
    stride
    pad
end
export ConvTranspose

(c::ConvTranspose)(x) = c.f.(deconv4(c.w, x, padding = c.pad,stride = c.stride) .+ c.b)

ConvTranspose(w::NTuple{2},(cx,cy),f = identity; stride=1, pad=0) =
    ConvTranspose(param(w...,cy,cx), param0(1,1,cy,1), f, stride, pad)

ConvTranspose(w::NTuple{3},(cx,cy),f = identity; stride=1, pad=0) =
    ConvTranspose(param(w...,cy,cx), param0(1,1,1,cy,1), f, stride, pad)


# Chain of layers
struct Chain{T<:Tuple}
    layers::T
end

Chain(layers...) = Chain(layers)

export Chain

function (c::Chain)(x)
    for l in c.layers
        x = l(x)
    end
    return x
end

weights(m::Chain) = reduce(vcat,weights.(m.layers))


mutable struct BatchNorm
    inputsize
    w
    m
end

(l::BatchNorm)(x; o...) = batchnorm(x, l.m, l.w; o...)

function BatchNorm(; input::Int, atype=Knet.atype())
    w = Param(atype(bnparams(input)))
    m = bnmoments()
    return BatchNorm(input, w, m)
end

BatchNorm(input; kwargs...) = BatchNorm(input=input; kwargs...)


struct ConvBN
    w
    b
    bn
    f
end
export ConvBN

(c::ConvBN)(x) = c.f.(c.bn(conv4(c.w, x, padding = 1) .+ c.b))
ConvBN(w::NTuple{2},(cx,cy),f = relu) = ConvBN(param(w[1],w[2],cx,cy), param0(1,1,cy,1), BatchNorm(cy), f)
ConvBN(w::NTuple{3},(cx,cy),f = relu) = ConvBN(param(w[1],w[2],w[3],cx,cy), param0(1,1,1,cy,1), BatchNorm(cy), f)


weights(m::Union{Dense,BatchNorm,Conv,ConvBN,ConvTranspose}) = [m.w]


function MaxPool(window::NTuple; pad = 0)
    for w in window
        @assert w == 2
    end

    return x -> pool(x; mode = 0, padding = pad)
end


function MeanPool(window::NTuple; pad = 0)
    for w in window
        @assert w == 2
    end

    return x -> pool(x; mode = 1, padding = pad)
end
