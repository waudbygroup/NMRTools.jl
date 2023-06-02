#!/bin/csh -f

set specName    = ft/test%03d.ft2
set simName     = sim/test%03d.ft2
set simDir      = sim
set difName     = dif/test%03d.ft2
set difDir      = dif
set inTabName   = test.tab
set auxTabName  = axt.tab
set outTabName  = nlin.tab
set errTabName  = err.nlin.tab
set noiseRMS    = 268617.968750
set specCount   = 11

set aRegSizeX  = 5
set dRegSizeX  = 5
set maxDX      = 1.0
set minXW      = 0.0
set maxXW      = 7.52
set simSizeX   = 292

set aRegSizeY  = 4
set dRegSizeY  = 4
set maxDY      = 1.0
set minYW      = 0.0
set maxYW      = 6.25
set simSizeY   = 1024

set aRegSizeZ  = 11
set dRegSizeZ  = 11
set maxDZ      = 2.75
set minZW      = 0.0
set maxZW      = 22.00
set simSizeZ   = 11


seriesTab -in  $inTabName -list nlin.spec.list \
 -dx  $dRegSizeX -dy  $dRegSizeY \
 -adx $aRegSizeX -ady $aRegSizeY \
 -xzf 64 -yzf 64 -max \
 -out $auxTabName -adVar VOL -verb


nlinLS -tol 1.0e-8 -maxf 750 -iter 750 \
 -in $auxTabName -out $outTabName -list nlin.spec.list \
 -apod  None \
 -noise $noiseRMS \
 -mod    GAUSS1D  GAUSS1D  SCALE1D  \
 -delta  X_AXIS $maxDX  Y_AXIS $maxDY  \
 -limit  XW $minXW $maxXW YW $minYW $maxYW \
 -w      $dRegSizeX  $dRegSizeY  $dRegSizeZ  \
 -nots -norm -ppm

if (!(-e $simDir)) then
   mkdir $simDir
endif

xyz2pipe -in $specName -verb \
| nmrPipe -fn SET -r 0.0 \
| pipe2xyz -out $simName -ov

simSpecND -in $outTabName -list sim.spec.list \
          -mod   GAUSS1D  GAUSS1D  SCALE1D  \
          -w     $simSizeX  $simSizeY  $simSizeZ  \
          -apod None -nots -verb


if (!(-e $difDir)) then
   mkdir $difDir
endif

addNMR -in1 $specName -in2 $simName -out $difName -sub
