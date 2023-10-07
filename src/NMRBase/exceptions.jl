"""
    NMRToolsError(message)

An error arising in NMRTools.
"""
struct NMRToolsError <: Exception
    message::String
end
