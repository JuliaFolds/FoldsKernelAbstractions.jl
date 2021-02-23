module TestDevice

include("../device_tests.jl")
using ROCKernels

test_all(ROCDevice())

end  # module
