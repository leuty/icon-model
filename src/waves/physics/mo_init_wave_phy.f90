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

! Contains routines for the analytic initialisation of the physical model state,
! routines for computing the 1D JONSWAP spectrum, as well as other auxiliary
! variables related to nonlinear wave interaction.

!----------------------------
#include "omp_definitions.inc"
!----------------------------

MODULE mo_init_wave_physics

  USE mo_kind,                 ONLY: wp
  USE mo_mpi,                  ONLY: my_process_is_stdio
  USE mo_exception,            ONLY: message, message_text, finish
  USE mo_model_domain,         ONLY: t_patch
  USE mo_impl_constants,       ONLY: MAX_CHAR_LENGTH, min_rlcell, SUCCESS, VNAME_LEN, min_rlcell_int
  USE mo_physical_constants,   ONLY: grav
  USE mo_math_constants,       ONLY: pi2, rpi_2, rad2deg
  USE mo_loopindices,          ONLY: get_indices_c
  USE mo_parallel_config,      ONLY: nproma

  USE mo_wave_types,           ONLY: t_wave_diag, t_wave_state
  USE mo_wave_config,          ONLY: t_wave_config, generate_filename
  USE mo_wave_constants,       ONLY: EMIN
  !
  USE mo_parallel_config,      ONLY: nproma
  USE mo_io_units,             ONLY: filename_max
  USE mo_read_interface,       ONLY: openInputFile, closeFile, t_stream_id, on_cells, on_edges, read_3D_1time, read_2D_1time, read_2D !read_2D_int_1time
  USE mo_io_config,            ONLY: default_read_method
  USE mo_sync,                 ONLY: SYNC_C, sync_patch_array_mult
  USE mo_grid_config,          ONLY: n_dom, nroot
  USE mo_dynamics_config,      ONLY: nnow
  USE mo_initwave_config,      ONLY: initwave_config
  USE mo_time_config,          ONLY: time_config
  USE mo_master_config,        ONLY: getModelBaseDir
  USE mtime,                   ONLY: datetime

  IMPLICIT NONE

  PRIVATE

  PUBLIC :: init_wave_spectrum_analytic
  PUBLIC :: init_wave_nonlinear
  PUBLIC :: min_energy
  PUBLIC :: init_spectrum_from_file

  CHARACTER(LEN=*), PARAMETER :: modname = 'mo_init_wave_phy'

CONTAINS

  !>
  !! Initialisation of the wave spectrum by the analytic 1D JONSWAP spectrum
  !!
  !! Calculation of wind dependent initial spectrum from
  !! the fetch law and from the 1D JONSWAP spectrum. The minimum
  !! of wave energy is limited to FLMIN.
  !!
  SUBROUTINE init_wave_spectrum_analytic(p_patch, wave_config, sp10m, dir10m, tracer)
    CHARACTER(len=MAX_CHAR_LENGTH), PARAMETER ::  &
         &  routine = modname//':init_wave_spectrum_analytic'

    TYPE(t_patch),               INTENT(IN)    :: p_patch
    TYPE(t_wave_config), TARGET, INTENT(IN)    :: wave_config
    REAL(wp),                    INTENT(IN)    :: sp10m(:,:)      !< 10m wind speed (m/s)
    REAL(wp),                    INTENT(IN)    :: dir10m(:,:)     !< wind direction (rad)
    REAL(wp),                    INTENT(INOUT) :: tracer(:,:,:,:) !< wave energy spectrum (m**2 s)

    INTEGER :: i_rlstart, i_rlend, i_startblk, i_endblk
    INTEGER :: i_startidx, i_endidx
    INTEGER :: jc,jb,jd,jf
    REAL(wp):: alphaj(nproma)                 ! Phillips constant (scaling parameter)
    REAL(wp):: fp(nproma)                     ! JONSWAP peak frequency (where spectrum has maximum energy)
    REAL(wp):: et(nproma, wave_config%nfreqs) ! JONSWAP spectrum
    REAL(wp):: st

    TYPE(t_wave_config), POINTER :: wc => NULL()

    ! save some paperwork
    wc => wave_config

    ! halo points must be included
    i_rlstart  = 1
    i_rlend    = min_rlcell
    i_startblk = p_patch%cells%start_block(i_rlstart)
    i_endblk   = p_patch%cells%end_block(i_rlend)

