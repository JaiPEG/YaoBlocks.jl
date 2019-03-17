using Test, Random, YaoBase, YaoBlockTree, LuxurySparse

function random_dense_kron(n; gateset)
    addrs = randperm(n)
    blocks = [i=>rand(gateset) for i in addrs]
    g = KronBlock{n}(blocks...)
    sorted_blocks = sort(blocks, by=x->x[1])
    t = mapreduce(x->mat(x[2]), kron, reverse(sorted_blocks), init=IMatrix(1))
    mat(g) ≈ t || @info(g)
end

function rand_kron_test(n; gateset)
    firstn = rand(1:n)
    addrs = randperm(n)
    blocks = [rand(gateset) for i = 1:firstn]
    seq = [i=>each for (i, each) in zip(addrs[1:firstn], blocks)]
    mats = Any[i=>mat(each) for (i, each) in zip(addrs[1:firstn], blocks)]
    append!(mats, [i=>IMatrix(2) for i in addrs[firstn+1:end]])
    sorted = sort(mats, by=x->x.first)
    mats = map(x->x.second, reverse(sorted))

    g = KronBlock{n}(seq...)
    t = reduce(kron, mats, init=IMatrix(1))
    mat(g) ≈ t || @info(g)
end


@testset "test constructors" begin
    @test_throws AddressConflictError KronBlock{5}(4=>CNOT, 5=>X)
    @test_throws ErrorException kron(3, 1=>X, Y)
end

@testset "test mat" begin
    TestGateSet = [
        X, Y, Z,
        phase(0.1), phase(0.2), phase(0.3),
        rot(X, 0.1), rot(Y, 0.4), rot(Z, 0.2)]

    U = Const.X
    U2 = Const.CNOT

    @testset "case 1" begin
        m = kron(Const.I2, U)
        g = kron(2, 1=>X)
        @test m == mat(g)

        m = kron(U, Const.I2)
        g = kron(2, 2=>X)
        @test m == mat(g)
        @test collect(occupied_locations(g)) == [2]
        blks = [Rx(0.3)]
        @test chsubblocks(g, blks) |> subblocks |> collect == blks

        m = kron(U2, Const.I2, U, Const.I2)
        g = KronBlock{5}(4=>CNOT, 2=>X)
        @test m == mat(g)
        @test g.addrs == [2, 4]
        @test collect(occupied_locations(g)) == [2, 4, 5]
    end

    @testset "case 2" begin
        m = kron(mat(X), mat(Y), mat(Z))
        g = KronBlock{3}(1=>Z, 2=>Y, 3=>X)
        g1 = KronBlock(Z, Y, X)
        @test m == mat(g)
        @test m == mat(g1)

        m = kron(Const.I2, m)
        g = KronBlock{4}(1=>Z, 2=>Y, 3=>X)
        @test m == mat(g)
    end

    @testset "random dense sequence, n=$i" for i = 2:8
        @test random_dense_kron(i; gateset=TestGateSet)
    end

    @testset "random mat sequence, n=$i" for i = 4:8
        @test rand_kron_test(i; gateset=TestGateSet)
    end
end

@testset "test allocation" begin
    g = kron(4, 1=>X, 2=>phase(0.1))
    # deep copy
    cg = deepcopy(g)
    cg[2].theta = 0.2
    @test g[2].theta == 0.1

    # shallow copy
    cg = copy(g)
    cg[2].theta = 0.2
    @test g[2].theta == 0.2

    sg = similar(g)
    @test_throws KeyError sg[2]
    @test_throws KeyError sg[1]
end

@testset "test insertion" begin
    g = KronBlock{4}(1=>X, 2=>phase(0.1))
    g[4] = rot(X, 0.2)
    @test g[4].theta == 0.2

    g[2] = Y
    @test mat(g[2]) == mat(Y)
end

@testset "test iteration" begin
    g = kron(5, 1=>X, 3=>Y, 4=>rot(X, 0.0), 5=>rot(Y, 0.0))
    for (src, tg) in zip(g, [1=>X, 3=>Y, 4=>rot(X, 0.0), 5=>rot(Y, 0.0)])
        @test src[1] == tg[1]
        @test src[2] == tg[2]
    end

    for (src, tg) in zip(eachindex(g), [1, 3, 4, 5])
        @test src == tg
    end
end

@testset "test inspect" begin
    g = kron(5, 1=>X, 3=>Y, 4=>rot(X, 0.0), 5=>rot(Y, 0.0))
    collect(subblocks(g)) === g.blocks
    eltype(g) == Tuple{Int, AbstractBlock}

    @test isunitary(g) == true
    @test isreflexive(g) == true
end
