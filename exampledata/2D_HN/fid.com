#!/bin/csh

bruk2pipe -in ./ser \
  -bad 0.0 -ext -aswap -AMX -decim 1848 -dspfvs 21 -grpdly 76  \
  -xN              2048  -yN               128  \
  -xT              1024  -yT                64  \
  -xMODE            DQD  -yMODE    States-TPPI  \
  -xSW        10822.511  -ySW         1337.972  \
  -xOBS         600.203  -yOBS          60.825  \
  -xCAR           4.974  -yCAR         118.285  \
  -xLAB              HN  -yLAB             15N  \
  -ndim               2  -aq2D         Complex  \
  -out ./test.fid -verb -ov

