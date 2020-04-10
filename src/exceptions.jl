import Base.showerror

struct NMRToolsException <: Exception
    message::String
end

Base.showerror(io::IO, e::NMRToolsException) = printstyled(io, "(NMRTools) " * e.message, color=:red)
