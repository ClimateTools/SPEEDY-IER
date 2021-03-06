
      SUBROUTINE CULND(WTWB,WTWG,WTRUN,WTDRN,PRECNV,PRECLS,EVAP,
     &                 RLD,RB,FMASK,SOILW)
C
C Subroutine CULND
C   Updates the simple 2 bucket land model of Deardorff (1977), 
C   adapted for water isotope tracers.
C   This is an updated version of the scheme in MUGCM (see Noone and
C   Simmonds, 2002), and code has been formatted to be SPEEDY-fied.
C
C   [Notice this also works over the ocean. Could form the basis of a
C   simple ocean mixed layer model, but would need a deep ocean
C   relaxation term, rather than draining to empty.]
C
C
C) ONLY RUN THIS SUBROUTINE IF WE ARE AT A LAND POINT.
C
C David Noone <dcn@colorado.edu> - Wed Mar 28 16:42:27 MDT 2012
C Sylvia Dee <sdee@usc.edu> - Mon Aug 13 11:40:00 PST 2012
C
C--   Tracers are assumed:
C--   ITR=1     Q	: normal water vapor (mass) mixing ratio

C     Define all variables
C     Input-only
C     PRECLS = large-scale precipitation 	[g/(m^2 s)]   	(2-dim)
C     PRECNV = convective precipitation 	[g/(m^2 s)]     (2-dim)
C     EVAP   = evaporation 			[g/(m^2 s)]     (2-dim)

C ! Pass these back through SUFLUX, and there we will calculate the isotope ratio of evap. 
C ! Next look through we'll pass it the isotopic composition of the soil water, and then we'll pass that to the evaporation.


C     Input/output
C       WTWB                    bulk water		[m^3/m^3]
C       WTWG                    ground water 		[m^3/m^3]
C       RLD						land isotope ratio

C     Output
C       WTRUN                   runoff			[g/m^2 s]
C       WTDRN                   subsurface drainage	[g/m^2 s]
C

C     Other variables
C      WBXS			bulk excess 		[m^3/m^3]
C      WGXS			ground water excess 	[m^3/m^3]


C     Resolution parameters
C
      include "atparam.h"
      include "atparam1.h"
C
      PARAMETER ( NLON=IX, NLAT=IL, NLEV=KX, NGP=NLON*NLAT )

C     Physical constants + functions of sigma and latitude

      include "com_physcon.h"

C     Large-scale condensation constants

      include "com_lsccon.h"

C     Isotope tracer constants

      include "com_isocon.h"

C     Time parameters
      include "com_tsteps.h"
      include "com_date.h"

C 
C     External isotope fractionation functions
C

C      REAL ALPLIQ, ALPKOC
C      REAL D

C
C Input variables 
C
      REAL EVAP(NGP,3,NTR)
      REAL PRECLS(NGP,NTR)
      REAL PRECNV(NGP,NTR)
      REAL FMASK(NGP)

C
C Input/output variables (Tracer soil water fields)
C 
      REAL WTWB(NGP,NTR)			
      REAL WTWG(NGP,NTR)
      REAL WTRUN(NGP,NTR)
      REAL WTDRN(NGP,NTR)
      REAL RLD(NGP,NTR), RB(NGP,NTR)
      REAL SOILW(NGP)

C
C Working variables
C
      REAL WBXS(NGP,NTR)
      REAL WGXS(NGP,NTR)
      REAL PREC(NGP,NTR)
      INTEGER ITR, J

C
C Parameters
C

      REAL wgmax , wbmax
      REAL d1    , d2
      REAL wtiny 
      REAL tau1  
      REAL rhow  

      parameter(wgmax = 0.4)              ! ground max volumetic content (m^3/m^3)
      parameter(wbmax = 0.32)             ! bulk max volumetic content (m^3/m^3)
      parameter(d1    = 0.10)             ! depth of upper layer (meters)
      parameter(d2    = 0.50)             ! depth of both layers (meters)
      parameter(wtiny = 0.01)             ! trivial amount to retain ratio
      parameter(tau1  = 7.0*86400.)           ! upper damping scale (seconds)
      parameter(rhow  = 1.0e+06)          ! density of water (g/m^3)

C=========================================================

C 0) Initialize Soil Water Values 

C--SDEE:(choices: can do 0 for all tracers, put some water in it with a prescribed ratio.
      
      if (IDAY .eq. 1) then		! initialize to smow
        DO ITR = 1, NTR
          DO J = 1, NGP
            if (FMASK(J) .gt. 0.0) then
              	wtwb(J,1)= wbmax
		wtwb(J,2)= wbmax
		wtwb(J,3)= wbmax*(1.-(80./1000.))
		wtwb(J,4)= wbmax*(1.-(10./1000.))
             	wtwg(J,1)= wgmax
		wtwg(J,2)= wgmax
		wtwg(J,3)= wgmax*(1.-(80./1000.))
		wtwg(J,4)= wgmax*(1.-(10./1000.))
            endif
          ENDDO
        ENDDO
      endif
      
C=========================================================

C=========================================================
C=========================================================

C 2) Update surface reservoirs:  dbucket = P - E - drain - Runoff

      DO J = 1, NGP
        if (FMASK(J) .gt. 0.0) then

