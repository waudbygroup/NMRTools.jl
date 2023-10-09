"""
    pcls(A, y)

Compute the phase-constrained least squares solution:
```math
y = A x e^{i\\phi}
```
following the algorithm of Bydder (2010) *Lin Alg & Apps*.

Returns the tuple `(x, ϕ)`, containing the component amplitudes and global phase.

If passed a matrix `Y`, the function will return a matrix of component amplitudes and
a list of global phases corresponding to each row.

# Arguments
- `A`: (m,n) complex matrix with component spectra
- `y`: (m,) complex vector containing the observed spectrum
"""
function pcls(A::AbstractMatrix, y::AbstractVector)
    invM = pinv(real(A' * A))
    AHy = A' * y
    ϕ = 0.5 * angle(transpose(AHy) * invM * AHy)
    x = invM * real(AHy * exp(-im * ϕ))
    return x, ϕ
end

function pcls(A::AbstractMatrix, B::AbstractMatrix)
    n = size(A, 2)
    t = size(B, 2)
    X = zeros(n, t)
    Φ = zeros(t)

    invM = pinv(real(A' * A))

    for i in 1:t
        AHb = A' * B[:, i]
        ϕ = 0.5 * angle(transpose(AHb) * invM * AHb)
        X[:, i] = invM * real(AHb * exp(-im * ϕ))
        Φ[i] = ϕ
    end

    return X, Φ
end

# function pcls(A::AbstractMatrix, b::AbstractVector, invM)
#     AHb = A' * b
#     ϕ = 0.5 * angle(transpose(AHb) * invM * AHb)
#     x = invM * real(AHb * exp(-im*ϕ))
#     return x, ϕ
# end

# function plan_pcls(A::AbstractMatrix)
#     return pinv(real(A' * A))
# end