!$OMP PARALLEL
!$OMP DO PRIVATE(jb,jf,jd,jc,i_startidx,i_endidx,st,fp,alphaj,et)
    DO jb = i_startblk, i_endblk
      CALL get_indices_c( p_patch, jb, i_startblk, i_endblk,           &
        &                 i_startidx, i_endidx, i_rlstart, i_rlend)

      ! Calculate the peak frequency fp from a fetch law
      ! and set the Phillips constant alphaj
      CALL fetch_law_nonblk(              &
        &     i_startidx  = i_startidx,   & !in
        &     i_endidx    = i_endidx,     & !in
        &     fetch       = wc%fetch,     & !in
        &     fpmax       = wc%fm,        & !in
        &     sp10m       = sp10m(:,jb),  & !in
        &     fp          = fp(:),        & !out
        &     alphaj      = alphaj(:))      !out


      ! Set the 1D JONSWAP spectrum
      !
      CALL jonswap_nonblk(               &
        &   i_startidx = i_startidx,     & !in
        &   i_endidx   = i_endidx,       & !in
        &   freqs      = wc%freqs(:),    & !in
        &   gamma      = wc%GAMMA_wave,  & !in
        &   sa         = wc%SIGMA_A,     & !in
        &   sb         = wc%SIGMA_B,     & !in
        &   flmin      = wc%flmin,       & !in
        &   alphaj     = alphaj(:),      & !in
        &   fp         = fp(:),          & !in
        &   et         = et(:,:)         ) !out


      DO jf = 1,wc%nfreqs
        DO jd = 1,wc%ndirs
          DO jc = i_startidx, i_endidx
            st = rpi_2*MAX(0._wp, COS(wc%dirs(jd)-dir10m(jc,jb)) )**2
            IF (st < 0.1E-08_wp) st = 0._wp

            ! Wave model initialisation
            tracer(jc,jd,jb,jf) = et(jc,jf) * st
            tracer(jc,jd,jb,jf) = MAX(tracer(jc,jd,jb,jf),EMIN)
          END DO  !jc
        END DO  !jd
      END DO  !jf
    END DO  !jb
