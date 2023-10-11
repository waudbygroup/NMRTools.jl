"""
    FQ(value, unit::Symbol, relative::Bool)

Represent a frequency e.g. from a frequency list. `unit` can be `:Hz` or `:ppm`, and `relative`
indicates whether the frequency is given relative to SFO (true) or BF (false).
"""
struct FQ
    value
    unit::Symbol
    relative::Bool
end

