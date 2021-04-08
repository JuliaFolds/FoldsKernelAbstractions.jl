module TestWithSequential

using Adapt
using AMDGPU
using ROCKernels

include("../with_sequential.jl")

upload(x) = adapt(ROCArray, x)
test_with_sequential(tests, get_executors(ROCDevice()); upload = upload)

end
