#!/bin/csh

bruk2pipe -in ./ser \
  -bad 0.0 -noaswap -AMX -decim 16 -dspfvs 12 -grpdly -1  \
  -xN              2048  -yN               256  \
  -xT              1024  -yT               128  \
  -xMODE            DQD  -yMODE    States-TPPI  \
  -xSW         9615.385  -ySW         1823.985  \
  -xOBS         599.927  -yOBS          60.797  \
  -xCAR           4.611  -yCAR         118.959  \
  -xLAB              HN  -yLAB             15N  \
  -ndim               2  -aq2D          States  \
  -out ./test.fid -verb -ov

