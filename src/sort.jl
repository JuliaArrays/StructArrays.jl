isdiscrete(v) = false

function Base.permute!(c::StructVector, p::AbstractVector)
    foreachcolumn(c) do v
        if isdiscrete(v) || v isa StructVector
            permute!(v, p)
        else
            copyto!(v, v[p])
        end
    end
    return c
end
