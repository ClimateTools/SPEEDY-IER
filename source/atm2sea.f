      SUBROUTINE ATM2SEA(OICE1,HFLXS1,
     &                   HFINTS,USTRSM,VSTRSM,U0SM,V0SM,
     &                   SHFSM,XLHFSM,SSRSM,SLRDSM,SLRUSM,
     &                   ALBSM,PRECSM,SNOWRSM,SST01,SST01L)
C-- 
C--   SUBROUTINE ATM2SEA(OICE1,HFLXS1,
C--  &                   HFINTS,USTRSM,VSTRSM,U0SM,V0SM,
C--  &                   SHFSM,XLHFSM,SSRSM,SLRDSM,SLRUSM,
C--  &                   ALBSM,PRECSM,SNOWRSM) 
C--   
C--   Purpose :	Update sea-surface tenperature anomalies
C--   Input   : OICE1 = Daily value of ice concentration
C--           : HFLXS1= Daily value of climat. sea heat flux
C--           : HFINTS= Net heatflux over sea
C--           : USTRSM= Ustress over sea 
C--           : VSTRSM= Vstress over sea 
C--           : U0SM  = Sfc U wind over sea 
C--           : V0SM  = Sfc v wind over sea
C--           : SHFSM = Sensible heatflux over sea 
C--           : XLHFSM= Latent heat flux uver sea
C--           : SSRSM = Sfc solar radiation sea
C--           : SLRDSM= Sfc downward longw. radiat. sea
C--           : SLRUSM= Sfc upward longw. radiat. sea
C--           : ALBSM = Albedo over sea
C--           : PRECSM= Precip over sea
C--           : SNOWRSM= Snowfall rate over sea
C--           : SST01= daily SST
C--           : SST01L= daily SST from previous day
C--   Modified common blocks: ssfcanom
C--                           
C--  

      include "atparam.h"

      PARAMETER ( NLON=IX, NLAT=IL )

      include "com_ts_sea.h"
      include "com_sea.h"

      real oice1(ix,il), hflxs1(ix,il)
      real  hfints(ix,il), ustrsm(ix,il), vstrsm (ix,il), 
     &      u0sm(ix,il), v0sm(ix,il), shfsm(ix,il),  
     &      xlhfsm(ix,il), ssrsm(ix,il), slrdsm(ix,il), 
     &      slrusm(ix,il), albsm(ix,il), precsm(ix,il),
     &      snowrsm(ix,il), sst01(ix,il),sst01l(ix,il)
cfk---modification for coupling start
      real  hfl(ix,il), saltfl(ix,il), 
     &      taux(ix,il), tauy(ix,il)
cfk---modification for coupling start
      real hfanom(nlon,nlat)


C--   1. Compute sfc temp. anomalies from flux anomalies

      rnstep = 1./nsteps


C--   1.1 Sea-ice

      do j=1,nlat
        do i=1,nlon
C          hfanom(i,j)=hfints(i,j)*rnstep-hflxs1(i,j)
          hfanom(i,j)=hfints(i,j)*rnstep
        enddo
      enddo

      if (iaice.gt.0) then

        do j=1,nlat
          do i=1,nlon
            if (oice1(i,j).gt.0.) then
              stanomi1(i,j)=stdisi*
     &                      (stanomi1(i,j)+hfanom(i,j)*rhcapi)
     &                      + (sst01l(i,j)-sst01(i,j))
              hfanom(i,j)=hfanom(i,j)-hflxs1(i,j)
              hfice=flxice*stanomi1(i,j)-hfanom(i,j)
              hfanom(i,j)=hfanom(i,j)+oice1(i,j)*hfice
            else
              hfanom(i,j)=hfanom(i,j)-hflxs1(i,j)
            endif
          enddo
        enddo

      else

        do j=1,nlat
          do i=1,nlon
C            hfanom(i,j)=hfanom(i,j)*(1.-oice1(i,j))
            hfanom(i,j)=(hfints(i,j)*rnstep-hflxs1(i,j))*
     &                  (1.-oice1(i,j))
          enddo
        enddo

      endif


C--   1.2 Ocean mixed layer

      if (iasst.gt.1) then

        do j=1,nlat
          do i=1,nlon
            if (rhcap2s(i,j).gt.0.) then
              stanoms1(i,j)=stdiss*
     &                      (stanoms1(i,j)+hfanom(i,j)*rhcap2s(i,j))
            endif
          enddo
        enddo

      endif

cfk--- modification for coupling start
      IF(IASST .EQ. 4 .OR. IASST .EQ. 5 .OR. 
     &   IASST .EQ. 6 .OR. IASST .EQ. 7) THEN
        ALHC = 2501.0
        FAK=1./86400.
        DO J=1,NLAT
          DO I=1,NLON
            TAUX(I,J)=-10.*USTRSM(I,J)
            TAUY(I,J)=-10.*VSTRSM(I,J)
            HFL(I,J)=SLRDSM(I,J)+SSRSM(I,J)-
     &              (SHFSM(I,J)+XLHFSM(I,J)+SLRUSM(I,J))
            SALTFL(I,J)=-(PRECSM(I,J)*FAK*100.0
     &                    -XLHFSM(I,J)/ALHC/1000./10.)*0.035
          ENDDO
        ENDDO 
         CALL WRITERA(TAUX,TAUY,HFL,SALTFL,SSRSM)
       ENDIF
cfk--- modification for coupling end

C--   2. Set flux integral to zero for next step 

        do j=1,nlat
          do i=1,nlon
            hfints(i,j)=0.
          enddo
        enddo

      return
      end


