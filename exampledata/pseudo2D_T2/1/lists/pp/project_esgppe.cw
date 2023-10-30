; project_esgppe.cw
; PROJECT sequence with perfect echo watergate
;
; J.A. Aguilar, M. Nilsson, G. Bodenhausen and G. Morris
; Chem. Commun. (2012) 48 811-813
;
; run as pseudo-2D
; with presaturation
;
; Chris Waudby
; updated Nov 2022 to add perfect echo watergate

#include <Avance.incl>
#include <Grad.incl>
#include <Delay.incl>

prosol relations=<triple>

define list<loopcounter> vclist = <$VCLIST>


"p2=p1*2"
"p27=p1"
"d2=1m"
"d3=4*d2"  ; T2 time per loop
"d12=20u"
"DELTA1=d2-p1"
"DELTA2=d2-1.5*p1"
"acqt0=-0.6366*p1"

1 ze
2 30m

  ; presaturation
  d12 pl9:f1
  d1 cw:f1 ph29
  4u do:f1
  d12 pl1:f1 

  ; begin PROJECT sequence
  p1 ph1
3 DELTA1
  p2 ph2
  DELTA2
  p1 ph3
  DELTA2
  p2 ph2
  DELTA1
  lo to 3 times vclist

  ; perfect echo watergate
  50u UNBLKGRAD
  p16:gp1
  d16 ;pl18:f1
  p27*0.087 ph13
  d19*2
  p27*0.206 ph13
  d19*2
  p27*0.413 ph13
  d19*2
  p27*0.778 ph13
  d19*2
  p27*1.491 ph13
  d19*2
  p27*1.491 ph14
  d19*2
  p27*0.778 ph14
  d19*2
  p27*0.413 ph14
  d19*2
  p27*0.206 ph14
  d19*2
  p27*0.087 ph14
  50u
  p16:gp1
  d16 pl1:f1

  p1 ph10


  50u 
  p16:gp2
  d16 ;pl18:f1
  p27*0.087 ph15
  d19*2
  p27*0.206 ph15
  d19*2
  p27*0.413 ph15
  d19*2
  p27*0.778 ph15
  d19*2
  p27*1.491 ph15
  d19*2
  p27*1.491 ph16
  d19*2
  p27*0.778 ph16
  d19*2
  p27*0.413 ph16
  d19*2
  p27*0.206 ph16
  d19*2
  p27*0.087 ph16
  p16:gp2
  d16
  50u BLKGRAD

  go=2 ph31
  30m mc #0 to 2
      F1QF(vclist.inc)
exit

ph1= 0 2
ph2= 1
ph3= 1 1 3 3
ph10=1
ph13=0 0 0 0 1 1 1 1 2 2 2 2 3 3 3 3 
ph14=2 2 2 2 3 3 3 3 0 0 0 0 1 1 1 1
ph15=0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
     1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1
     2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2
     3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3
ph16=2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2
     3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3
     0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
     1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1
ph29=0
ph31=0 2 0 2 2 0 2 0 0 2 0 2 2 0 2 0
     2 0 2 0 0 2 0 2 2 0 2 0 0 2 0 2

;pl1: f1 channel - power level for pulse (default)
;pl9: f1 channel - power level for presaturation
;p1 : f1 channel - 90 degree excitation pulse
;p2 : f1 channel - 180 degree refocusing pulse
;p16: homospoil/gradient pulse
;p27: f1 channel -  90 degree pulse for watergate
;d1 : relaxation delay; 1-5 * T1
;d2 : tau (T2 time = 4*d2*vc) [1 ms]
;d3 : total T2 time per loop
;d12: delay for power switching [20 usec]
;d16: delay for homospoil/gradient recovery
;d19: delay for binomial water suppression
;     d19 = (1/(2*d)), d = distance of next null (in Hz)
;ns : 16*n
;ds : 8

;use gradient ratio:    gp 1 : gp 2
;                         34 :   22

;for z-only gradients:
;gpz1: 34%
;gpz2: 22%

;use gradient files:
;gpnam1: SINE.100
;gpnam2: SINE.100
