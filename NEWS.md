# NEWS

## Version 0.6.0

### Breaking

- Static arrays are automatically unwrapped when creating a `StructArray{<:StaticArray}` [#186](https://github.com/JuliaArrays/StructArrays.jl/pull/186)

### New features

- `pop!` is now supported on `StructVector`s [#190](https://github.com/JuliaArrays/StructArrays.jl/pull/190)

## Version 0.5.0

### Breaking

- Renamed `fieldarrays` to `StructArrays.components` [#167](https://github.com/JuliaArrays/StructArrays.jl/pull/167)
- `getproperty` is no longer used to access fields of a struct. It is replaced by `StructArrays.component(x, i)` [#167](https://github.com/JuliaArrays/StructArrays.jl/pull/167). This is only relevant for structs with custom layout.
- Inner constructors are bypassed on `getindex` [#145](https://github.com/JuliaArrays/StructArrays.jl/pull/136)
- Broadcast on `StructArray`s now returns a `StructArray` [#136](https://github.com/JuliaArrays/StructArrays.jl/pull/136)

## Version 0.4.0

### Breaking

- `fieldarrays` now returns a tuple of arrays for a `StructArray{<:Tuple}`
- `push!` now only works if the `StructArray` and the element have the same propertynames
- The special constructor `StructArray(first_col => last_col)` is no longer supported

## Version 0.2.0

### Breaking

- Renamed `columns` to `fieldarrays`
- `StructArray{T}(args...)` has been deprecated in favor of `StructArray{T}(args::Tuple)`

### New features

- Added `collect_structarray` function to collect an iterable of structs into a `StructArray` without having to allocate an array of structs
- `StructArray{T}(undef, dims)` and `StructArray(v::AbstractArray)` now support an `unwrap` keyword argument to specify on which types to do recursive unnesting of array of structs to struct of arrays
