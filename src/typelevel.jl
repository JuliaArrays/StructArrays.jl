using NamedTupleTools: namedtuple

ntkeys(::Type{NamedTuple{K,V}}) where {K, V} = K
ntvaltype(::Type{NamedTuple{K,V}}) where {K, V} = V

"""
    fromtype(::Type)
    
`fromtype` turns a type into a value that's easier to work with.

Example:

    julia> nt = (a=(b=[1,2],c=(d=[3,4],e=[5,6])),f=[7,8]);

    julia> NT = typeof(nt)
    NamedTuple{(:a, :f),Tuple{NamedTuple{(:b, :c),Tuple{Array{Int64,1},NamedTuple{(:d, :e),Tuple{Array{Int64,1},Array{Int64,1}}}}},Array{Int64,1}}}

    julia> fromtype(NT)
    (a = (b = Array{Int64,1}, c = (d = Array{Int64,1}, e = Array{Int64,1})), f = Array{Int64,1})
"""
function fromtype end

function fromtype(NT::Type{NamedTuple{names, T}}) where {names, T}
    return namedtuple(ntkeys(NT), fromtype(ntvaltype(NT)))
end

function fromtype(TT::Type{T}) where {T <: Tuple} 
    return fromtype.(Tuple(TT.types))
end

fromtype(T) = T
