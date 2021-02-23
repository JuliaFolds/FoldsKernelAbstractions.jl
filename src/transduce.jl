transduce_ka(xf::Transducer, op, init, xs, device; groupsize, basesize) =
    transduce_ka(xf'(op), init, xs, device, groupsize, basesize)

function transduce_ka(op, init, xs, device, groupsize, basesize)
    groupsize = max(groupsize, 1)
    basesize = max(basesize, 2)
    xf0, coll = extract_transducer(xs)
    if coll isa Iterators.Zip
        arrays = coll.is
        xf = xf0
    else
        arrays = (coll,)
        xf = opcompose(Map(first), xf0)
    end
    rf = _reducingfunction(xf, op; init = init)
    acc = transduce_impl(device, groupsize, basesize, rf, init, arrays...)
    result = complete(rf, acc)
    if unreduced(result) isa DefaultInitOf
        throw(EmptyResultError(rf))
    end
    return result
end

function transduce_impl(device, groupsize, basesize, rf::F, init, arrays...) where {F}
    (ys, buf) = transduce!(nothing, device, groupsize, basesize, rf, init, arrays...)
    # @info "ys, = transduce!(nothing, rf, ...)" ys
    length(ys) == 1 && return @allowscalar ys[1]
    monoid = asmonoid(always_combine(rf))
    rf2 = Map(first)'(monoid)  # TODO: reduce wrapping
    dest = ys
    while true
        ys, = transduce!(buf, device, groupsize, basesize, rf2, InitialValue(monoid), ys)
        # @info "ys, = transduce!(buf, rf2, ...)" ys
        length(ys) == 1 && return @allowscalar ys[1]
        dest, buf = buf, dest
        # reusing buffer; is it useful?
    end
end

function fake_transduce(rf, xs, init)
    acc1 = next(rf, start(rf, init), first(xs))
    for x in xs
        acc1 = next(rf, acc1, x)
    end
    acc2 = acc1
    for x in xs
        acc2 = next(rf, acc2, x)
    end
    ys = [acc1, acc2]
    acc3 = acc2
    for y in ys
        acc3 = _combine(rf, acc3, y)
    end
    return acc3
end

valueof(::Val{x}) where {x} = x
valueof(x) = x

instantiate_kernel(f, device, ::Nothing) = f(device)
instantiate_kernel(f, device, groupsize) = f(device, valueof(groupsize))

Base.@propagate_inbounds getvalues(i) = ()
Base.@propagate_inbounds getvalues(i, a) = (a[i],)
Base.@propagate_inbounds getvalues(i, a, as...) = (a[i], getvalues(i, as...)...)

function transduce!(
    buf,
    device,
    groupsize,
    basesize,
    rf::F,
    init,
    arrays...,
) where {F}
    idx = eachindex(arrays...)
    n = Int(length(idx))  # e.g., `length(UInt64(0):UInt64(1))` is not an `Int`

    acctype = if buf === nothing
        # global _ARGS = (rf, zip(arrays...), init)
        # @show fake_transduce(rf, zip(arrays...), init)
        return_type(fake_transduce, Tuple{Typeof(rf),Typeof(zip(arrays...)),Typeof(init)})
        # Note: the result of `return_type` is not observable by the
        # caller of the API `transduce_impl`
    else
        eltype(buf)
    end
    # @show acctype

    function compute_sizes(n)
        local nbasecases = cld(n, basesize)
        local groupsize′ = min(nbasecases, nextpow(2, groupsize))
        local blocks = cld(nbasecases, groupsize′)
        return (blocks, groupsize′, nbasecases)
    end
    blocks, groupsize′, nbasecases = compute_sizes(n)
    if buf === nothing
        next_blocks, = compute_sizes(blocks)
        dest_buf = arrayfor(device){acctype}(undef, blocks + next_blocks)
        dest = view(dest_buf, 1:blocks)
        buf = view(dest_buf, blocks+1:length(dest_buf))
    else
        dest = view(buf, 1:blocks)
    end
    # @show nbasecases, blocks, basesize, groupsize, groupsize′

    ev = instantiate_kernel(transduce_kernel!, device, groupsize′)(
        dest,
        rf,
        init,
        basesize,
        nbasecases,
        idx,
        arrays...;
        ndrange = nbasecases,
    )
    wait(ev)
    # TODO: use `dependencies`

    return dest, buf
end

@kernel function transduce_kernel!(
    dest::AbstractArray{T},
    rf::F,
    init,
    basesize,
    nbasecases,
    idx,
    arrays...,
) where {F,T}
    # basecase
    n = @uniform length(idx)
    ill = @index(Local, Linear)
    igl = @index(Group, Linear)
    offset = ill - 1 + (igl - 1) * groupsize()[1]

    i1 = offset * basesize + 1
    if i1 <= n
        x1 = @inbounds getvalues(idx[i1], arrays...)
    else
        x1 = @inbounds getvalues(idx[1], arrays...) # random value (not used)
    end
    acc = next(rf, start(rf, init), x1)
    for i in offset*basesize+2:min((offset + 1) * basesize, n)
        x = @inbounds getvalues(idx[i], arrays...)
        acc = next(rf, acc, x)
    end

    # combineblock
    offsetb = @uniform (igl - 1) * groupsize()[1]
    bound = @uniform max(0, nbasecases - offsetb)

    # shared mem for a complete reduction
    shared = @localmem(T, (2 * groupsize()[1]))
    @inbounds shared[ill] = acc

    m = @private Int (1,)
    t = @private Int (1,)
    s = @private Int (1,)
    c = @private Int (1,)
    m = ill - 1
    t = ill
    s = 1
    c = nextpow(2, groupsize()[1]) >> 1
    while c != 0
        @synchronize
        if t + s <= bound && iseven(m)
            @inbounds shared[t] = _combine(rf, shared[t], shared[t+s])
            m >>= 1
        end
        s <<= 1
        c >>= 1
    end

    if t == 1
        @inbounds dest[igl] = shared[1]
    end
end

function always_combine(rf::F) where {F}
    @inline function op(a, b)
        _combine(rf, a, b)
    end
    return op
end

# Semantically correct but inefficient (eager) handling of `Reduced`.
@inline _combine(rf, a::Reduced, b::Reduced) = a
@inline _combine(rf, a::Reduced, b) = a
@inline _combine(rf::RF, a, b::Reduced) where {RF} = reduced(combine(rf, a, unreduced(b)))
@inline _combine(rf::RF, a, b) where {RF} = combine(rf, a, b)
