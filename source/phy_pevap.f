
      SUBROUTINE PEVAP(FEQ,TA,QA,QSAT,DQLSC,DTLSC,PRECLS)

C
C Subroutine PEVAP
C Purpose: Calculate evaporation of falling rain in each vertical layer.
C
C Sylvia Dee <sdee@usc.edu> - Tuesday, Sept. 20, 2011
C (Modified David Noone <dcn@colorado.edu> - Thu Sep 22 17:27:45 MDT 2011)
C (Bug fixes, David Noone <dcn@colorado.edu> - Wed Mar 21 07:57:18 MDT 2012)
C
C--   Tracers are assumed:
C--   ITR=1     Q	: normal water vapor (mass) mixing ratio

C     Define all variables
C     Input-only
C       FEQ		Fractional equilibration (drop size dependent)
C       TA              Temperature [K]                            (3-dim)
C       QA              specific humidity [g/kg]                   (3-dim)
C       QSAT            saturation specific humidity [g/kg]        (3-dim)
C
C     Input/output
C       DQLSC           hum. tendency [g/(kg s)] from cond         (3-dim)
C       DTLSC           latent heating tendency [K/s]              (3-dim)
C
C     Output
C       PRECLS          precipitation [g/(m^2 s)]                  (2-dim)

C     Other variables
C       EVAPPREC         evaporation RATE of water in a level (k) [g/(m^2 s)] 
C       HUM              relative humidity at level k
C       PFACT            DSIG(K)*PRG 
C       TFACT            ALHC/CP



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

C     External isotope fractionation functions
      REAL ALPLIQ, ALPKEX

C
C Input variables
C
      REAL FEQ
      REAL TA(NGP,NLEV)
      REAL QA(NGP,NLEV,NTR)
      REAL QSAT(NGP,NLEV)

C
C Input/output variables
C
      REAL DQLSC(NGP,NLEV,NTR)
      REAL DTLSC(NGP,NLEV)
      REAL PRECLS(NGP,NTR)
C
C Working variables
C
      REAL EVAPPREC(NGP,NTR)
      REAL EVAPTOT(NGP,NTR)
      REAL Ke, TFACT, PFACT
      REAl HUM
      REAL PRG
      REAL Pnew
      REAL ALPEQ, ALPHA
      INTEGER ITR, J, K

C Check the tendency is always negative on entry. 
      DO K = 1, NLEV
        DO J = 1, NGP
          if (DQLSC(J,K,1) .gt. 0.) then 
             write(*,*) 'PEVAP: DQLCS > 0',J,K,DQLSC(J,K,1)
          endif
        END DO
      END DO

C Define Constants 

      Ke = 0.03
C      Ke = 0.030
C      Ke = 0.036
C      Ke = 0.175
C      Ke = 6.5e-2
C      Ke = 1.0e-2
C      Ke = 5.0e-3
      
C Define TFACT and PRG

      TFACT = ALHC/CP
      PRG = P0/GG

     
C Initialize precipitation flux array
C and do special case of precipitation at the top level

      PFACT = DSIG(1)*PRG
      DO ITR=1,NTR
        DO J = 1,NGP
          EVAPTOT(J,ITR) = 0.
          EVAPPREC(J,ITR) = 0.
          PRECLS(J,ITR) = -PFACT*DQLSC(J,1,ITR)

C       if (j.eq.1063) then
C        write(*,*) 'DB1:',1,itr,precls(j,ITR),EVAPPREC(j,ITR), 
C     &                DQLSC(j,1,ITR)
C       endif
        ENDDO
      ENDDO

C
C Loop from top down below the top layer
C
      DO K=2,NLEV

C Initialize precipitation at this level

         PFACT = DSIG(K)*PRG
         DO ITR=1,NTR
           DO J=1,NGP
              EVAPPREC(J,ITR)=0
           ENDDO
         ENDDO

         DO J = 1, NGP


C Total water calculations:

          HUM = min(QA(J,K,1)/QSAT(J,K),1.0)

C Only allow evaporation if this layer is not precipitating (i.e., DQLSC eq 0)

           if (DQLSC(j,k,1) .ge. 0.0) then

