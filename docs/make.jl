using Documenter
using Ghost

makedocs(
    sitename = "Ghost",
    format = Documenter.HTML(),
    modules = [Ghost],
    pages = [
        "Main" => "index.md",
        "Linearized traces" => "trace.md",
        "Tape anatomy" => "tape.md",
        "Loops" => "loops.md",
        "Reference" => "reference.md",
    ],
)

# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.
#=deploydocs(
    repo = "<repository url>"
)=#
