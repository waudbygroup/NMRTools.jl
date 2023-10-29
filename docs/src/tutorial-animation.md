# Animating spectra

The plot recipes defined within NMRTools provide an easy way to generate animations of spectral data, using the `@animate` macro defined within the Plots package. A couple of examples are provided below.

## Phosphorylation kinetics

First, load in some data. This pseudo-3D kinetic data - a series of 1H,15N SOFAST-HMQC spectra - showing the progressive phosphorylation of cJun by JNK1 kinase. Read more about the paper here: [Waudby et al. Nat Commun (2022)](https://www.nature.com/articles/s41467-022-33866-w).

```@example 1
using NMRTools, Plots

spec=loadnmr("../../exampledata/pseudo3D_kinetics/1")
nothing # hide
```

The data have been processed in Topspin using `ftnd 3` and `ftnd 2`, so that the final dimension of the 3D represents the phosphorylation time. Each 2D plane took 2 minutes to acquire, and there was an initial delay of 4 min between adding the kinase and recording the first free induction decay. We need to calculate a list of times from this information, that we can use to label the animation:

```@example 1
# get number of time points
nt = size(spec,3)

# calculate a list of measurement times
# experiment was recorded with 2 min per spectrum, plus initial dead-time of 4 min
tmin = LinRange(0, 2*(nt-1), nt) .+ 4
thr = tmin / 60
```

Now we can generate the animation, by looping over each point in the time series with the Plots `@animate` macro, then saving as an animated gif.

```@example 1
anim = @animate for i=1:nt
    # generate a nice title with the time rounded to 1 decimal place, e.g. "Time elapsed: 0.1 hr"
    titletext = "Time elapsed: $(round(thr[i],digits=1)) hr"
    plot(spec[:,:,i], title=titletext)
end

# save as an animated gif
gif(anim, "kinetics.gif", fps=30)
nothing # hide
```

![](kinetics.gif)


## 2D titration

First, load in some data - as described in the [tutorial on plotting](@ref "Overlaying multiple 2D spectra").

```@example 1
filenames = ["../../exampledata/2D_HN_titration/1/test.ft2",
             "../../exampledata/2D_HN_titration/2/test.ft2",
             "../../exampledata/2D_HN_titration/3/test.ft2",
             "../../exampledata/2D_HN_titration/4/test.ft2",
             "../../exampledata/2D_HN_titration/5/test.ft2",
             "../../exampledata/2D_HN_titration/6/test.ft2",
             "../../exampledata/2D_HN_titration/7/test.ft2",
             "../../exampledata/2D_HN_titration/8/test.ft2",
             "../../exampledata/2D_HN_titration/9/test.ft2",
             "../../exampledata/2D_HN_titration/10/test.ft2",
             "../../exampledata/2D_HN_titration/11/test.ft2"]
spectra2d = map(loadnmr, filenames)
nothing # hide
```

Now loop over the spectra to produce the animation:

```@example 1
anim=@animate for spec in spectra2d
    plot(spec, xlims=(6,10.5), title=label(spec))
end

gif(anim, "titration.gif", fps=8)
nothing # hide
```

![](titration.gif)

Note that spectra have been normalised automatically to account for differences in their number of scans or receiver gain.