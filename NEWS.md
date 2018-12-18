# NEWS

## Version 0.2.0

### Breaking

- Renamed `columns` to `fieldarrays`
- `StructArray{T}(args...)` has been deprecated in favor of `StructArray{T}(args::Tuple)`

### New features

- Added `collect_structarray` function to collect an iterable of structs into a `StructArray` without having to allocate an array of structs
- `StructArray{T}(undef, dims)` and `StructArray(v::AbstractArray)` now support an `unwrap` keyword argument to specify on which types to do recursive unnesting of array of structs to struct of arrays

