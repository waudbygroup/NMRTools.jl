TITAN: FIR / FBP Nbox example and walkthrough
=============================================

- FIR / FBP Nbox 1H,15N-HMQC titration (Cukier 2010, NSMB)
- raw NMR data can be found in experiment folders 1-11
- data can be processed in nmrPipe with `proc-all.com` to give `test-1.ft2` etc.
- run `TITAN` to launch GUI:
    - `TITAN_session_initial.mat`: example session with experimental parameters set up, and ROIs selected, before fitting
    - `TITAN_session_fitted.mat`: example session after fitting and bootstrap error analysis
- `analysis.m` contains a scripted walkthrough of the analysis procedure
