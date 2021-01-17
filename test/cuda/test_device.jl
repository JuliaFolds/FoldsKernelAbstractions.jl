module TestDevice

include("../device_tests.jl")
using CUDAKernels

test_all(CUDADevice())

end  # module
