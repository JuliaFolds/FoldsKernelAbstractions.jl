module TestWithSequential

using Adapt
using CUDA
using CUDAKernels

include("../with_sequential.jl")

upload(x) = adapt(CuArray, x)
test_with_sequential(tests, get_executors(CUDADevice()); upload = upload)

end