!$OMP END DO NOWAIT
!$OMP END PARALLEL

    CALL message(routine,'finished')

  END SUBROUTINE init_wave_spectrum_analytic


  !>
  ! -----------------------------------------------------------------------
  ! SUBROUTINE: init_spectrum_from_file
  ! PURPOSE:
  !   This subroutine initializes the wave spectrum by reading data from
  !   an external file specified in the wave configuration. It allocates
  !   necessary 3D and 2D arrays to store initial conditions for various
  !   wave parameters, including tracers and swell mask.
  !   The data is read for each tracer and assigned to the wave state
  !   structure (p_wave_state) for use in the simulation.
  ! -----------------------------------------------------------------------
  SUBROUTINE init_spectrum_from_file(p_patch,  wave_config, p_wave_state)
    TYPE(t_patch),       INTENT(IN   ) :: p_patch
    TYPE(t_wave_config), INTENT(IN   ) :: wave_config
    TYPE(t_wave_state),  INTENT(INOUT) :: p_wave_state

    TYPE(t_stream_id) :: stream_id

    CHARACTER(len=MAX_CHAR_LENGTH), PARAMETER ::  &
         &  routine = modname//':init_spectrum_from_file'

    REAL(wp), ALLOCATABLE :: data_3D_swmask(:,:,:)     ! Array for reading initial 3D fields
    REAL(wp), ALLOCATABLE :: data_3D_llws(:,:,:)       ! Array for reading initial 3D fields

    CHARACTER(LEN=filename_max) :: filename
    CHARACTER(LEN=VNAME_LEN) :: freq_ind_str
    CHARACTER(LEN=VNAME_LEN) :: tracer_name, llws_name , swmask_name
    INTEGER :: jg, ist , jf
    INTEGER :: nfreqs, ndirs ,  nblks_c


    ! 1. Setup parameters
    nblks_c = p_patch%nblks_c
    ndirs = wave_config%ndirs
    nfreqs = wave_config%nfreqs
    jg = p_patch%id

    ! 2. Allocate arrays for reading data
    !llws_tracer
    ALLOCATE(data_3D_llws(nproma, ndirs, p_patch%nblks_c), stat=ist)
    IF (ist/=SUCCESS) CALL finish(routine, 'allocation of data_3D_llws failed')
    !swmask_tracer
    ALLOCATE(data_3D_swmask(nproma, ndirs, p_patch%nblks_c), stat=ist)
    IF (ist/=SUCCESS) CALL finish(routine, 'allocation of data_3D_swmask failed')


    ! 3. Build filename dynamically using generator
    filename = TRIM(generate_filename( &
      & initwave_config(jg)%initial_wave_spectrum_filename, &
      & getModelBaseDir(), nroot, 1, jg, time_config%tc_exp_startdate))

    ! Log which file we are reading
    CALL message(routine, 'Reading initial wave spectrum from file: '//TRIM(filename))

    ! Open file and read data
    CALL openInputFile(stream_id, TRIM(filename), p_patch, default_read_method)


    DO jf = 1,wave_config%nfreqs ! frequencies
      write(freq_ind_str,'(I3.3)') jf

      !tracer
      tracer_name = 'tracer_'//TRIM(freq_ind_str)
      !PRINT *, tracer_name
      CALL read_3D_1time(stream_id, on_cells, tracer_name, p_wave_state%prog(nnow(jg))%tracer(:,:,:,jf))

      !llws
      llws_name = 'llws_'//TRIM(freq_ind_str)
      !PRINT *, llws_name
      CALL read_3D_1time(stream_id, on_cells, llws_name, data_3D_llws)
      p_wave_state%source%llws(:,:,jf,:) = NINT(data_3D_llws(:,:,:))

      !swmask
      swmask_name = 'swmask_'//TRIM(freq_ind_str)
      !PRINT *, swmask_name
      CALL read_3D_1time(stream_id, on_cells, swmask_name, data_3D_swmask)
      p_wave_state%diag%swell_mask(:,:,jf,:) = NINT(data_3D_swmask(:,:,:))

    END DO !frequencies

    CALL closeFile(stream_id)
    !
    CALL sync_patch_array_mult(typ         = SYNC_C,                                    &
      &                        p_patch     = p_patch,                                   &
      &                        nfields     = SIZE(p_wave_state%prog(nnow(jg))%tracer,4),&
      &                        f4din       = p_wave_state%prog(nnow(jg))%tracer,        &
      &                        opt_varname = 'tracer',                                  &
      &                        lacc        = .FALSE.)

    !cleanup
    DEALLOCATE(data_3D_llws, stat=ist)
    IF (ist /= SUCCESS) CALL finish(routine, 'Deallocation of data_3D_llws failed')

    DEALLOCATE(data_3D_swmask, stat=ist)
    IF (ist /= SUCCESS) CALL finish(routine, 'Deallocation of data_3D_swmask failed')

    CALL message(routine, 'finished')
    !
  END SUBROUTINE init_spectrum_from_file


  !>
  !! Calculation of the JONSWAP spectrum according to
  !! Hasselmann et al. 1973. Adaptation of WAM 4.5
  !! subroutine JONSWAP.
  !!
  !! Non-blocked version
  !!
  SUBROUTINE jonswap_nonblk(i_startidx, i_endidx, freqs, gamma, sa, sb, flmin, alphaj, fp, et)
    INTEGER,       INTENT(IN)    :: i_startidx, i_endidx
    REAL(wp),      INTENT(IN)    :: freqs(:)      !! FREQUENCIES.
    REAL(wp),      INTENT(IN)    :: gamma         !! OVERSHOOT FACTOR.
    REAL(wp),      INTENT(IN)    :: sa            !! LEFT PEAK WIDTH.
    REAL(wp),      INTENT(IN)    :: sb            !! RIGHT PEAK WIDTH.
    REAL(wp),      INTENT(IN)    :: flmin
    REAL(wp),      INTENT(IN)    :: alphaj(:)     !! OVERALL ENERGY LEVEL OF JONSWAP SPECTRA.
    REAL(wp),      INTENT(IN)    :: fp(:)         !! PEAK FREQUENCIES.
    REAL(wp),      INTENT(INOUT) :: et(:,:)       !! JONSWAP SPECTRA (is only OUT parameter)

    CHARACTER(len=MAX_CHAR_LENGTH), PARAMETER ::  &
         &  routine = modname//':JONSWAP_nonblk'

    REAL(wp) :: ARG, sigma, G2ZPI4FRH5M

    INTEGER :: jc,jf

    DO jf = 1,SIZE(freqs)

      G2ZPI4FRH5M = grav**2 / pi2**4 * freqs(jf)**(-5)

      DO jc = i_startidx, i_endidx

        sigma = MERGE(sb,sa, freqs(jf)>fp(jc))
        ET(jc,jf) = 0._wp

        ARG = 1.25_wp*(FP(jc)/freqs(jf))**4
        IF (ARG.LT.50.0_wp) THEN
          ET(jc,jf) = ALPHAJ(jc) * G2ZPI4FRH5M * EXP(-ARG)
        END IF

        ARG = 0.5_wp*((freqs(jf)-FP(jc)) / (sigma*FP(jc)))**2
        IF (ARG.LT.99._wp) THEN
          ET(jc,jf) = ET(jc,jf)*exp(log(GAMMA)*EXP(-ARG))
        END IF

        ET(jc,jf) = MAX(ET(jc,jf),flmin)

      END DO  !jc
    END DO  !jf

  END SUBROUTINE jonswap_nonblk


  !>
  !! Calculation of JONSWAP parameters.
  !!
  !! Calculate the peak frequency from a fetch law
  !! and the JONSWAP alpha.
  !!
  !! Developted by S. Hasselmann (July 1990) and H. Guenther (December 1990).
  !! K.HASSELMAN,D.B.ROOS,P.MUELLER AND W.SWELL. A parametric wave prediction
  !! model. Journal of physical oceanography, Vol. 6, No. 2, March 1976.
  !!
  !! Adopted from WAM 4.5.
  !!
  !! non-blocked version
  !!
  SUBROUTINE fetch_law_nonblk(i_startidx, i_endidx, fetch, fpmax, sp10m, fp, alphaj)
    CHARACTER(len=MAX_CHAR_LENGTH), PARAMETER ::  &
         &  routine = modname//':fetch_law_nonblk'
    !
    INTEGER,       INTENT(IN)    :: i_startidx, i_endidx
    REAL(wp),      INTENT(IN)    :: fetch
    REAL(wp),      INTENT(IN)    :: fpmax     ! maximum peak frequency (Hz)
    REAL(wp),      INTENT(IN)    :: sp10m(:)  ! wind speed at 10m (m/s)
    REAL(wp),      INTENT(INOUT) :: fp(:)     ! jonswap peak frequency (1/s) (is only OUT parameter)
    REAL(wp),      INTENT(INOUT) :: alphaj(:) ! jonswap alpha (-) (is only OUT parameter)

    INTEGER :: jc

    REAL(wp), PARAMETER :: A = 2.84_wp,  D = -(3._wp/10._wp) !! PEAK FREQUENCY FETCH LAW CONSTANTS
    REAL(wp), PARAMETER :: B = 0.033_wp, E = 2._wp/3._wp     !! ALPHA-PEAK FREQUENCY LAW CONSTANTS

    REAL(wp) :: ug

    ! ---------------------------------------------------------------------------- !
    !                                                                              !
    !     1. COMPUTE VALUES FROM FETCH LAWS.                                       !
    !        -------------------------------
    DO jc = i_startidx, i_endidx
      IF (sp10m(jc) > 0.1E-08_wp) THEN
        ug = grav / sp10m(jc)
        fp(jc) = MAX(0.13_wp, A*((grav*fetch)/(sp10m(jc)**2))**D)

        fp(jc) = MIN(fp(jc), fpmax/ug)

        alphaj(jc) = MAX(0.0081_wp, B * fp(jc)**E)
        fp(jc) = fp(jc) * ug
      ELSE
        alphaj(jc) = 0.0081_wp
        fp(jc) = fpmax
      END IF
    END DO

  END SUBROUTINE fetch_law_nonblk


  !>
  !! Calculation of index arrays and weights for the computation of
  !! the nonlinear transfer rate for shallow water.
  !!
  !! Computation of parameters used in discrete interaction
  !! parameterization of nonlinear transfer.
  !!
  !! Adoptation of NLWEIGT from WAM 4.5.
  !!
  !! SUSANNE HASSELMANN JUNE 86.
  !! H. GUNTHER   ECMWF/GKSS  DECEMBER 90 - CYCLE_4 MODIFICATIONS.
  !! P. Janssen   ECMWF June 2005                                         !
  !! H. Gunther   HZG   January 2015  cycle_4.5.4
  !!
  !! Reference
  !! S. Hasselmann and K. Hasselmann, JPO, 1985
  !!
  SUBROUTINE init_wave_nonlinear(wave_config, p_diag)

    CHARACTER(len=MAX_CHAR_LENGTH), PARAMETER ::  &
         &  routine = modname//':init_wave_nonlinear'

    TYPE(t_wave_config), TARGET, INTENT(IN)    :: wave_config
    TYPE(t_wave_diag),           INTENT(INOUT) :: p_diag

    TYPE(t_wave_config), POINTER :: wc => NULL()

    INTEGER :: jf,jd
    INTEGER :: error

    INTEGER :: nfreqs, ndirs
    INTEGER :: klp1, ic, kh, klh, k, ks, icl1, icl2, isg, k1, k11, k2, k21
    INTEGER :: m, ikn, i, ie

    REAL(wp) :: alamd, con, delphi1, delphi2
    REAL(wp) :: deltha, cl1, cl2, al11, al12, ch, cl1h, cl2h
    REAL(wp) :: f1p1, frg, flp, flm, fkp, fkm

    REAL(WP), ALLOCATABLE, DIMENSION(:) :: frlon


    wc => wave_config
    nfreqs = wc%nfreqs
    ndirs = wc%ndirs

    ALLOCATE(frlon(2*nfreqs+2), STAT = error)
    IF(error /= SUCCESS) CALL finish(routine, "memory allocation failure")

    ! Parameters for discrete approximation of nonlinear transfer
    alamd   = 0.25_wp   ! lambda
    con     = 3000.0_wp ! weight for discrete approximation of nonlinear transfer
    delphi1 = -11.48_wp
    delphi2 = 33.56_wp

    ! 1. Computation for angular grid
    deltha = wc%delth * rad2deg

    cl1 = delphi1/deltha
    cl2 = delphi2/deltha

    ! 1.1 computation of indices of angular cell.
    klp1 = ndirs+1
    ic = 1

    DO kh = 1,2
       klh = ndirs
       IF (kh.eq.2) klh=klp1
       DO k = 1,klh
          ks = k
          IF (kh.gt.1) ks=klp1-k+1
          IF (ks.gt.ndirs) CYCLE
          ch = ic*cl1
          p_diag%ja1(ks,kh) = jafu(ch,k,ndirs)
          ch = ic*cl2
          p_diag%ja2(ks,kh) = jafu(ch,k,ndirs)
       END DO
       ic = -1
    END DO

    ! 1.2 computation of angular weights
    icl1 = cl1
    cl1  = cl1 - icl1
    icl2 = cl2
    cl2  = cl2 - icl2
    wc%acl1 = ABS(cl1)
    wc%acl2 = ABS(cl2)
    wc%cl11 = 1._wp - wc%acl1
    wc%cl21 = 1._wp - wc%acl2
    al11 = (1._wp + alamd)**4
    al12 = (1._wp - alamd)**4
    wc%dal1 = 1._wp / al11
    wc%dal2 = 1._wp / al12

    ! 1.3 computation of angular indices
    isg = 1
    DO kh = 1,2
       cl1h = isg*cl1
       cl2h = isg*cl2
       DO k = 1,ndirs
          ks = k
          IF (kh.eq.2) ks = ndirs-k+2
          IF(k.eq.1) ks = 1
          k1 = p_diag%ja1(k,kh)
          p_diag%k1w(ks,kh) = k1
          IF (cl1h.lt.0.) THEN
             k11 = k1-1
             IF (k11.lt.1) k11 = ndirs
          ELSE
             k11 = k1+1
             IF (k11.gt.ndirs) k11 = 1
          END IF
          p_diag%k11w(ks,kh) = k11
          k2 = p_diag%ja2(k,kh)
          p_diag%k2w(ks,kh) = k2
          IF (cl2h.lt.0) THEN
             k21 = k2-1
             IF(k21.lt.1) k21 = ndirs
          ELSE
             k21 = k2+1
             IF (k21.gt.ndirs) k21 = 1
          END IF
          p_diag%k21w(ks,kh) = k21
       END DO
       isg = -1
    END DO

    ! 2. computation for frequency grid
    frlon(1:nfreqs) = wc%freqs(1:nfreqs)

    DO m = nfreqs+1,2*nfreqs+2
       frlon(m) = wc%co*frlon(m-1)
    END DO

    f1p1 = LOG10(wc%co)
    DO m = 1,nfreqs+4
       frg = frlon(m)
       p_diag%af11(m) = con * frg**11
       flp = frg*(1.+alamd)
       flm = frg*(1.-alamd)
       ikn = INT(LOG10(1._wp+alamd)/f1p1+.000001_wp)
       ikn = m+ikn
       p_diag%ikp(m) = ikn
       fkp = frlon(p_diag%ikp(m))
       p_diag%ikp1(m) = p_diag%ikp(m)+1
       p_diag%fklap(m) = (flp-fkp)/(frlon(p_diag%ikp1(m))-fkp)

       p_diag%fklap1(m) = 1._wp-p_diag%fklap(m)
       IF (frlon(1).ge.flm) THEN
          p_diag%ikm(m) = 1
          p_diag%ikm1(m) = 1
          p_diag%fklam(m) = 0._wp
          p_diag%fklam1(m) = 0._wp
       ELSE
          ikn = INT(LOG10(1._wp-alamd)/f1p1+.0000001_wp)
          ikn = m+ikn-1
          IF (ikn.lt.1) ikn = 1
          p_diag%ikm(m) = ikn
          fkm = frlon(p_diag%ikm(m))
          p_diag%ikm1(m) = p_diag%ikm(m)+1
          p_diag%fklam(m) = (flm-fkm)/(frlon(p_diag%ikm1(m))-fkm)

          p_diag%fklam1(m) = 1._wp-p_diag%fklam(m)
       END IF
    END DO


    ! 3. compute tail frequency ratios
    wc%frh(:) = 0._wp ! initialisation

    ie = MIN(30,nfreqs+3)
    DO i = 1,ie
       m = nfreqs+i-1
       wc%frh(i) = (frlon(nfreqs)/frlon(m))**5
    END DO

    IF (ALLOCATED(frlon))          DEALLOCATE(frlon)

    !print nonlinear status
    IF (my_process_is_stdio()) THEN
       WRITE(0,'(/,'' -------------------------------------------------'')')
       WRITE(0,*)'        non linear interaction parameters'
       WRITE(0,'(  '' -------------------------------------------------'')')
       WRITE(0,'(/,''  frequency arrays'')')
       WRITE(0,'(''     acl1       acl2       cl11       cl21   '',                &
            &            ''    dal1       dal2'')')
       WRITE(0,'(1x,6f11.8)') wc%acl1, wc%acl2, wc%cl11, wc%cl21, wc%dal1, wc%dal2
       WRITE(0,*) ' '
       WRITE(0,'(''  m   ikp ikp1  ikm ikm1   fklap       fklap1 '',               &
            &            ''   fklam       fklam1     af11'')')

       DO jf = 1,size(p_diag%ikp)
          WRITE(0,'(1x,i2,4i5,4f11.8,e11.3)') jf, p_diag%ikp(jf), p_diag%ikp1(jf), p_diag%ikm(jf), p_diag%ikm1(jf), &
               &            p_diag%fklap(jf), p_diag%fklap1(jf), p_diag%fklam(jf), p_diag%fklam1(jf), p_diag%af11(jf)
       END DO

       WRITE(0,'(/,''  angular arrays'')')
       WRITE(0,'(''   |--------kh = 1----------||--------kh = 2----------|'')')
       WRITE(0,'(''  k   k1w   k2w  k11w  k21w   k1w   k2w  k11w  k21w'')')
       DO jd = 1,size(p_diag%k1w,1)
          WRITE(0,'(1x,i2,8i6)') jd,(p_diag%k1w(jd,kh), p_diag%k2w(jd,kh), p_diag%k11w(jd,kh),              &
               &                            p_diag%k21w(jd,kh),kh=1,2)
       END DO

       WRITE(0,'(/,''  tail array frh'')')
       WRITE(0,'(1x,8f10.7)') wc%frh(1:30)
    END IF


    CALL message(routine,'finished')

  END SUBROUTINE init_wave_nonlinear


  !>
  !! Function to compute the index array for the angles of the
  !! interacting wavenumbers.
  !!
  !! Adopted from WAM 4.5 JAFU
  !!
  !!  S. Hasselmann        MPIFM        01/12/1985
  !!
  !! Indices defining bins in frequency and direction plane into
  !! which nonlinear energy transfer increments are stored. Needed
  !! for computation of the nonlinear energy transfer.
  !!
  !! Reference
  !! S. Hasselmann and K. Hasselmann, JPO, 1985 B
  INTEGER FUNCTION JAFU (CL, J, IAN)

    REAL(wp),    INTENT(IN) :: CL !! weights.
    INTEGER, INTENT(IN) :: J      !! index in angular array.
    INTEGER, INTENT(IN) :: IAN    !! number of angles in array.

    JAFU = J + INT(CL)
    IF (JAFU.LE.0)   JAFU = JAFU+IAN
    IF (JAFU.GT.IAN) JAFU = JAFU-IAN

  END FUNCTION JAFU


  !>
  !! Computation of minimum energy in spectral bins.
  !!
  !! Adopted from WAM 4.5 MIN_ENERGY
  !!
  !! J. Bidlot    ECMWF
  !!
  !! Computate of a table for minimum energy in spectral bins.
  !!
  !! Method:
  !!
  !! For each windspeed u10 as listed in the stress table the JONSWAP
  !! spectrum is computed from fetch laws and 1% of its value is stored for
  !! each frequency bin. Too small values are replaced by a given minimum.
  !!
  SUBROUTINE min_energy(wave_config, flminfr_tab)
    CHARACTER(len=MAX_CHAR_LENGTH), PARAMETER ::  &
         &  routine = modname//':min_energy'

    TYPE(t_wave_config), INTENT(IN)    :: wave_config
    REAL(wp),            INTENT(INOUT) :: flminfr_tab(:,:) ! minimum energy for a given frequency and wind spped bin (jmax,nfreqs)

    INTEGER  :: j, nfreqs, jmax

    REAL(wp) :: flmin       !! absolute minimum energy in spectral bins
    REAL(wp) :: delu        !! wind increment

    REAL(wp) :: u10(SIZE(flminfr_tab,1))
    REAL(wp) :: fpk(SIZE(flminfr_tab,1))      ! JONSWAP peak frequency
    REAL(wp) :: alphaj0(SIZE(flminfr_tab,1))  ! JONSWAP alpha

    nfreqs = wave_config%nfreqs
    jmax = wave_config%jmax
    flmin = wave_config%flmin
    delu = wave_config%delu

    ! sanity check
    IF (SIZE(flminfr_tab,1) /= jmax) THEN
      CALL finish(routine, "Size of field flminfr_tab must be equal to jmax.")
    ENDIF

    ! compute windspeeds from table parameters
    DO j = 1,jmax
      u10(j) = REAL(j,wp)*delu
    END DO

    ! peak frequencies and alpha parameter from fetch law
    CALL fetch_law_nonblk(                              &
          & i_startidx  = 1,                            & !in
          & i_endidx    = jmax,                         & !in
          & fetch       = wave_config%fetch_min_energy, & !in
          & fpmax       = wave_config%freqs(nfreqs),    & !in
          & sp10m       = u10(:),                       & !in
          & fp          = fpk(:),                       & !out
          & alphaj      = alphaj0(:))                     !out

    ! JONSWAP spectra
    CALL jonswap_nonblk(                         &
          & i_startidx = 1,                      & !in
          & i_endidx   = jmax,                   & !in
          & freqs      = wave_config%freqs,      & !in
          & gamma      = wave_config%GAMMA_wave, & !in
          & sa         = wave_config%SIGMA_A,    & !in
          & sb         = wave_config%SIGMA_B,    & !in
          & flmin      = flmin,                  & !in
          & alphaj     = alphaj0(:)*0.01_wp,     & !in
          & FP         = fpk(:),                 & !in
          & ET         = flminfr_tab(:,:))         !out
  END SUBROUTINE min_energy

END MODULE mo_init_wave_physics
