#!/bin/csh

bruk2pipe -in ./fid \
  -bad 0.0 -ext -aswap -DMX -decim 1418.66666666667 -dspfvs 20 -grpdly 67.9896545410156  \
  -xN             28416  \
  -xT             14097  \
  -xMODE            DQD  \
  -xSW        14097.744  \
  -xOBS         470.522  \
  -xCAR        -130.000  \
  -xLAB             19F  \
  -ndim               1  \
  -out ./test2.fid -verb -ov

