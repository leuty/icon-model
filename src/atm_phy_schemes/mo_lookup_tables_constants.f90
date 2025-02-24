! ICON
!
! ---------------------------------------------------------------
! Copyright (C) 2004-2025, DWD, MPI-M, DKRZ, KIT, ETH, MeteoSwiss
! Contact information: icon-model.org
!
! See AUTHORS.TXT for a list of authors
! See LICENSES/ for license information
! SPDX-License-Identifier: BSD-3-Clause
! ---------------------------------------------------------------

! Constants used for the computation of lookup tables of the saturation
! mixing ratio over liquid water (*c_les*) or ice(*c_ies*)

MODULE mo_lookup_tables_constants

  USE, INTRINSIC :: iso_fortran_env, ONLY: wp => real64
  USE mo_physical_constants, ONLY: alv, als, cpd, rd, rv, tmelt


  IMPLICIT NONE

  PRIVATE

  PUBLIC :: c1es, c2es, c3les, c3ies, c4les, c4ies, c5les, c5ies, &
    &       c5alvcp, c5alscp, alvdcp, alsdcp

  PUBLIC :: init_satpres_coeffs

  REAL (wp) :: c1es
  REAL (wp) :: c2es
  REAL (wp) :: c3les
  REAL (wp) :: c3ies
  REAL (wp) :: c4les
  REAL (wp) :: c4ies
  REAL (wp) :: c5les
  REAL (wp) :: c5ies
  REAL (wp) :: c5alvcp
  REAL (wp) :: c5alscp
  REAL (wp) :: alvdcp
  REAL (wp) :: alsdcp

  !$ACC DECLARE CREATE(c1es, c2es, c3les, c3ies, c4les, c4ies, c5les, c5ies, c5alvcp, c5alscp, alvdcp, alsdcp)

  CONTAINS


  SUBROUTINE init_satpres_coeffs(itype_satpres)

    INTEGER, INTENT(IN), OPTIONAL :: itype_satpres

    INTEGER :: itype

    IF (PRESENT(itype_satpres)) THEN
      itype = itype_satpres
    ELSE
      itype = 1
    ENDIF

    ! Set coefficients for saturation pressure (originally set as fortran parameters in the declaration above, but this
    ! needed to be moved in order to switch between the old COSMO model coefficients and the more accurate IFS coefficients)

    IF (itype == 1) THEN ! DWD coefficients (namelist default)
      c3les = 17.269_wp
      c3ies = 21.875_wp
      c4les = 35.86_wp
      c4ies = 7.66_wp
    ELSE IF (itype == 2) THEN ! IFS coefficients
      c3les = 17.502_wp
      c3ies = 22.587_wp
      c4les = 32.19_wp
      c4ies = -0.7_wp
    ENDIF
    c1es  = 610.78_wp
    c2es  = c1es*rd/rv
    c5les = c3les*(tmelt-c4les)
    c5ies = c3ies*(tmelt-c4ies)
    c5alvcp = c5les*alv/cpd
    c5alscp = c5ies*als/cpd
    alvdcp  = alv/cpd
    alsdcp  = als/cpd

    !$ACC UPDATE DEVICE(c1es, c2es, c3les, c3ies, c4les, c4ies, c5les, c5ies, c5alvcp, c5alscp, alvdcp, alsdcp)

  END SUBROUTINE init_satpres_coeffs

END MODULE mo_lookup_tables_constants

