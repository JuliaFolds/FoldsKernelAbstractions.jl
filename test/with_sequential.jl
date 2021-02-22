using Folds.Testing: parse_tests, test_with_sequential
using FoldsKernelAbstractions

# Taken from FoldsCUDA.jl
rawdata = """
count(isodd(x) for x in 1:10)
extrema((x - 5)^2 for x in 1:10)
mapreduce(x -> x^2, +, 1:10)
mapreduce(*, +, 1:10, 11:20)
mapreduce(*, +, 1:10, 11:20, 21:30)
maximum(0:9)
maximum(9:-1:0)
maximum([2, 3, 0, 3, 4, 0, 5, 7, 4, 2])
minimum(0:9)
minimum(9:-1:0)
minimum([2, 3, 0, 3, 4, 0, 5, 7, 4, 2])
prod(1:2:10)
sum(1:10)
sum(x^2 for x in 1:11)
sum(x^2 for x in 1:11 if isodd(x); init = 0)
"""

# Works in FoldsCUDA but not with CUDADevice:
#=
prod(y for x in 1:11 if isodd(x) for y in 1:x:x^2; init = 1)
=#

tests = parse_tests(rawdata, @__MODULE__)

get_executors(device) = [
    KAEx(device; groupsize = 1, basesize = 1),
    KAEx(device; groupsize = 1, basesize = 3),
    KAEx(device; groupsize = 3, basesize = 1),
    KAEx(device; groupsize = 3, basesize = 3),
]
