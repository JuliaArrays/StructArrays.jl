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

# Advanced APIs

```@docs
StructArrays.append!!
StructArrays.replace_storage
StructArrays.staticschema
StructArrays.createinstance
```

# Internals

```@docs
StructArrays.bypass_constructor
StructArrays.iscompatible
```