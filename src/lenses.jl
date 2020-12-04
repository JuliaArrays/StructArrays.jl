using BangBang
using Setfield

lenses(nt::NamedTuple) = _lenses(nt, ())
lenses(NT::Type{NamedTuple{K,V}}) where {K,V} = lenses(fromtype(NT))

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

function _lenses(::Type{A}, acc) where {A <: AbstractArray}
    return (Setfield.compose(acc...),)
end

nt = (a=(b=[1,2],c=(d=[3,4],e=[5,6])),f=[7,8]);

lenses(nt)
lenses(typeof(nt))
