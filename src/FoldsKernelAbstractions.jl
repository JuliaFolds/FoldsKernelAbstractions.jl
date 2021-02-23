module FoldsKernelAbstractions

export KAEx

using Core.Compiler: return_type
using Core: Typeof
using GPUArrays: @allowscalar
using InitialValues: InitialValue, asmonoid
using KernelAbstractions
using Requires: @require
using Transducers:
    Executor,
    Map,
    Reduced,
    Transducer,
    Transducers,
    combine,
    complete,
    next,
    opcompose,
    reduced,
    start,
    unreduced

# TODO: Don't import internals from Transducers:
using Transducers:
    DefaultInit,
    DefaultInitOf,
    EmptyResultError,
    IdentityTransducer,
    _reducingfunction,
    extract_transducer

include("transduce.jl")
include("api.jl")

arrayfor(::CPU) = Array

function __init__()
    @require CUDA="052768ef-5323-5732-b1bb-66c8b64840ba" begin
        @require CUDAKernels="72cfdca4-0801-4ab0-bf6a-d52aa10adc57" begin
            arrayfor(::CUDAKernels.CUDADevice) = CUDA.CuArray
        end
    end
    @require AMDGPU="21141c5a-9bdb-4563-92ae-f87d6854732e" begin
        @require ROCKernels="7eb9e9f0-4bd3-4c4c-8bef-26bd9629d9b9" begin
            arrayfor(::ROCKernels.ROCDevice) = AMDGPU.ROCArray
        end
    end
end

# Use README as the docstring of the module:
@doc let path = joinpath(dirname(@__DIR__), "README.md")
    include_dependency(path)
    doc = read(path, String)
    doc = replace(doc, r"^```julia"m => "```jldoctest README")
    doc
end FoldsKernelAbstractions

end
