import Ghost: trace, V, Call, play!

inc_mul(a::Real, b::Real) = a * (b + 1.0)
inc_mul(A::AbstractArray, B::AbstractArray) = inc_mul.(A, B)
inc_mul2(A::AbstractArray, B::AbstractArray) = A .* (B .+ 1)


non_primitive(x) = 2x + 1
non_primitive_caller(x) = sin(non_primitive(x))


make_tuple(a, b) = (a, b)

function tuple_unpack(x)
    a, b = make_tuple(1, 2)
    x + a
end


function make_adder(x)
    return y -> x + y
end

function add(x, y)
    adder = make_adder(x)
    adder(y)
end


function constant_return_value(x)
    2x
    nothing
end


function no_input()
    print()
end


@testset "trace" begin
    # calls
    val, tape = trace(inc_mul, 2.0, 3.0)
    @test val == inc_mul(2.0, 3.0)
    @test length(tape) == 5
    @test tape[V(5)].args[1].id == 2

    # bcast
    A = rand(3)
    B = rand(3)
    val, tape = trace(inc_mul, A, B)
    @test val == inc_mul(A, B)
    # broadcasting may be lowered to different forms,
    # so making no assumptions regarding the tape

    val, tape = trace(inc_mul2, A, B)
    @test val == inc_mul2(A, B)

    # primitives
    x = 3.0
    val1, tape1 = trace(non_primitive_caller, x)
    val2, tape2 = trace(non_primitive_caller, x; primitives=Set([non_primitive, sin]))

    @test val1 == val2
    @test any(op isa Call && op.fn == (*) for op in tape1)
    @test tape2[V(3)].fn == non_primitive
    @test tape2[V(4)].fn == sin

    # tuple unpacking
    val, tape = trace(tuple_unpack, 4.0)
    @test val == tuple_unpack(4.0)

    # closures
    val, tape = trace(add, 2.0, 4.0)
    @test val == add(2.0, 4.0)
    @test play!(tape, add, 2.0, 5.0) == add(2.0, 5.0)
    @test play!(tape, add, 3.0, 5.0) == add(3.0, 5.0)

    # iterators
    xs = rand(3)
    f = xs -> [x + 1 for x in xs]
    val, tape = trace(f, xs)
    @test val == f(xs)
    xs2 = rand(5)
    @test play!(tape, nothing, xs2) == f(xs2)

    # constant return value
    _, tape = trace(constant_return_value, 1.0)
    @test play!(tape, nothing, 2.0) === nothing

    # no input
    _, tape = trace(no_input)
    @test tape[V(2)].fn == print
end



function return_in_branch(x)
    if x > 0
        return 2x
    end
    return 3x
end

@testset "trace: branches" begin
    # See https://github.com/dfdx/Ghost.jl/issues/8
    _, tape = trace(return_in_branch, 1.0)
    @test tape[V(length(tape))].args[1] == 2

    _, tape = trace(return_in_branch, -1.0)
    @test tape[V(length(tape))].args[1] == 3
end


function loop1(a, n)
    a = 2a
    for i in 1:n
        a = a * n
    end
    return a
end

function loop2(a, b)
    while b > 0
        a = a * b
        b = b - 1
    end
    return a
end


function loop3(a, b)
    while b > 1
        b = b - 1
        a = b
        while a < 100
            a = a * b + 1
        end
    end
    return a
end


function loop4(x, n, m)
    for i in 1:n
        for j in 1:m
            x = 2x
        end
    end
    return x
end


function loop5(a, n)
    for i=1:3
        a = loop1(a, n)
    end
    return a
end

function loop6(n)
    a = 0
    i = 1
    while true
        a += i
        if a > n
            break
        end
    end
    return a
end

function myabs(x)
    if x >= 0
        return x
    else
        return -x
    end
end

function myabs2(x)
    if x <= 0
        return -x
    else
        return 1*x
    end
end

@testset "trace: loops" begin
    should_trace_loops!(false)

    _, tape = trace(loop1, 1.0, 3)
    @test findfirst(op -> op isa Loop, tape.ops) === nothing
    # same number of iteration
    @test play!(tape, loop1, 2.0, 3) == loop1(2.0, 3)
    @test compile(tape)(loop1, 2.0, 3) == loop1(2.0, 3)
    # different number of iteration - with loop tracing off, should be incorrect
    @test play!(tape, loop1, 2.0, 4) != loop1(2.0, 4)
    @test compile(tape)(loop1, 2.0, 4) != loop1(2.0, 4)

    should_trace_loops!(true)

    _, tape = trace(loop1, 1.0, 3)
    @test play!(tape, loop1, 2.0, 4) == loop1(2.0, 4)
    @test compile(tape)(loop1, 2.0, 4) == loop1(2.0, 4)
    @test findfirst(op -> op isa Loop, tape.ops) !== nothing

    _, tape = trace(loop2, 1.0, 3)
    @test play!(tape, loop2, 2.0, 4) == loop2(2.0, 4)
    @test compile(tape)(loop2, 2.0, 4) == loop2(2.0, 4)
    @test findfirst(op -> op isa Loop, tape.ops) !== nothing

    _, tape = trace(loop3, 1.0, 3)
    @test play!(tape, loop3, 2.0, 4) == loop3(2.0, 4)
    @test compile(tape)(loop3, 2.0, 4) == loop3(2.0, 4)
    @test findfirst(op -> op isa Loop, tape.ops) !== nothing

    _, tape = trace(loop4, 1.0, 2, 3)
    @test play!(tape, loop4, 2.0, 3, 4) == loop4(2.0, 3, 4)
    @test compile(tape)(loop4, 2.0, 3, 4) == loop4(2.0, 3, 4)
    loop_idx = findfirst(op -> op isa Loop, tape.ops)
    @test loop_idx !== nothing
    subtape = tape[V(loop_idx)].subtape
    @test findfirst(op -> op isa Loop, subtape.ops) !== nothing

    _, tape = trace(loop5, 1.0, 3)
    @test play!(tape, loop5, 2.0, 4) == loop5(2.0, 4)
    @test compile(tape)(loop5, 2.0, 4) == loop5(2.0, 4)
    loop_idx = findfirst(op -> op isa Loop, tape.ops)
    @test loop_idx !== nothing
    subtape = tape[V(loop_idx)].subtape
    @test findfirst(op -> op isa Loop, subtape.ops) !== nothing

    should_trace_loops!()

    # Test with fixed boolean condition
    # Currently broken
    #=
    _, tape = trace(loop6, 3)
    @test play!(tape, loop6, 3) == loop6(3)
    @test compile(tape, loop6, 3) == loop6(3)
    =#
end

@testset "trace: branches" begin
    should_assert_branches!(true)

    _, tape = trace(myabs, 3)
    @test play!(tape, myabs, 3) == 3
    @test_throws AssertionError play!(tape, myabs, -3) # Throws assert exception due to bad branch

    _, tape = trace(myabs2, 3)
    @test play!(tape, myabs2, 3) == 3
    @test_throws AssertionError play!(tape, myabs2, -3) # Test with branching flipped

    should_assert_branches!(false)
end
