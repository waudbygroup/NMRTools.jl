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
