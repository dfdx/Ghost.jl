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

deploydocs(
    repo = "github.com/dfdx/Ghost.jl.git",
    devbranch = "main",
)