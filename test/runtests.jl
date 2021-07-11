using Test
using Ghost
using Ghost: Loop, should_trace_loops, should_trace_loops!
using Ghost: compile, play!


include("test_funres.jl")
include("test_tape.jl")
include("test_trace.jl")
