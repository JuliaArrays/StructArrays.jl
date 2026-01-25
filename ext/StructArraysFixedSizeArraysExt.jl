module StructArraysFixedSizeArraysExt

using StructArrays
using FixedSizeArrays: FixedSizeArrayDefault

export fixed_size_array_backed_initializer

fixed_size_array_of(::Type{S}, d::NTuple{N, Any}) where {S, N} = similar(FixedSizeArrayDefault{S, N}, d)

const fixed_size_array_backed_initializer = StructArrays.StructArrayInitializer(StructArrays.alwaysfalse, fixed_size_array_of)

# Make `fixed_size_array_backed_initializer` available in `StructArrays` using this hack
# https://github.com/itsdfish/PackageExtensionsExample.jl/blob/41581ab0371cf512ace5dd063f7e7935effbb256/ext/DistributionsExt.jl#L28
function __init__()
    Threads.@spawn begin
        sleep(0.01)
        Core.eval(
            StructArrays,
            quote
                ext = Base.get_extension(StructArrays, :StructArraysFixedSizeArraysExt)
                using .ext
                VERSION >= v"1.11.0-DEV.469" && eval(Meta.parse("public fixed_size_array_backed_initializer"))
            end
        )
    end
end

end
