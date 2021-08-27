push!(LOAD_PATH, dirname(@__DIR__))

using Documenter
using StructArrays

makedocs(
    sitename = "StructArrays",
    format = Documenter.HTML(prettyurls = get(ENV, "CI", nothing) == "true"),
    modules = [StructArrays],
    pages = [
            "Overview"=>"index.md",
            "Example usage"=>"examples.md",
            "Some counterintuitive behaviors"=>"counterintuitive.md",
            "Advanced techniques"=>"advanced.md",
            "Index"=>"reference.md",
            ]
)

# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.
deploydocs(
    repo = "github.com/JuliaArrays/StructArrays.jl.git",
    push_preview = true,
)
