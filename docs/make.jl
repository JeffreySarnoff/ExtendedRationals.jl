using XRationals
using Documenter

makedocs(;
    doctest=false,
    modules=[XRationals],
    authors="Jeffrey Sarnoff <jeffrey.sarnoff@gmail.com>",
    repo="https://github.com/JeffreySarnoff/XRationals.jl/blob/{commit}{path}#{line}",
    sitename="XRationals.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://JeffreySarnoff.github.io/XRationals.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        "Strict Rationals (Rational32/Rational64)" => "strict.md",
        "Extended Rationals (Qx32/Qx64)" => "extended.md",
        "Usage Guide" => "guide.md",
        "API Reference" => "api.md",
    ],
    warnonly=[:missing_docs, :parse_error, :autodocs_block],
)

deploydocs(;
    repo="github.com/JeffreySarnoff/XRationals.jl",
    devbranch="main",
    push_preview=true,
)
