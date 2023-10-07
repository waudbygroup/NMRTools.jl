"""
    bar(x[, y])

Compute the Bar index between `x` and `y`.

```math
\LaTeX
```

If `y` is unspecified, compute the Bar index between all pairs of columns of `x`.

# Arguments
- `n::Integer`: the number of elements to compute.
- `dim::Integer=1`: the dimensions along which to perform the computation.

# Examples
```jldoctest
julia> a = [1 2; 3 4]
2×2 Array{Int64,2}:
 1  2
 3  4
```

See also [`bar!`](@ref), [`baz`](@ref), [`baaz`](@ref).
"""