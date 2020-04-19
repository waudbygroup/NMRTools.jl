#!/bin/csh

foreach i (2 3 4 5 6 7 8 9 10 11 12)

echo "Processing spectrum $i ..."
echo

bruk2pipe -in ./$i/fid \
  -bad 0.0 -ext -aswap -AMX -decim 1418.66666666667 -dspfvs 20 -grpdly 67.9896545410156  \
  -xN             28416  \
  -xT             14097  \
  -xMODE            DQD  \
  -xSW        14097.744  \
  -xOBS         470.522  \
  -xCAR        -130.000  \
  -xLAB             19F  \
  -ndim               1  \
  -out ./test.fid -verb -ov

nmrPipe -in test.fid \
| nmrPipe -fn EM  -lb 5.0 -c 0.5                              \
#| nmrPipe  -fn ZF -auto                               \
| nmrPipe  -fn FT -auto                               \
| nmrPipe  -fn PS -p0 49.00 -p1 0.00 -di -verb         \
| nmrPipe -fn BASE -nw 50 -nl -119ppm -140ppm           \
| nmrPipe -fn EXT -x1 -121.5ppm -xn -124.5ppm -sw                                    \
   -ov -out ./$i/test.ft1

rm test.fid

end

