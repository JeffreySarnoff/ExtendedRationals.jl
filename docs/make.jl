using ExtendedRationals
using Documenter

makedocs(;
    doctest=false,
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
        "Strict Rationals (Q32/Q64)" => "strict.md",
        "Extended Rationals (Qx32/Qx64)" => "extended.md",
        "Usage Guide" => "guide.md",
        "API Reference" => "api.md",
    ],
    warnonly=[:missing_docs, :parse_error, :autodocs_block],
)

deploydocs(;
    repo="github.com/JeffreySarnoff/ExtendedRationals.jl",
    devbranch="main",
    push_preview=true,
)
