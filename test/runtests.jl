using Test
using Ghost
using Ghost: Loop, should_trace_loops, should_trace_loops!, should_assert_branches, should_assert_branches!
using Ghost: compile, play!


include("test_funres.jl")
include("test_tape.jl")
include("test_trace.jl")
