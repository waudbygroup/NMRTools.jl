#!/bin/csh

bruk2pipe -in ./ser \
  -bad 0.0 -ext -aswap -AMX -decim 1312 -dspfvs 20 -grpdly 67.9841003417969  \
  -xN              4096  -yN                11  -zN               320  \
  -xT              2048  -yT                11  -zT               160  \
  -xMODE            DQD  -yMODE           Real  -zMODE  Echo-AntiEcho  \
  -xSW        15243.902  -ySW           11.000  -zSW         2051.703  \
  -xOBS         899.794  -yOBS           1.000  -zOBS          91.186  \
  -xCAR           4.773  -yCAR           0.000  -zCAR         117.811  \
  -xLAB              HN  -yLAB             TAU  -zLAB             15N  \
  -ndim               3  -aq2D         Complex                         \
| nmrPipe -fn TP  | nmrPipe -fn ZTP  | nmrPipe -fn TP -hyper \
| pipe2xyz -out ./fid/test%03d.fid -verb -ov

xyz2pipe -in fid/test%03d.fid -x -verb              \
| nmrPipe  -fn SOL                                  \
| nmrPipe -fn SP -off 0.4 -end 0.98 -pow 1 -c 0.5  \
| nmrPipe  -fn ZF -auto                             \
| nmrPipe  -fn FT                                   \
| nmrPipe  -fn PS -p0 65 -p1 0.0 -di               \
| nmrPipe  -fn EXT -xn 8.8ppm -x1 7.6ppm -sw           \
| nmrPipe  -fn TP                                   \
| nmrPipe  -fn LP -fb                               \
| nmrPipe -fn SP -off 0.5 -end 0.98 -pow 2 -c 0.5  \
| nmrPipe  -fn ZF -auto                             \
| nmrPipe  -fn FT -neg                                  \
| nmrPipe  -fn PS -p0 90.0 -p1 0.0 -di               \
| pipe2xyz -out ftx/test%03d.ft2 -x

cp ft/test001.ft2 first-plane.ft2
sethdr first-plane.ft2 -ndim 2 -zN 1 -zT 1
pipe2ucsf first-plane.ft2 first-plane.ucsf

awk '{print $1*0.02808711}' vclist > tau

awk '{printf "sethdr ft/test%03d.ft2 -tau %g\n", NR, $1*0.02808711}' vclist > settau.com
echo "setting tau values:"
cat settau.com
chmod +x settau.com
./settau.com

echo "autoFit.tcl -specName ft/test%03d.ft2 -inTab test.tab -series"
echo "modelExp.tcl nlin.tab nlin.spec.list 0"
