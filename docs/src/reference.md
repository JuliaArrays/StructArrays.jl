# StructArrays.jl


```@meta
CurrentModule = StructArrays
```

# Type

```@docs
StructArray
```

# Constructors

```@docs
StructArray(tup::Union{Tuple,NamedTuple})
StructArray(::AbstractArray)
StructArray(::Base.UndefInitializer, sz::Dims)
StructArray(v)
collect_structarray
```

# Accessors

```@docs
StructArrays.components
```

# Lazy iteration

```@docs
LazyRow
LazyRows
```

# Advanced APIs

```@docs
StructArrays.append!!
StructArrays.replace_storage
```

# Interface

```@docs
StructArrays.staticschema
StructArrays.component
StructArrays.createinstance
```

# Internals

```@docs
StructArrays.get_ith
StructArrays.map_params
StructArrays.buildfromschema
StructArrays.bypass_constructor
StructArrays.iscompatible
StructArrays.maybe_convert_elt
StructArrays.findconsistentvalue
```