using ExtendedRationals
using Documenter

DocMeta.setdocmeta!(ExtendedRationals, :DocTestSetup, :(using ExtendedRationals); recursive=true)

makedocs(;
    modules=[ExtendedRationals],
    authors="Jeffrey Sarnoff <jeffrey.sarnoff@gmail.com>",
    repo="https://github.com/JeffreySarnoff/ExtendedRationals.jl/blob/{commit}{path}#{line}",
    sitename="ExtendedRationals.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://JeffreySarnoff.github.io/ExtendedRationals.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/JeffreySarnoff/ExtendedRationals.jl",
    devbranch="main",
)
