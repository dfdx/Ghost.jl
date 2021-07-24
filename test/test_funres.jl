
@testset "functionresolver" begin
    rsv = Ghost.FunctionResolver{Symbol}()
    rsv[Tuple{typeof(sin), Vararg}] = :Vararg
    rsv[Tuple{typeof(sin), Float64}] = :Float64
    rsv[Tuple{typeof(sin), Real}] = :Real
    rsv[Tuple{typeof(sin), Number}] = :Number
    # Yota.order!(rsv)

    @test rsv[Tuple{typeof(sin), Float64}] == :Float64
    @test rsv[Tuple{typeof(sin), Float32}] == :Real
    @test rsv[Tuple{typeof(sin), Float64, Float64}] == :Vararg

    # non-matching signature
    rsv[Tuple{typeof(cos), Number}] = :CosineNumber
    @test rsv[Tuple{typeof(cos), String}] === nothing

    # override value
    rsv[Tuple{typeof(cos), Number}] = :CosineNumber2
    @test rsv[Tuple{typeof(cos), Number}] == :CosineNumber2
    @test length(rsv.signatures[Symbol("Base.#cos")]) == 1
end