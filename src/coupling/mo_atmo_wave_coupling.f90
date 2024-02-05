! Interface between atmosphere physics and the ocean surface waves, through a coupler
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

MODULE mo_atmo_wave_coupling

  USE mo_kind,           ONLY: wp
  USE mo_model_domain,   ONLY: t_patch
  USE mo_fortran_tools,  ONLY: assert_acc_host_only
  USE mo_coupling_utils, ONLY: cpl_def_field, cpl_put_field, cpl_get_field
  USE mo_sync,           ONLY: sync_c, sync_patch_array

  IMPLICIT NONE

  PRIVATE

  PUBLIC :: construct_atmo_wave_coupling, couple_atmo_to_wave

  CHARACTER(LEN=*), PARAMETER :: modname = 'mo_atmo_wave_coupling'

  INTEGER :: field_id_u10m
  INTEGER :: field_id_v10m
  INTEGER :: field_id_fr_seaice
  INTEGER :: field_id_z0

CONTAINS

  !>
  !! Registers fields required for the coupling between atmosphere and wave
  !!
  !! This subroutine is called from constrcut_atmo_coupling.
  !!
  SUBROUTINE construct_atmo_wave_coupling( &
    comp_id, cell_point_id, timestepstring)

    INTEGER, INTENT(IN) :: comp_id
    INTEGER, INTENT(IN) :: cell_point_id
    CHARACTER(LEN=*), INTENT(IN) :: timestepstring

    CALL cpl_def_field( &
      comp_id, cell_point_id, timestepstring, &
      "zonal_wind_in_10m", 1, field_id_u10m)
    CALL cpl_def_field( &
      comp_id, cell_point_id, timestepstring, &
      "meridional_wind_in_10m", 1, field_id_v10m)
    CALL cpl_def_field( &
      comp_id, cell_point_id, timestepstring, &
      "fraction_of_ocean_covered_by_sea_ice", 1, field_id_fr_seaice)
    CALL cpl_def_field( &
      comp_id, cell_point_id, timestepstring, &
      "roughness_length", 1, field_id_z0)

  END SUBROUTINE construct_atmo_wave_coupling

  !>
  !! Exchange fields between atmosphere and wave model
  !!
  !! Send fields to the wave model:
  !!   "meridional_wind_in_10m"
  !!   "zonal_wind_in_10m"
  !!   "fraction_of_ocean_covered_by_sea_ice"
  !!
  !! Receive fields from the wave model:
  !!   "roughness_length"
  !!
  !! This subroutine is called from nwp_nh_interface.
  !!
  SUBROUTINE couple_atmo_to_wave(p_patch, u10m, v10m, fr_seaice, z0_waves, lacc)

    CHARACTER(len=*), PARAMETER ::  &
      &  routine = modname//':couple_atmo_to_wave'

    TYPE(t_patch),                INTENT(IN)   :: p_patch
    REAL(wp), CONTIGUOUS, TARGET, INTENT(IN)   :: u10m(:,:)      !< zonal wind speed in 10m [m/s]
    REAL(wp), CONTIGUOUS, TARGET, INTENT(IN)   :: v10m(:,:)      !< meridional wind speed in 10m [m/s]
    REAL(wp), CONTIGUOUS, TARGET, INTENT(IN)   :: fr_seaice(:,:) !< fraction_of_ocean_covered_by_sea_ice [1]
    REAL(wp), CONTIGUOUS, TARGET, INTENT(INOUT):: z0_waves(:,:)  !< surface roughness length [m]
    LOGICAL,  OPTIONAL,           INTENT(IN)   :: lacc           ! If true, use openacc

    LOGICAL :: write_coupler_restart, received_data

    CALL assert_acc_host_only('couple_atmo_to_wave', lacc)

    !  *****  *****  *****  *****  *****  *****  *****  *****  *****  *****  *****  *****
    !  Send fields from atmosphere to wave
    !  *****  *****  *****  *****  *****  *****  *****  *****  *****  *****  *****  *****
    !
    !------------------------------------------------
    !  Send 10m zonal wind u10m
    !  'zonal_wind_in_10m'
    !------------------------------------------------
    !
    CALL cpl_put_field( &
      routine, field_id_u10m, 'U10', p_patch%n_patch_cells, u10m)

    ! ----------------------------------------------
    !  Send 10m meridional wind v10m
    !  'meridional_wind_in_10m'
    ! ----------------------------------------------
    !
    CALL cpl_put_field( &
      routine, field_id_v10m, 'V10', p_patch%n_patch_cells, v10m)

    ! ------------------------------------------------------------------
    !  Send fraction of sea ice
    !  'fraction_of_ocean_covered_by_sea_ice'
    ! ------------------------------------------------------------------
    !
    CALL cpl_put_field( &
      routine, field_id_fr_seaice, 'fr_seaice', p_patch%n_patch_cells, &
      fr_seaice, write_restart=write_coupler_restart)

    !  *****  *****  *****  *****  *****  *****  *****  *****  *****  *****  *****  *****
    !  Receive fields from wave to atmosphere
    !  *****  *****  *****  *****  *****  *****  *****  *****  *****  *****  *****  *****
    !
    ! --------------------------------------------
    !  Receive roughness length z0 from the wave model
    !  'roughness_length'
    ! --------------------------------------------
    !
    CALL cpl_get_field( &
      routine, field_id_z0, 'z0', p_patch%n_patch_cells, z0_waves, &
      received_data=received_data)

    IF (received_data) &
      CALL sync_patch_array(SYNC_C, p_patch, z0_waves, opt_varname='z0')

  END SUBROUTINE couple_atmo_to_wave

END MODULE mo_atmo_wave_coupling
