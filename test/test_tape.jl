import Ghost: Tape, V, inputs!, rebind!, mkcall, primitivize!


@testset "tape" begin
    # rebind!
    tape = Tape()
    _, v1, v2 = inputs!(tape, nothing, 3.0, 5.0)
    v3 = push!(tape, mkcall(*, v1, 2))
    st = Dict(v1.id => v2.id)
    rebind!(tape, st)
    @test tape[v3].args[1].id == v2.id

    # variable equality
    @test tape[v3].args[1] == v2         # bound var
    @test tape[v3].args[1] != V(v2.id)   # unbound var

    # mkcall value calculation
    c = mkcall(*, 2.0, v1)                # bound var
    @test c.val == 2.0 * tape[v1].val
    c = mkcall(*, 2.0, V(100))            # unbound var
    @test c.val === missing
    c = mkcall(*, 2.0, V(100); val=10.0)  # manual value
    @test c.val == 10.0

    # push!, insert!; var hash
    tape = Tape()
    a1, a2, a3 = inputs!(tape, nothing, 2.0, 5.0)
    r = push!(tape, mkcall(*, a2, a3))
    @test tape[r].val == 10.0

    dct = Dict(r => :r)
    ops = [mkcall(+, a2, 1), mkcall(+, a3, 1)]
    v1, v2 = insert!(tape, 4, ops...)
    @test r.id == 6
    @test dct[r] == :r

    tape[r] = mkcall(*, v1, v2)
    @test tape[r].val == 18.0

    v2.id = 100
    @test tape[r].args[2].id == 100

    # replace!
    tape2 = deepcopy(tape)
    tape3 = deepcopy(tape)

    op1 = mkcall(*, V(2), 2)
    op2 = mkcall(+, V(op1), 1)
    z = replace!(tape, 4 => [op1, op2]; rebind_to=2)
    @test tape[V(7)].args[1].id == op2.id
    @test z isa V

    replace!(tape2, V(4) => [op1, op2]; rebind_to=2)
    @test tape2[V(7)].args[1].id == op2.id

    replace!(tape3, tape3[V(4)] => [op1, op2]; rebind_to=2)
    @test tape3[V(7)].args[1].id == op2.id

    # deleteat!
    tape = Tape()
    _, v1, v2 = inputs!(tape, nothing, 3.0, 5.0)
    v3 = push!(tape, mkcall(*, v1, 2))
    v4 = push!(tape, mkcall(+, v3, v1))
    v5 = push!(tape, mkcall(+, v4, v2))
    v6 = push!(tape, mkcall(+, v4, v1))
    tape2, tape3 = deepcopy(tape), deepcopy(tape)

    deleteat!(tape, 5; rebind_to = 1)
    @test tape[V(5)].args[1].id == 1
    @test tape[V(6)].args[1].id == 1
    @test all(x -> x[1].id == x[2], zip(tape, 1:length(tape)))

    deleteat!(tape2, 5; rebind_to = 1)
    @test tape2[V(5)].args[1].id == 1
    @test tape2[V(6)].args[1].id == 1
    @test all(x -> x[1].id == x[2], zip(tape2, 1:length(tape2)))

    deleteat!(tape3, 5; rebind_to = 1)
    @test tape3[V(5)].args[1].id == 1
    @test tape3[V(6)].args[1].id == 1
    @test all(x -> x[1].id == x[2], zip(tape3, 1:length(tape3)))

    tape = Tape()
    _, v1, v2 = inputs!(tape, nothing, 3.0, 5.0)
    v3 = push!(tape, mkcall(println, "Test"))
    deleteat!(tape, v3)
    @test length(tape) == 3

    # primitivize!
    f(x) = 2x - 1
    g(x) = f(x) + 5

    tape = Tape()
    _, x = inputs!(tape, g, 3.0)
    y = push!(tape, mkcall(f, x))
    z = push!(tape, mkcall(+, y, 5))
    tape.result = z

    primitivize!(tape)

    @test length(tape) == 5
    @test tape[V(3)].fn == *
    @test tape[V(4)].fn == -

end