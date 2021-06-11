# import Statistics
using LinearAlgebra
# using Setfield
using OrderedCollections
using IRTools
using CUDA


include("funres.jl")
include("utils.jl")
include("scatter/scatter.jl")
include("helpers.jl")
include("devices.jl")
include("tape.jl")
include("trace.jl")
include("compile.jl")