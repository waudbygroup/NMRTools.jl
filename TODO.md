# NMRTools.jl TODO list

- [ ] Import (multi)complex spectra
- [ ] Load raw time-domain data
- [ ] Export data


## failure importing complex 2D

```
dat = loadnmr("exampledata/2D_HN/1/pdata/1"; allcomponents=true)
┌ Warning: import of multicomplex data not yet implemented - returning real values only
└ @ NMRTools.NMRIO ~/.julia/dev/NMRTools/src/NMRIO/bruker.jl:174
ERROR: BoundsError: attempt to access 4-element Vector{Matrix{Float64}} at index [1:1216, 1:512]
Stacktrace:
 [1] throw_boundserror(A::Vector{Matrix{Float64}}, I::Tuple{UnitRange{Int64}, UnitRange{Int64}})
   @ Base ./abstractarray.jl:744
 [2] checkbounds
   @ ./abstractarray.jl:709 [inlined]
 [3] _getindex
   @ ./multidimensional.jl:860 [inlined]
 [4] getindex(::Vector{Matrix{Float64}}, ::UnitRange{Int64}, ::UnitRange{Int64})
   @ Base ./abstractarray.jl:1294
 [5] loadpdata(filename::String, allcomponents::Bool)
   @ NMRTools.NMRIO ~/.julia/dev/NMRTools/src/NMRIO/bruker.jl:184
 [6] loadnmr(filename::String; experimentfolder::Nothing, allcomponents::Bool)
   @ NMRTools.NMRIO ~/.julia/dev/NMRTools/src/NMRIO/loadnmr.jl:43
 [7] top-level scope
   @ REPL[15]:1
```