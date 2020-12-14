using BangBang
using Setfield

"""
    lenses(t::Tuple)
    lenses(nt::NamedTuple)
    lenses(NT::Type{NamedTuple{K,V}})

Build a Tuple of lenses for a given value or type

Example:
    julia> nt = (a=(b=[1,2],c=(d=[3,4],e=[5,6])),f=[7,8]);

    julia> lenses(nt)
    ((@lens _.a.b), (@lens _.a.c.d), (@lens _.a.c.e), (@lens _.f))

    julia> lenses(typeof(nt))
    ((@lens _.a.b), (@lens _.a.c.d), (@lens _.a.c.e), (@lens _.f))
"""
function lenses end

lenses(t::Tuple) = _lenses(t, ())

lenses(nt::NamedTuple) = _lenses(nt, ())
lenses(NT::Type{NamedTuple{K,V}}) where {K,V} = lenses(fromtype(NT))

function _lenses(t::Tuple, acc)
    result = ()
    for (k,v) in enumerate(t)
        acc_k = push!!(acc, Setfield.IndexLens((k,)))
        ℓ = _lenses(v, acc_k)
        result = append!!(result, ℓ)
    end
    return result
end

function _lenses(nt::NamedTuple, acc)
    result = ()
    for k in keys(nt)
        nt_k = getproperty(nt, k)
        # Add "breadcrumb" steps to the accumulator as we descend into the tree
        acc_k = push!!(acc, Setfield.PropertyLens{k}())
        ℓ = _lenses(nt_k, acc_k)
        result = append!!(result, ℓ)
    end
    return result
end

# When we reach a leaf node (an array), compose the steps to get a lens
function _lenses(a::AbstractArray, acc)
    return (Setfield.compose(acc...),)
end

function _lenses(::Type{T}, acc) where {T}
    return (Setfield.compose(acc...),)
end
