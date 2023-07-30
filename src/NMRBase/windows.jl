# WindowFunction
#     NullWindow
#     UnknownWindow
#     ExponentialWindow

abstract type WindowFunction end

"""
    NullWindow(tmax)

No apodization applied.
"""
struct NullWindow <: WindowFunction
    tmax::Float64
    NullWindow(tmax=Inf) = new(tmax)
end

"""
    UnknownWindow(tmax)

Unknown apodization applied.
"""
struct UnknownWindow <: WindowFunction
    tmax::Float64
    UnknownWindow(tmax=Inf) = new(tmax)
end


"""
    ExponentialWindow(lb, tmax)

EM: Exponential Multiply Window.
 -lb    expHz  [0.0]  Exponential Broaden, Hz. (Q1)
"""
struct ExponentialWindow <: WindowFunction
    lb::Float64
    tmax::Float64
    ExponentialWindow(lb=0.0, tmax=Inf) = new(lb, tmax)
end

"""
    SineWindow(offset, endpoint, power, tmax)

SP: Adjustable Sine Window. [SINE]
 -off   offset [0.0]  Sine Start*PI.  (Q1)
 -end   end    [1.0]  Sine End*PI.    (Q2)
 -pow   exp    [1.0]  Sine Exponent.  (Q3)
 """
abstract type SineWindow <: WindowFunction end
function SineWindow(offset=0.0, endpoint=1.0, power=1.0, tmax=Inf)
    if power ≈ 1.0 && offset ≈ 0.5
        return CosWindow(endpoint * tmax)
    elseif power ≈ 2.0 && offset ≈ 0.5
        return Cos²Window(endpoint * tmax)
    else
        return GeneralSineWindow(offset, endpoint, power, tmax)
    end
end

struct GeneralSineWindow <: SineWindow
    offset::Float64
    endpoint::Float64
    power::Float64
    tmax::Float64
end

struct CosWindow <: SineWindow
    tmax::Float64
end

struct Cos²Window <: SineWindow
    tmax::Float64
end


"""
GaussWindow(expHz, gaussHz, center, tmax)

GM: Lorentz-to-Gauss Window.
 -g1    expHz   [0.0]  Inverse Exponential, Hz. (Q1)
 -g2    gausHz  [0.0]  Gaussian Width, Hz.      (Q2)
 -g3    center  [0.0]  Center, 0 to 1.          (Q3)
"""
abstract type GaussWindow <: WindowFunction end
function GaussWindow(expHz=0.0, gaussHz=0.0, center=0.0, tmax=Inf)
    if center ≈ 0.0
        return LorentzToGaussWindow(expHz, gaussHz, tmax)
    else
        return GeneralGaussWindow(expHz, gaussHz, center, tmax)
    end
end

struct GeneralGaussWindow <: GaussWindow
    expHz::Float64
    gaussHz::Float64
    center::Float64
    tmax::Float64
    GeneralGaussWindow(expHz=0.0, gaussHz=0.0, center=0.0, tmax=Inf) = new(expHz, gaussHz, center, tmax)
end

struct LorentzToGaussWindow <: GaussWindow
    expHz::Float64
    gaussHz::Float64
    tmax::Float64
    LorentzToGaussWindow(expHz=0.0, gaussHz=0.0, tmax=Inf) = new(expHz, gaussHz, tmax)
end


abstract type LineshapeComplexity end
struct RealLineshape <: LineshapeComplexity end
struct ComplexLineshape <: LineshapeComplexity end

## lineshapes for various window functions
function lineshape(ax, δ, R2, complexity::LineshapeComplexity)
    lineshape(getω(ax, δ), R2, getω(ax), ax[:window], complexity)
end
lineshape(ax, δ, R2) = lineshape(ax, δ, R2, RealLineshape()) # default to a real return type


# generic case - return a default Lorentzian

function lineshape(ω, R, ωax, ::WindowFunction, ::RealLineshape)
    @. R / ((ωax - ω)^2 + R^2)
end

function lineshape(ω, R, ωax, ::WindowFunction, ::ComplexLineshape)
    @. 1 / (R + 1im*(ω - ωax))
end


# exponential functions

function lineshape(ω, R, ωax, w::ExponentialWindow, ::ComplexLineshape)
    x = @. R + 1im*(ω - ωax) + π*w.lb
    T = w.tmax

    return @. (1 - exp(-T*x)) / x
end
lineshape(ω, R, ωax, w::ExponentialWindow, ::RealLineshape) = real(lineshape(ω, R, ωax, w, ComplexLineshape()))


# cosine

function lineshape(ω, R, ωax, w::CosWindow, ::ComplexLineshape)
    x = @. R + 1im*(ω - ωax)
    T = w.tmax
    Tx = T * x
    return @. 2 * T * (π*exp(-Tx) + 2*Tx) / (π^2 + 4*Tx^2)
end
lineshape(ω, R, ωax, w::CosWindow, ::RealLineshape) = real(lineshape(ω, R, ωax, w, ComplexLineshape()))
  
function lineshape(ω, R, ωax, w::Cos²Window, ::ComplexLineshape)
    x = @. R + 1im*(ω - ωax)
    Tx = w.tmax * x
    
    return @. (π^2*(1-exp(-Tx)) + 2*Tx^2) / (2 * (π^2 + Tx^2) * x)
end
lineshape(ω, R, ωax, w::Cos²Window, ::RealLineshape) = real(lineshape(ω, R, ωax, w, ComplexLineshape()))
  
Base.Broadcast.broadcastable(w::WindowFunction) = Ref(w)



"""
    apod(spec::NMRData, dimension)

Return the time-domain apodization function for the specified axis,
as a vector of values.
"""
apod(spec::NMRData, dimension, zerofill=true) = apod(dims(spec,dimension), zerofill)

function apod(ax::FrequencyDimension, zerofill=true)
    td = ax[:td]
    sw = ax[:swhz]
    window = ax[:window]
    
    dt = 1/sw
    t = dt * (0:(td-1))
    
    if zerofill
        tdzf = ax[:tdzf]
        w = zeros(tdzf)
    else
        w = zeros(td)
    end
    w[1:td] = apod(t, window)

    return w
end

# function apod(t, w::WindowFunction)
#     @warn "time-domain apodization function not yet defined for window $w - treating as no apodization"
#     ones(length(t))
# end

apod(t, ::NullWindow) = ones(length(t))
apod(t, w::ExponentialWindow) = exp.(-π * w.lb * t)
apod(t, w::GeneralSineWindow) = @. sin(π*w.offset + π*((w.endpoint - w.offset) * t / w.tmax))^w.power
apod(t, w::CosWindow) = @. cos(π/2 * t / w.tmax)
apod(t, w::Cos²Window) = @. cos(π/2 * t / w.tmax)^2
