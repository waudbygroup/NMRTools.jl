#!/bin/csh

bruk2pipe -in ./ser \
  -bad 0.0 -ext -aswap -AMX -decim 2000 -dspfvs 20 -grpdly 67.9862518310547  \
  -xN              1024  -yN                10  \
  -xT               512  -yT                10  \
  -xMODE            DQD  -yMODE           Real  \
  -xSW        10000.000  -ySW           10.000  \
  -xOBS         499.852  -yOBS           1.000  \
  -xCAR           4.916  -yCAR           0.000  \
  -xLAB              1H  -yLAB             TAU  \
  -ndim               2  -aq2D         Complex  \
  -out ./test.fid -verb -ov

