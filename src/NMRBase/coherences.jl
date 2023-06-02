# Coherence
#     SQ
#     MQ

abstract type Coherence end

"""
    SQ(nucleus, label=="")

Representation of a single.
"""
struct SQ <: Coherence
    nucleus::Nucleus
    label::String
    SQ(nuc, label="") = new(nuc, label)
end

"""
    MQ(coherences, label=="")

Representation of a multiple-quantum transition.

e.g. ``
"""
struct MQ <: Coherence
    transitions::Tuple{Vararg{Tuple{Nucleus,Int}}}
    label::String
    MQ(transitions, label="") = new(transitions, label)
end

"""
    coherenceorder(coherence)

Calculate the total coherence order.

````
coherenceorder(SQ(H1)) == 1
coherenceorder(MQ(((H1,1),(C13,1)))) == 2
coherenceorder(MQ(((H1,1),(C13,-1)))) == 0
coherenceorder(MQ(((H1,3),(C13,1)))) == 4
coherenceorder(MQ(((H1,0),))) == 0
````
"""
coherenceorder(c::SQ) = 1
function coherenceorder(c::MQ)
    return sum([t[2] for t ∈ c.transitions])
end

"""
    γeff(coherence)

Calculate the effective gyromagnetic ratio of the coherence. This is equal to
the product of the individual gyromagnetic ratios with their coherence orders.

````
γeff(SQ(H1)) == 2.6752218744e8
γeff(MQ(((H1,1),(C13,1)))) == 3.3480498744e8
γeff(MQ(((H1,1),(C13,-1)))) == 2.0023938744e8
γeff(MQ(((H1,3),(C13,1)))) == 8.698493623199999e8
γeff(MQ(((H1,0),))) == 0
````
"""
γeff(c::SQ) = gyromagneticratio(c.nucleus)
function γeff(c::MQ)
    return sum([gyromagneticratio(t[1])*t[2] for t ∈ c.transitions])
end
