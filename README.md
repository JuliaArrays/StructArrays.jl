# StructArrays

[![CI](https://github.com/JuliaArrays/StructArrays.jl/workflows/CI/badge.svg?branch=master)](https://github.com/JuliaArrays/StructArrays.jl/actions?query=workflow%3ACI+branch%3Amaster)
[![codecov.io](http://codecov.io/github/JuliaArrays/StructArrays.jl/coverage.svg?branch=master)](http://codecov.io/github/JuliaArrays/StructArrays.jl?branch=master)
[![](https://img.shields.io/badge/docs-stable-blue.svg)](https://JuliaArrays.github.io/StructArrays.jl/stable)

This package defines an array type, `StructArray`, which acts like an array of `struct` elements but which internally is stored as a list of arrays, typically one per field of the `struct`. See the [documentation](https://JuliaArrays.github.io/StructArrays.jl/stable) for details.