C The following should never happen. dqlsc = 0 is what we expect.
             if (DQLSC(J,K,1) .gt. 0.0) then
               write(*,*) 'PEVAP: Why is DQLSC>0?:',j,k,DQLSC(J,K,1)
             endif

C Compute rate at which randrops evaporate to the local large-scale
C subsaturation, and the rate at which 
C convective rainwater is made available to the subsaturated model
C layer' as per CAM:
             

C             EVAPPREC(J,1)=Ke*(1.-heff)*sqrt(max(PRECLS(J,1),0.))
             EVAPPREC(J,1)=Ke*(1.-HUM)*sqrt(max(PRECLS(J,1),0.))

     
C
C Ensure that total evaporation does not exceed input precipitation in a
C given level:
C
C SDEE CHECK
             EVAPPREC(J,1) = min(EVAPPREC(J,1), PRECLS(J,1))

           endif            

C
C Isotope tracers:
C   Rain tends toward equilibrium with environment vapor.
C   Conserve isotope ratio for the tracers if ice (or small)
C   (This can occur even if evapprec = 0)
C   [NEED TO MODIFY ALPHA TO INCLUDE KINETIC EFFECTS, a-la Stewart 1975]
C
C             if (j.eq.1063) then
C               write(*,*)'DBE:',k,1,EVAPPREC(J,1),precls(j,1)
C             endif

           DO ITR=2,NTR

CC -- Super simple, non-fractionating. And works.
CC             fevp = EVAPPREC(J,1)/PRECLS(J,1)
CC             EVAPPREC(J,ITR) = fevp*PRECLS(J,ITR)


             if (PRECLS(j,ixh2o) .lt. ptiny) then
               Rini = 1.		! why not 0?
             else
               Rini = PRECLS(J,ITR)/PRECLS(J,ixh2o)
             endif
             if (QA(J,k,ixh2o) .lt. qtiny) then 
               Rvap = 1.		! why not 0?
             else
               Rvap = QA(J,k,ITR)/QA(J,k,ixh2o)
             endif

             alpeq = alpliq(ITR,TA(J,K))

C             HUM = (QA(J,K,1)/QSAT(J,K))

C sdee 4/5/12 heff must be calculated as per Bony et al. A3: heff can be equal to the relative humidity (heff = hb) or it
C can be heff = phi*hs + (1-phi)*hb where hs = relative hum at saturation = 1, and hb is the relative humidity. Bony et al. find 
C phi = 0.9 yields the most reasonable Deuterium-excess values. HUM = hb. Phi = fheff here, and is defined in com_isocon.h.

             heff = (fheff + (1.00-fheff)*HUM)
C             heff = min(heff,0.9999)

C try Yoshimura 2008 parameterization for heff:
C             heff = max((1.4*HUM),1.0)

C             heff = min(0.99,max(0.6,1.4*HUM))

C set DDN explicitly to solve numerical problems.


              if (ITR .EQ. 3) then
                ddn = 1.01449096
              else if (ITR .EQ. 4) then  
                ddn = 1.01642616
              else if (ITR .EQ. 2) then 
                ddn = 1.0
              endif

CCCCCCCCC Calculate R Precip via Stewart (1975) CCCCCCCCCCCCCCC
             if (TA(J,K) .lt. TMELT) then
                Rprec = Rini
             else
CC                Rprec = (1.-FEQ)*Rini + FEQ*Reql
                if (PRECLS(J,1) .gt. qtiny) then
                  ff = (PRECLS(J,1)-EVAPPREC(J,1))/(PRECLS(J,1))
                  ff = min(ff,0.9999)
                  ff = max(ff,0.0)
C                  if (J .eq. 2000) then 
C                    write(*,*) "ff=", ff
C                  endif
C                  ddn = (1./difr(ITR))**enn
                  if (heff .lt. 0.999) then
                  beta = (1.-alpeq*ddn*(1.-heff))/
     &            (alpeq*ddn*(1.-heff))
                  gam = (alpeq*heff)/(1.-alpeq*ddn*(1.-heff))
                  Rprec = FEQ*((Rini-gam*Rvap)*ff**beta + (gam*Rvap))
     &                  + (1.0-FEQ)*Rini
