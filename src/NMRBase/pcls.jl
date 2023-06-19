"""
    pcls(A, b)

Compute a phase constrained least squares solution
following the algorithm of Bydder (2010) Lin Alg & Apps

Inputs:
    A - (m,n) complex matrix of components
    b - (m,) complex vector with observed spectrum
"""
function pcls(A::AbstractMatrix, b::AbstractVector)
    invM = pinv(real(A' * A))
    AHb = A' * b
    ϕ = 0.5 * angle(transpose(AHb) * invM * AHb)
    x = invM * real(AHb * exp(-im*ϕ))
    return x, ϕ
end


"""
    pcls(A, B)

Compute a phase constrained least squares solution
following the algorithm of Bydder (2010) Lin Alg & Apps

Inputs:
    A - (m,n) complex matrix of components
    B - (m,t) complex matrix with observed spectra over time

Outputs:
    X - (n,t) amplitudes over time
    ϕ - (t,) phases over time
"""
function pcls(A::AbstractMatrix, B::AbstractMatrix)
    n = size(A, 2)
    t = size(B, 2)
    X = zeros(n,t)
    Φ = zeros(t)
    
    invM = pinv(real(A' * A))

    for i=1:t
        AHb = A' * B[:,i]
        ϕ = 0.5 * angle(transpose(AHb) * invM * AHb)
        X[:,i] = invM * real(AHb * exp(-im*ϕ))
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
    