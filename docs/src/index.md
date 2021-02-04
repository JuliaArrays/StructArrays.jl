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
StructArray(::Base.UndefInitializer, sz::Dims)
StructArray(v)
collect_structarray
```

# Accessors

```@docs
fieldarrays
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
StructArrays._map_params
StructArrays.buildfromschema
StructArrays.bypass_constructor
StructArrays.iscompatible
```