C                  write(*,*)"ddn,B,gam,Rprec,Rini,Rvap,a,ff",ddn,beta,
C     &                       gam,Rprec,Rini,Rvap,alpeq,ff
                  else 
                    Rprec = alpeq*Rvap
                  endif
                else 
                  Rprec = 0.
                endif

             endif

             Pnew = Rprec*(PRECLS(J,1) - EVAPPREC(J,1))
             EVAPPREC(J,ITR) = PRECLS(J,ITR) - omeps*Pnew


C             if (j.eq.1063) then
C               write(*,*)'DBEiso:',k,itr,EVAPPREC(J,ITR),precls(j,itr),
C     &                      Rprec,Rini,Reql
C             endif

           ENDDO

C             heff = (fheff + (1.00-fheff)*HUM)
C             if (heff .lt. 1.0) then
C               alpha = alpkex(ITR,ALPEQ,heff)
C             else
C               alpha = alpeq
C             endif

C             Reql = Rvap*alpha

C             if (TA(J,K) .lt. TMELT) then
C                Rprec = Rini
C             else
C                Rprec = (1.-FEQ)*Rini + FEQ*Reql
C             endif

C             Pnew = Rprec*(PRECLS(J,1) - EVAPPREC(J,1))
C             EVAPPREC(J,ITR) = PRECLS(J,ITR) - omeps*Pnew

C           ENDDO

C All the rain was evaporated. Hard code complete evap of tracers.
C (This helps isotope ratios in cases trivial amounts of water)

           IF (abs(PRECLS(J,1) - EVAPPREC(J,1)) .lt. qtiny) then
              do ITR = 2, NTR
                 EVAPPREC(J,ITR) = PRECLS(J,ITR)
              enddo
           ENDIF


C SDEE: is there maybe too much evaporation? Causing high RH?
C Update the state tendencies and remove evap from the precip
C  and add precipitation formed at this layer to the amount falling
C
          DO ITR= 1, NTR
            PRECLS (J,ITR) = PRECLS (J,ITR) - EVAPPREC(J,ITR)
            EVAPTOT(J,ITR) = EVAPTOT(J,ITR) + EVAPPREC(J,ITR)
            DQLSC(J,K,ITR) = DQLSC(J,K,ITR) + EVAPPREC(J,ITR)/PFACT

C          if (precls(J,ITR) .lt. 0.) then
C           write(*,*) 'PEVAP: after evpPRC<0:',j,k,itr,precls(j,itr),
C     &                 EVAPPREC(J,itr),DQLSC(j,k,itr)
C           endif               


          ENDDO
C
C Remove latent heat from temperature profile
C
          DTLSC(J,K) = DTLSC(J,K) - TFACT*(EVAPPREC(J,1)/PFACT)
C
C Update remaining precipitation with formation of precip at this layer. 
C Don't do this if there is evaporation at this layer. (This should in theory
C protect us against negative precipitation values but it's not...)
C SDEE changed this to be ITR. sometimes the isotopes have a different sign for DQLSC. not sure whetehr this will cause a problem.
C
          if (DQLSC(j,k,1) .lt. 0) then					! evaporation in the layer
C          if (DQLSC(j,k,ITR) .lt. 0) then				! evaporation in the layer
            do ITR = 1, NTR
              PRECLS(J,ITR) = PRECLS(J,ITR) - PFACT*DQLSC(J,K,ITR) 

CCCCCCCCCCCCCCCCC DEBUGGING CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC

C           if (j.eq.1063) then
C        write(*,*) 'DBx:',k,itr,precls(JDBG,ITR),EVAPPREC(JDBG,ITR), 
C     &                DQLSC(JDBG,k,ITR)
C           endif

C           if (precls(J,ITR) .lt. 0.) then
C             write(*,*) 'PEVAP: end loop PRC<0:',j,k,itr,precls(j,itr),
C     &                        DQLSC(j,k,itr),pfact
C             stop'Bugger'
C           endif

            enddo
          endif
          

C          do itr = 1, ntr
C           if (j.eq.1063) then
C        write(*,*) 'DBY:',k,itr,precls(1063,ITR),EVAPPREC(1063,ITR), 
C     &                DQLSC(1063,k,ITR)
C           endif
C          enddo
          
 
CCCCCCCCCCCCCCCCC DEBUGGING CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC

         ENDDO		! J loop
      ENDDO		! K loop
      
      RETURN
      END       

