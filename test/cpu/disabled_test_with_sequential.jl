# This does not work ATM
module TestWithSequential

include("../with_sequential.jl")
using KernelAbstractions

test_with_sequential(tests, get_executors(CPU()))

end
