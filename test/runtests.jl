module TestFoldsKernelAbstractions
using Test

const TEST_CUDA = try
    import CUDA
    CUDA.has_cuda_gpu()
catch
    false
end

const TEST_ROC = try
    import AMDGPU
    true
catch
    false
end

const TEST_GPU = TEST_CUDA || TEST_ROC

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

@testset "$file" for file in find_test("rocm")
    TEST_ROC || continue
    include(file)
end

end  # module