C=========================================================
C Set Constants (Deardorff C1, C2)

C        DO ITR = 1, NTR

        C1 = 0.9
        wet = (wtwg(J,1)/wgmax)
        
        if (wet .ge. 0.75) then
           C2 = 0.5
        else if (wet .le. 0.15) then
           C2 = 14.0
        else if ((wet.lt.0.75) .and. (wet.gt.0.15)) then
           C2 = 14.0 - 22.5*(wet-0.15)
        else 
           C2=1.0
        endif
C=========================================================
CC Update the state for WB and WG, for all tracers
C (Notice, here we allow for the posability for negative or
C oversaturated soil - these will be handled explictly below (dcn)

        DO ITR=1,NTR
          dwb = (PRECNV(J,ITR)+PRECLS(J,ITR))/(d2*rhow)
          dwg = C1*(PRECNV(J,ITR)+PRECLS(J,ITR)-
     &          (1-fracT)*EVAP(J,1,ITR))/(d1*rhow)
C          dwg = dwg - C2*(wtwg(J,ITR)-wtwb(J,ITR))/tau1    ! drain/recharge

          wtwg(J,ITR) = wtwg(J,ITR) + DELT*dwg
          wtwb(J,ITR) = wtwb(J,ITR) + DELT*dwb

        ENDDO
C=========================================================
C=========================================================

C Ensure that excess water (runoff) is the well-mixed combination of original soil
C water and any additional precipitation.

	if (wtwb(J,1) .gt. wbmax) then
	  fac_b = wbmax/wtwb(J,1)
              DO ITR = 1, NTR
	      wtwb(J,ITR) = wtwb(J,ITR)*fac_b
              ENDDO
        endif

C Check that wtwb is not negative (should never be, but lets check)
        if (wtwb(J,1) .le. 0.0) then
C           write(*,*) 'WTWB < 0:',WTWB(J,ITR),J
C           write(*,*) '  Setting WTWB for all tracers to zero'
           do ITR = 1, NTR
             wtwb(J,ITR) = 0.0
           end do
         endif

C check WTWB for all other tracers (slightly different, but also
C should never happen)
         DO ITR = 2, NTR
           if (wtwb(J,ITR) .le. 0.0) then
C              write(*,*) 'WTWB < 0 (tracer)',WTWB(J,ITR),J,ITR
C              write(*,*) 'setting tracer water to zero - good luck!'
              wtwb(J,ITR) = 0.0
           endif
        ENDDO
C=========================================================	 
C=========================================================	    
C Check the mass balance for WG
C If oversaturated, allow runoff and preserve the isotope ratio

	if (wtwg(J,1) .gt. wgmax) then
	  fac_g = wgmax/wtwg(J,1)
            DO ITR = 1, NTR
	      wtwg(J,ITR) = wtwg(J,ITR)*fac_g
            ENDDO
       
C=========================================================

! case of REQUIRED recharge.

        else 
	  deficit = wgmax-wtwg(J,1)
          DO ITR = 2, NTR
              if (WTWB(J,1) .gt. 0.99*wtiny) then 
	        Rbulk = wtwb(J,ITR)/wtwb(J,1)
              else
		Rbulk = 0.
              endif
              wtwg(J,ITR)=wtwg(J,ITR)+deficit*Rbulk
	  ENDDO

          wtwg(J,1) = wtwg(J,1)+deficit

       endif
C=========================================================

! If total has dried up apply the saved isotope ratio so that we have
! something sensible to evaporate next time
!
            if (wtwb(J,1) .le. wtiny) then
              wtwb(J,1) = wtiny
              do ITR = 2, NTR
                wtwb(J,ITR) = RLD(J,ITR)*wtwb(J,1)
              enddo
            endif
C=========================================================         

      
C 1) Prescribe ratio for fluxes based on surface scheme
C SDEE--note we can remove this if we opt for the more elegant scheme at bottom of code.

           DO ITR = 1, NTR
              
              if (wtwg(J,1) .gt. wtiny) then
               RLD(J,ITR) = (wtwg(J,ITR)/wtwg(J,1))
               RB(J,ITR) = (wtwb(J,ITR)/wtwb(J,1))
              else if (wtwb(J,1) .gt. 0.99*wtiny) then 
               RLD(J,ITR) = (wtwb(J,ITR)/wtwb(J,1))
               RB(J,ITR) = RLD(J,ITR)
              else                                        	! buckets are dry, assign smow?
               RLD(J,ITR) = Rlnd(ITR)  			
              endif

            ENDDO
     
          endif
      ENDDO 


C
      RETURN
      END       

