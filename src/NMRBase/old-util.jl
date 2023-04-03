"""
    closest(A, x)

Return the index of the array entry closest in value to `x`. If there are multiple closest entries,
then the first one will be returned.

# Example

```julia
julia> closest([-1, -0.5, 0.5], 0)
2

julia> closest([1 2 3
                4 5 6], 5.8)
CartesianIndex(2, 3)
```
"""
closest(A::AbstractArray, x) = findmin(abs.(A.-x))[2]


logrange(x1, x2, n=50) = (10^y for y in range(log10(x1), log10(x2), length=n))
