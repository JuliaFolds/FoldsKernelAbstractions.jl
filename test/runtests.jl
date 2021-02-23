module TestFoldsKernelAbstractions
using Test
import CUDA

const TEST_CUDA = CUDA.has_cuda_gpu()
const TEST_GPU = TEST_CUDA

find_test(subdir = "") = sort([
    joinpath(subdir, file) for file in readdir(joinpath(@__DIR__, subdir)) if
    match(r"^test_.*\.jl$", file) !== nothing
])

@testset "$file" for file in find_test()
    include(file)
end

@testset "$file" for file in find_test("cpu")
    TEST_GPU && continue
    include(file)
end

@testset "$file" for file in find_test("cuda")
    TEST_CUDA || continue
    include(file)
end

end  # module
