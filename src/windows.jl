abstract type WindowFunction end

"""
NullWindow()

No apodization applied.
"""
struct NullWindow <: WindowFunction end

"""
UnknownWindow()

Unknown apodization applied.
"""
struct UnknownWindow <: WindowFunction end

"""
ExponentialWindow(lb)

EM: Exponential Multiply Window.
 -lb    expHz  [0.0]  Exponential Broaden, Hz. (Q1)
"""
struct ExponentialWindow <: WindowFunction
    lb::Float64
    ExponentialWindow(lb=0.0) = new(lb)
end

"""
SineWindow(offset, endpoint, power)

SP: Adjustable Sine Window. [SINE]
 -off   offset [0.0]  Sine Start*PI.  (Q1)
 -end   end    [1.0]  Sine End*PI.    (Q2)
 -pow   exp    [1.0]  Sine Exponent.  (Q3)
 """
struct SineWindow <: WindowFunction
    offset::Float64
    endpoint::Float64
    power::Float64
    SineWindow(offset=0.0, endpoint=1.0, power=1.0) = new(offset, endpoint, power)
end

"""
GaussWindow(expHz, gaussHz, center)

GM: Lorentz-to-Gauss Window.
 -g1    expHz   [0.0]  Inverse Exponential, Hz. (Q1)
 -g2    gausHz  [0.0]  Gaussian Width, Hz.      (Q2)
 -g3    center  [0.0]  Center, 0 to 1.          (Q3)
"""
struct GaussWindow <: WindowFunction
    expHz::Float64
    gaussHz::Float64
    center::Float64
    GaussWindow(expHz=0.0, gaussHz=0.0, center=0.0) = new(expHz, gaussHz, center)
end
