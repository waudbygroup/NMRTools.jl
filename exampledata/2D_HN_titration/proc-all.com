#!/bin/csh

foreach spec (1 2 3 4 5 6 7 8 9 10 11)
cd $spec
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
nmrPipe -in test.fid \
| nmrPipe -fn SOL                                     \
| nmrPipe -fn EM  -lb 4.0 -c 0.5                      \
| nmrPipe  -fn ZF -auto                               \
| nmrPipe  -fn FT -auto                               \
| nmrPipe  -fn PS -p0 152.00 -p1 -65.00 -di -verb     \
| nmrPipe -fn EXT -x1 6ppm -xn 12ppm -sw              \
| nmrPipe -fn BASE -nw 10 -nl 0% 2%  98% 100%         \
| nmrPipe  -fn TP                                     \
| nmrPipe -fn LP -fb                                  \
| nmrPipe -fn EM  -lb 8.0 -c 1.0                      \
| nmrPipe  -fn ZF -auto                               \
| nmrPipe  -fn FT -auto                               \
| nmrPipe  -fn PS -p0 -90.00 -p1 180.00 -di -verb     \
   -ov -out test.ft2
rm test.fid
cd ..
end

# process expt 2 separately, needs different 1H phasing
cd 2
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
nmrPipe -in test.fid \
| nmrPipe -fn SOL                                     \
| nmrPipe -fn EM  -lb 4.0 -c 0.5                      \
| nmrPipe  -fn ZF -auto                               \
| nmrPipe  -fn FT -auto                               \
| nmrPipe  -fn PS -p0 -102.00 -p1 -65.00 -di -verb    \
| nmrPipe -fn EXT -x1 6ppm -xn 12ppm -sw              \
| nmrPipe -fn BASE -nw 10 -nl 0% 2% 98% 100%          \
| nmrPipe  -fn TP                                     \
| nmrPipe -fn LP -fb                                  \
| nmrPipe -fn EM  -lb 8.0 -c 1.0                      \
| nmrPipe  -fn ZF -auto                               \
| nmrPipe  -fn FT -auto                               \
| nmrPipe  -fn PS -p0 -90.00 -p1 180.00 -di -verb     \
   -ov -out test.ft2
rm test.fid
mv test.ft2 ../test-2.ft2
cd ..
