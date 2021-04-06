"""
    KAEx(device; groupsize, basesize)

Transducers.jl executor implemented using KernelAbstractions.jl.
"""
struct KAEx{D,K} <: Executor
    device::D
    kwargs::K
end

KAEx(device; kwargs...) = KAEx(device, (; kwargs...))

popsimd(; simd = nothing, kwargs...) = kwargs

Transducers.transduce(xf, rf::RF, init, xs, exc::KAEx) where {RF} =
    transduce_ka(xf, rf, init, xs, exc.device; popsimd(; exc.kwargs...)...)

# TODO: Once `groupsize` and `basesize` can be auto-tuned for non-CUDA GPUs,
# hook `KAEx` into the executor promotion mechanism.

function Base.show(io::IO, exc::KAEx)
    @nospecialize exc
    T = typeof(exc.kwargs)
    if (
        fieldtype(typeof(exc), 2) !== typeof(exc.kwargs) ||
        any(i -> typeof(exc.kwargs[i]) != fieldtype(T, i), 1:nfields(exc.kwargs))
    )
        return invoke(show, Tuple{IO,Any}, io, exc)
    end
    print(io, KAEx, "(::", typeof(exc.device), "; ")
    isfirst = true
    for (k, v) in pairs(exc.kwargs)
        isfirst || print(io, ", ")
        isfirst = false
        print(io, k, " = ", v)
    end
    print(io, ")")
    return
end
