using LinearAlgebra
using OrderedCollections
using IRTools
using ChainRulesCore
using CUDA


include("funres.jl")
include("utils.jl")
include("scatter/scatter.jl")
include("helpers.jl")
include("devices.jl")
include("tape.jl")
include("trace.jl")
include("compile.jl")


const BEST_AVAILABLE_DEVICE = Ref{AbstractDevice}(CPU())
best_available_device() = BEST_AVAILABLE_DEVICE[]

function __init__()
    if CUDA.functional()
        BEST_AVAILABLE_DEVICE[] = GPU(1)
    end
end