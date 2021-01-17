module TestFoldsKernelAbstractions
using Test
import CUDA

const TEST_CUDA = CUDA.has_cuda_gpu()

find_test(subdir = "") = sort([
    joinpath(subdir, file) for file in readdir(joinpath(@__DIR__, subdir)) if
    match(r"^test_.*\.jl$", file) !== nothing
])

@testset "$file" for file in find_test()
    include(file)
end

@testset "$file" for file in find_test("cuda")
    TEST_CUDA || continue
    include(file)
end

end  # module
