! Calculate humidity tendencies from methane oxidation and photolysis
!
! In GCMs without chemistry coupling, the water vapor concentration in
! the startosphere and mesosphere is unrealistic because the major
! production (oxidation of methane) and loss (photolysis) mechanisms
! are missing.  This submodel parameterizes both effects and should
! lead to a vertical profile of water vapor mixing ratio with a
! secondary maximum near the stratopause.
!
! Reference: ECMWF RD-MEMO R60.1/AJS/31, C. Jacob
!
! ICON
!
! ---------------------------------------------------------------
! Copyright (C) 2004-2024, DWD, MPI-M, DKRZ, KIT, ETH, MeteoSwiss
! Contact information: icon-model.org
!
! See AUTHORS.TXT for a list of authors
! See LICENSES/ for license information
! SPDX-License-Identifier: BSD-3-Clause
! ---------------------------------------------------------------

MODULE mo_methane_oxidation

  USE mo_kind,           ONLY: wp
  USE mo_math_constants, ONLY: pi

  IMPLICIT NONE

  PRIVATE

  PUBLIC :: methox

  REAL(kind=wp), PARAMETER :: rqlim   = 4.25e-6_wp
  REAL(kind=wp), PARAMETER :: rpbotox = 10000._wp
  REAL(kind=wp), PARAMETER :: rpbotph = 20._wp
  REAL(kind=wp), PARAMETER :: rptopox = 50._wp
  REAL(kind=wp), PARAMETER :: rptopph = 0.1_wp

  REAL(kind=wp), PARAMETER :: ralpha1 = (19._wp*LOG(10._wp))/(LOG(20._wp)**4)
  REAL(kind=wp), PARAMETER :: ralpha2 = LOG(1.0_wp/3._wp+0.01_wp)
  REAL(kind=wp), PARAMETER :: ralpha3 = 0.5_wp*(LOG(100._wp)+ralpha2)
  REAL(kind=wp), PARAMETER :: rlogpph = LOG(rptopph/rpbotph)

CONTAINS

  SUBROUTINE methox(jcs, jce, kproma, klev_top, klev_bottom, klev, pap, pq, ptenq)

    INTEGER,       INTENT(in)  :: kproma, klev            !< actual nproma and number of levels
    INTEGER,       INTENT(in)  :: jcs, jce                !< cell start, end in block used
    INTEGER,       INTENT(in)  :: klev_top, klev_bottom   !< vertical levels to process
    REAL(kind=wp), INTENT(in)  :: pap(kproma,klev)        !< pressure [Pa]
    REAL(kind=wp), INTENT(in)  :: pq(kproma,klev)         !< specific humidity [kg/kg]
    REAL(kind=wp), INTENT(out) :: ptenq(kproma,klev)      !< tendency of spucific humidity due to methox [kg/(kg*s)]

    LOGICAL :: lloxid, llphoto

    INTEGER :: jk, jl

    REAL(kind=wp) :: zarg, zpratio, ztau1, ztau2, ztdays

    !$ACC DATA PRESENT( pap, pq, ptenq )

    !$ACC PARALLEL DEFAULT(PRESENT)
    !$ACC LOOP SEQ
    DO jk = klev_top, klev_bottom
      !$ACC LOOP GANG VECTOR PRIVATE( LLOXID, LLPHOTO, ZTDAYS, ZPRATIO, ZTAU1, ZARG, ZTAU2 )
      DO jl = jcs, jce
        ptenq(jl,jk) = 0._wp
        lloxid = pap(jl,jk) < rpbotox .AND. pq(jl,jk) < rqlim
        llphoto = pap(jl,jk) < rpbotph

        ! methane oxidation

        IF (lloxid) THEN
          IF(pap(jl,jk) <= rptopox) THEN
            ztdays = 100._wp
          ELSE
            zpratio = (LOG(pap(jl,jk)/rptopox))**4._wp/LOG(rpbotox/pap(jl,jk))
            ztdays = 100._wp*(1._wp+ralpha1*zpratio)
          ENDIF
          ztau1 = 86400._wp*ztdays
          ptenq(jl,jk) = ptenq(jl,jk)+(rqlim-pq(jl,jk))/ztau1
        ENDIF

        ! photolysis

        IF (llphoto) THEN
          IF (pap(jl,jk) <= rptopph) THEN
            ztdays = 3._wp
          ELSE
            zarg = ralpha2-ralpha3*(1._wp+COS((pi*LOG(pap(jl,jk)/rpbotph))/rlogpph))
            ztdays = 1.0_wp/(EXP(zarg)-0.01_wp)
          ENDIF
          ztau2 = 86400._wp*ztdays
          ptenq(jl,jk) = ptenq(jl,jk)-pq(jl,jk)/ztau2
        ENDIF

      ENDDO
    ENDDO
    !$ACC END PARALLEL

    !$ACC END DATA

  END SUBROUTINE methox

END MODULE mo_methane_oxidation
