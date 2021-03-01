using FLoops
using Folds
using FoldsKernelAbstractions
using Referenceables
using Test

function inc!(xs, ex = nothing)
    @floop ex for x in referenceable(xs)
        x[] += 1
    end
    return xs
end

function test_size(
    device;
    groupsize,
    basesize = 2,
    extraitems = 0,
    n = groupsize * basesize + extraitems,
)
    ex = KAEx(device; groupsize, basesize)

    @test Folds.sum(1:n, ex) == sum(1:n)
    @test Folds.reduce(xor, 1:n, ex; init = 0) == reduce(xor, 1:n; init = 0)

    xs = FoldsKernelAbstractions.arrayfor(device)(1:n)
    @test inc!(xs, ex) == 2:n+1
end

function test_sweep_sizes(device)
    @testset for groupsize in [1, 2, 8, 64, 256],
        basesize in [2, 5, 16, 19],
        extraitems in [0, 1, 3]

        test_size(device; groupsize, basesize, extraitems)
    end
    @testset "$kwds" for kwds in [
        (groupsize = 4, n = 3),
        (groupsize = 4, n = 2),
        (groupsize = 4, n = 1),
        (groupsize = 4, basesize = 10, n = 30),
        (groupsize = 4, basesize = 10, n = 20),
        (groupsize = 4, basesize = 10, n = 10),
    ]
        test_size(device; kwds...)
    end
end

function test_all(device)
    @testset "sweep sizes" begin
        test_sweep_sizes(device)
    end
end
