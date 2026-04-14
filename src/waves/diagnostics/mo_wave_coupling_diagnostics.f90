! ICON
!
! ---------------------------------------------------------------
! Copyright (C) 2004-2026, DWD, MPI-M, DKRZ, KIT, ETH, MeteoSwiss
! Contact information: icon-model.org
!
! See AUTHORS.TXT for a list of authors
! See LICENSES/ for license information
! SPDX-License-Identifier: BSD-3-Clause
! ---------------------------------------------------------------

! Computes diagnostic variables for coupling and output, if requested.
! Fields have no impact on the wave solution, but may impact coupled components.
! In case of coupling, diagnostics are updated every time step.
! In standalone runs, diagnostics are updated at output time steps.

!----------------------------
#include "omp_definitions.inc"
!----------------------------

MODULE mo_wave_coupling_diagnostics
  USE mo_kind,                ONLY: wp
  USE mo_model_domain,        ONLY: t_patch
  USE mo_wave_config,         ONLY: t_wave_config
  USE mo_wave_types,          ONLY: t_wave_diag_dyn, t_wave_diag_cpl, t_wesd
  USE mo_impl_constants,      ONLY: min_rlcell
  USE mo_loopindices,         ONLY: get_indices_c
  USE mo_physical_constants,  ONLY: grav
  USE mo_math_constants,      ONLY: pi2, rad2deg
  USE mo_parallel_config,     ONLY: nproma
  USE mo_fortran_tools,       ONLY: init
  USE mo_wave_constants,      ONLY: EMIN
  USE mo_wave_stokes,         ONLY: stokes_profile_spectrum, stokes_profile_breivik, &
    &                               stokes_drift
  USE mo_wave_common_diagnostics, ONLY: significant_wave_height

  IMPLICIT NONE

  PRIVATE

  CHARACTER(LEN=*), PARAMETER :: modname = 'mo_wave_coupling_diagnostics'

  PUBLIC :: calculate_coupling_diagnostics

CONTAINS
  !>
  !! Calculation of purely diagnostic parameters
  !!
  SUBROUTINE calculate_coupling_diagnostics(p_patch, wave_config, depth, wesd, diag_dyn, diag_cpl)

    TYPE(t_patch),         INTENT(IN)    :: p_patch
    TYPE(t_wave_config),   INTENT(IN)    :: wave_config
    REAL(wp),              INTENT(IN)    :: depth(:,:)    ! water depth
    TYPE(t_wesd),          INTENT(IN)    :: wesd(:)       ! energy spectral bins
    TYPE(t_wave_diag_dyn), INTENT(IN)    :: diag_dyn
    TYPE(t_wave_diag_cpl), INTENT(INOUT) :: diag_cpl

    CHARACTER(len=*), PARAMETER ::  &
      &  routine = modname//':calculate_coupling_diagnostics'


    IF (ASSOCIATED(diag_cpl%hs)) THEN
      ! calculate significant wave height from total wave energy
      !
      CALL significant_wave_height(p_patch = p_patch, &
        &                          emean   = diag_dyn%emean(:,:), &
        &                          hs      = diag_cpl%hs(:,:)) ! OUT
    ENDIF


    ! calculate stokes drift velocities
    !
    ! surface values
    ! Note that the Breivik-type 3D stokes profile below requires
    ! Stokes surface values. Hence, we compute u_stokes and v_stokes
    ! unconditionally, for simplicity.
    !
    CALL stokes_drift(p_patch = p_patch,             &
      &           wave_config = wave_config,         &
      &            wave_num_c = diag_dyn%wave_num_c, &
      &                 depth = depth,               &
      &                  wesd = wesd,                &
      &              u_stokes = diag_cpl%u_stokes,   & ! OUT
      &              v_stokes = diag_cpl%v_stokes)     ! OUT

    ! vertical profile
    IF (ASSOCIATED(diag_cpl%last_idx_depth) .AND. &
      & ASSOCIATED(diag_cpl%u3d_stokes)     .AND. &
      & ASSOCIATED(diag_cpl%v3d_stokes)) THEN

      IF (wave_config%stokes_method == 1) THEN

        CALL stokes_profile_spectrum(p_patch = p_patch,      &
          &           wave_config = wave_config,             &
          &            wave_num_c = diag_dyn%wave_num_c,     &
          &                 depth = depth,                   &
          &        last_idx_depth = diag_cpl%last_idx_depth, &
          &                  wesd = wesd,                    &
          &            u3d_stokes = diag_cpl%u3d_stokes,     & ! OUT
          &            v3d_stokes = diag_cpl%v3d_stokes)       ! OUT

      ELSE

        CALL stokes_profile_breivik(p_patch = p_patch,       & ! IN
          &           wave_config = wave_config,             & ! IN
          &            wave_num_c = diag_dyn%wave_num_c,     & ! IN
          &                 depth = depth,                   & ! IN
          &        last_idx_depth = diag_cpl%last_idx_depth, & ! IN
          &                  wesd = wesd,                    & ! IN
          &              u_stokes = diag_cpl%u_stokes,       & ! IN
          &              v_stokes = diag_cpl%v_stokes,       & ! IN
          &            u3d_stokes = diag_cpl%u3d_stokes,     & ! OUT
          &            v3d_stokes = diag_cpl%v3d_stokes)       ! OUT
      END IF
    END IF


  END SUBROUTINE calculate_coupling_diagnostics

END MODULE mo_wave_coupling_diagnostics
