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

! Contains the variables to set up the wave  model.

MODULE mo_wave_state

  USE mo_kind,                      ONLY: wp
  USE mo_master_control,            ONLY: get_my_process_name
  USE mo_exception,                 ONLY: message, finish
  USE mo_parallel_config,           ONLY: nproma
  USE mo_model_domain,              ONLY: t_patch
  USE mo_grid_config,               ONLY: n_dom, l_limited_area, ifeedback_type
  USE mo_coupling_config,           ONLY: is_coupled_to_atmo, is_coupled_to_ocean
  USE mo_impl_constants,            ONLY: success, max_char_length, VNAME_LEN, TLEV_NNOW, &
    &                                     HINTP_TYPE_LONLAT_NNB, HINTP_TYPE_LONLAT_BCTR
  USE mo_math_constants,            ONLY: rad2deg
  USE mo_var_list,                  ONLY: add_var, add_ref, t_var_list_ptr
  USE mo_math_constants,            ONLY: pi2
  USE mo_var_list_register,         ONLY: vlr_add, vlr_del
  USE mo_var_groups,                ONLY: groups
  USE mo_cdi_constants,             ONLY: GRID_UNSTRUCTURED_CELL, GRID_CELL, &
    &                                     GRID_UNSTRUCTURED_EDGE, GRID_EDGE
  USE mo_cdi,                       ONLY: DATATYPE_FLT32, DATATYPE_FLT64, GRID_UNSTRUCTURED, &
    &                                     DATATYPE_PACK16, DATATYPE_INT
  USE mo_zaxis_type,                ONLY: ZA_SURFACE, ZA_FREQ_GENERIC, ZA_DIR_GENERIC, &
    &                                     ZA_DEPTH_BELOW_SEA
  USE mo_cf_convention,             ONLY: t_cf_var
  USE mo_grib2,                     ONLY: t_grib2_var, grib2_var, t_grib2_int_key, OPERATOR(+), &
    &                                     t_grib2_intarr_key
  USE mo_io_config,                 ONLY: lnetcdf_flt64_output
  USE mo_wave_io_config,            ONLY: t_wave_var_in_output
  USE mo_var_metadata,              ONLY: get_timelevel_string, create_hor_interp_metadata, post_op
  USE mo_var_metadata_types,        ONLY: CLASS_WAVE_SPECTRUM, POST_OP_SCALE
  USE mo_tracer_metadata,           ONLY: create_tracer_metadata
  USE mo_wave_types,                ONLY: t_wave_prog, t_wave_source, t_wave_diag, &
    &                                     t_wave_state, t_wave_state_lists
  USE mo_wave_config,               ONLY: t_wave_config, wave_config


  IMPLICIT NONE

  PRIVATE

  CHARACTER(LEN=*), PARAMETER :: modname = 'mo_wave_state'

  PUBLIC :: construct_wave_state    ! Constructor for the wave state
  PUBLIC :: destruct_wave_state     ! Destructor

  PUBLIC :: p_wave_state            ! state vector of wave variables
  PUBLIC :: p_wave_state_lists      ! lists for state vector of wave variables

  TYPE(t_wave_state),       TARGET, ALLOCATABLE :: p_wave_state(:)
  TYPE(t_wave_state_lists), TARGET, ALLOCATABLE :: p_wave_state_lists(:)

CONTAINS

  SUBROUTINE construct_wave_state(p_patch, n_timelevels, var_in_output)

    TYPE(t_patch),              INTENT(IN) :: p_patch(:)
    INTEGER,                    INTENT(IN) :: n_timelevels
    TYPE(t_wave_var_in_output), INTENT(IN) :: var_in_output(:) !< switches for optional diagnostics


    CHARACTER(len=max_char_length) :: listname
    CHARACTER(len=*), PARAMETER :: routine = modname//'::construct_wave_state'

    INTEGER :: ntl,  &! local number of timelevels
         ist,        &! status
         jg,         &! grid level counter
         jt           ! time level counter

    CALL message (routine, 'Construction of wave state started')

    ALLOCATE (p_wave_state(n_dom),p_wave_state_lists(n_dom), stat=ist)
    IF (ist /= success) THEN
       CALL finish(routine,'allocation for wave state failed')
    END IF

    DO jg = 1, n_dom

       ntl = n_timelevels

       ! As grid nesting is not called at every dynamics time step, an extra time
       ! level is needed for full-field interpolation and boundary-tendency calculation
       IF (n_dom > 1) THEN
          ntl = ntl + 1
       END IF

       IF (ifeedback_type == 1 .AND. jg > 1 .OR. l_limited_area .AND. jg == 1) ntl = ntl + 1

       ALLOCATE(p_wave_state(jg)%prog(1:ntl), STAT=ist)
       IF (ist/=SUCCESS) CALL finish(routine,                                   &
            'allocation of prognostic state array failed')

       ! create state list
       ALLOCATE(p_wave_state_lists(jg)%prog_list(1:ntl), STAT=ist)
       IF (ist/=SUCCESS) CALL finish(routine,                                   &
            'allocation of prognostic state list array failed')

       !
       ! Build lists for every timelevel
       !
       DO jt = 1, ntl
         WRITE(listname,'(a,i2.2,a,i2.2)') 'wave_state_prog_of_domain_',jg, &
             &                            '_and_timelev_',jt
         ! Build prog state list
         ! includes memory allocation
         CALL new_wave_state_prog_list(p_patch(jg), p_wave_state(jg)%prog(jt), &
              & p_wave_state_lists(jg)%prog_list(jt), &
              & listname, jt)
       END DO

       ! Build source state list
       ! includes memory allocation
       WRITE(listname,'(a,i2.2)') 'wave_state_source_of_domain_',jg
       CALL new_wave_state_source_list(&
            p_patch(jg), &
            p_wave_state(jg)%source, &
            p_wave_state_lists(jg)%source_list, &
            listname)

       ! Build diag state list
       ! includes memory allocation
       WRITE(listname,'(a,i2.2)') 'wave_state_diag_of_domain_',jg
       CALL new_wave_state_diag_list(&
            p_patch(jg), &
            p_wave_state(jg)%diag, &
            p_wave_state_lists(jg)%diag_list, &
            listname, &
            var_in_output(jg))

    END DO

    CALL message (routine, 'wave state construction completed')

  END SUBROUTINE construct_wave_state


  SUBROUTINE new_wave_state_prog_list(p_patch, p_prog, p_prog_list, listname, timelev)

    TYPE(t_patch),         INTENT(IN)    :: p_patch
    TYPE(t_wave_prog),     INTENT(INOUT) :: p_prog
    TYPE(t_var_list_ptr),  INTENT(INOUT) :: p_prog_list !< current prognostic state list
    CHARACTER(len=*),      INTENT(IN)    :: listname
    INTEGER,               INTENT(IN)    :: timelev

    CHARACTER(len=*), PARAMETER :: routine = modname//'::new_wave_state_prog_list'
    TYPE(t_cf_var)    :: cf_desc, new_cf_desc
    TYPE(t_grib2_var) :: grib2_desc

    INTEGER :: nblks_c       !< number of cell blocks to allocate
    INTEGER :: ibits         !< "entropy" of horizontal slice
    INTEGER :: datatype_flt  !< floating point accuracy in NetCDF output
    INTEGER :: ist

    CHARACTER(len=4)         :: suffix
    CHARACTER(len=VNAME_LEN) :: dir_ind_str, freq_ind_str
    CHARACTER(LEN=VNAME_LEN) :: wesd_container_name
    CHARACTER(LEN=VNAME_LEN) :: wesd_name

    TYPE(t_wave_config),               POINTER :: wc

    INTEGER :: shape3d_c(3), shape2d_c(2)
    INTEGER :: jf, jd

    INTEGER :: scaleFactor
    INTEGER :: scaled_wdsp1, scaled_wdsp2  ! scaled Grib2 waveDirectionSequenceParameters
    INTEGER :: scaled_wfsp1, scaled_wfsp2  ! scaled Grib2 waveFrequencySequenceParameters
    INTEGER :: scaleFactorArr(2), wdspArr(2), wfspArr(2)

    !determine size of arrays
    nblks_c = p_patch%nblks_c

    ! pointer to wave_config(jg) to save some paperwork
    wc => wave_config(p_patch%id)

    shape3d_c = (/nproma, wc%ndirs, nblks_c/)
    shape2d_c = (/nproma, nblks_c/)

    ibits = DATATYPE_PACK16   ! "entropy" of horizontal slice

    IF (lnetcdf_flt64_output) THEN
      datatype_flt = DATATYPE_FLT64
    ELSE
      datatype_flt = DATATYPE_FLT32
    END IF

    ! Suffix (mandatory for time level dependent variables)
    suffix = get_timelevel_string(timelev)

    ! allocate wesd state
    ALLOCATE(p_prog%wesd(wc%nfreqs), STAT=ist)
    IF (ist/=SUCCESS) CALL finish(routine, 'allocation of prognostic wesd state failed')

    ! scaling for waveDirectionSequenceParameters and waveFrequencySequenceParameters
    ! according to
    ! value = scaledValue * 10^{-scaleFactor}
    ! strictly speaking the scaleFactor refers to a power-of-10 exponent!
    !
    scaleFactor    = 6
    scaleFactorArr = (/scaleFactor, scaleFactor/)
    !
    ! scaled waveDirectionSequenceParameters
    ! hint arithmetic sequence for direction calculation (see mo_wave_config)
    ! dirs(jd) =  0.5_wp*wc%delth + REAL(jd-1,wp) * wc%delth
    scaled_wdsp1 = NINT(rad2deg * 0.5_wp*wc%delth * 10**(scaleFactor))
    scaled_wdsp2 = NINT(rad2deg * wc%delth * 10**(scaleFactor))
    wdspArr      = (/scaled_wdsp1, scaled_wdsp2/)
    !
    ! scaled waveFrequencySequenceParameter
    ! hint: geometric sequence for frequency calculation (see mo_wave_config)
    ! freqs(jf) = wc%fr1 * wc%co**(jf-1)
    scaled_wfsp1 = NINT(wc%fr1 * 10**(scaleFactor))
    scaled_wfsp2 = NINT(wc%co * 10**(scaleFactor))
    wfspArr      = (/scaled_wfsp1, scaled_wfsp2/)

    !
    ! Register a field list and apply default settings
    !
    CALL vlr_add(p_prog_list, TRIM(listname), patch_id=p_patch%id, lrestart=.TRUE., &
      &          model_type=get_my_process_name())

    DO jf = 1,wc%nfreqs
      write(freq_ind_str,'(I0.3)') jf

      ! wesd        wesd(jf)%ptr(nproma,ndirs,nblks_c)
      wesd_container_name = 'wesd_f'//TRIM(freq_ind_str)//suffix
      cf_desc    = t_cf_var(TRIM(wesd_container_name), 'm^2 s', &
        &                   'wave energy spectral density', datatype_flt)
      grib2_desc = grib2_var(10, 0, 42, ibits, GRID_UNSTRUCTURED, GRID_CELL)
      CALL add_var( p_prog_list, wesd_container_name, p_prog%wesd(jf)%ptr, &
           & GRID_UNSTRUCTURED_CELL, ZA_DIR_GENERIC, cf_desc, grib2_desc,  &
           & ldims=shape3d_c,                                              &
           & var_class=CLASS_WAVE_SPECTRUM,                                &
           & lcontainer=.TRUE., lrestart=.FALSE., loutput=.FALSE. )

      ALLOCATE(p_prog%wesd(jf)%dir(wc%ndirs), STAT=ist)
      IF (ist/=SUCCESS) CALL finish(routine, &
        &                    'allocation of p_prog%wesd(jf)%dir failed')

      DO jd = 1, wc%ndirs
        write(dir_ind_str,'(I0.3)') jd
        wesd_name = 'wesd_f'//TRIM(freq_ind_str)//'_d'//TRIM(dir_ind_str)//suffix

        cf_desc    = t_cf_var(TRIM(wesd_name), 'm^2 s', 'wave energy spectral density', datatype_flt)
        new_cf_desc = t_cf_var(TRIM(wesd_name), 'm^2 s rad^-1', 'wave energy spectral density', &
          &                    datatype_flt)
        grib2_desc = grib2_var(10, 0, 42, ibits, GRID_UNSTRUCTURED, GRID_CELL)     &
          &        + t_grib2_int_key("numberOfWaveDirections", wc%ndirs)           &
          &        + t_grib2_int_key("typeOfWaveDirectionSequence", 2)             &
          &        + t_grib2_int_key("waveDirectionNumber", jd)                    &
          &        + t_grib2_int_key("numberOfWaveDirectionSequenceParameters", 2) &
          &        + t_grib2_intarr_key("scaleFactorOfWaveDirectionSequenceParameter", scaleFactorArr) &
          &        + t_grib2_intarr_key("scaledValueOfWaveDirectionSequenceParameter", wdspArr) &
          &        + t_grib2_int_key("numberOfWaveFrequencies", wc%nfreqs)         &
          &        + t_grib2_int_key("typeOfWaveFrequencySequence", 1)             &
          &        + t_grib2_int_key("waveFrequencyNumber", jf)                    &
          &        + t_grib2_int_key("numberOfWaveFrequencySequenceParameters", 2) &
          &        + t_grib2_intarr_key("scaleFactorOfWaveFrequencySequenceParameter", scaleFactorArr) &
          &        + t_grib2_intarr_key("scaledValueOfWaveFrequencySequenceParameter", wfspArr)

        CALL add_ref( p_prog_list, wesd_container_name,                          &
          &  TRIM(wesd_name), p_prog%wesd(jf)%dir(jd)%p_2d,                      &
          &  GRID_UNSTRUCTURED_CELL, ZA_SURFACE,                                 &
          &  cf_desc, grib2_desc,                                                &
          &  ldims=shape2d_c, opt_var_ref_pos=2, ref_idx=jd,                     &
          &  loutput=.TRUE., lrestart=.TRUE.,                                    &
          &  tlev_source=TLEV_NNOW,                                              &
          &  tracer_info=create_tracer_metadata(lis_tracer=.TRUE.,               &
          &                        name        = TRIM(wesd_name),                &
          &                        lfeedback   = .TRUE.,                         &
          &                        ihadv_tracer= 2,                              &
          &                        ivadv_tracer= 0 ),                            &
          &  var_class=CLASS_WAVE_SPECTRUM,                                      &
          &  post_op=post_op(POST_OP_SCALE, arg1=1._wp/pi2, new_cf=new_cf_desc), &
          &  in_group=groups("wave_spectrum","DWD_FG_WAVE_VARS"))
      ENDDO
    ENDDO

  END SUBROUTINE new_wave_state_prog_list



  SUBROUTINE new_wave_state_source_list(p_patch, p_source, p_source_list, listname)

    TYPE(t_patch),         INTENT(IN)    :: p_patch
    TYPE(t_wave_source),   INTENT(INOUT) :: p_source
    TYPE(t_var_list_ptr),  INTENT(INOUT) :: p_source_list
    CHARACTER(len=*),      INTENT(IN)    :: listname

    CHARACTER(len=*), PARAMETER :: routine = modname//'::new_wave_state_source_list'

    TYPE(t_cf_var)    :: cf_desc
    TYPE(t_grib2_var) :: grib2_desc

    INTEGER :: ibits         !< "entropy" of horizontal slice
    INTEGER :: datatype_flt  !< floating point accuracy in NetCDF output
    INTEGER :: nblks_c
    INTEGER :: jf
    INTEGER :: ist
    INTEGER :: shape4d_c(4), shape3d_c(3)
    CHARACTER(len=VNAME_LEN) :: sl_name, fl_name, llws_name
    CHARACTER(len=3) :: freq_ind_str

    TYPE(t_wave_config), POINTER :: wc

    !------------------------------
    ! Ensure that all pointers have a defined association status
    !------------------------------
    NULLIFY(p_source%fl,  &
      &     p_source%sl,  &
      &     p_source%llws)

    ! pointer to wave_config(jg) to save some paperwork
    wc => wave_config(p_patch%id)

    nblks_c = p_patch%nblks_c

    shape4d_c = (/nproma, wc%ndirs, wc%nfreqs, nblks_c/)
    shape3d_c = (/nproma, wc%ndirs, nblks_c/)

    ibits = DATATYPE_PACK16   ! "entropy" of horizontal slice

    IF ( lnetcdf_flt64_output ) THEN
      datatype_flt = DATATYPE_FLT64
    ELSE
      datatype_flt = DATATYPE_FLT32
    ENDIF

    CALL vlr_add(p_source_list, TRIM(listname), patch_id=p_patch%id, lrestart=.TRUE., &
      &           model_type=get_my_process_name())


    ! fl          p_source%fl(nproma,ndirs,nfreqs,nblks_c)
    cf_desc    = t_cf_var('fl', '-', 'DIAG. MTRX OF FUNC. DERIVATIVE', datatype_flt)
    grib2_desc = grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_source_list, 'fl', p_source%fl,                  &
         & GRID_UNSTRUCTURED_CELL, ZA_DIR_GENERIC, cf_desc, grib2_desc, &
         & ldims=shape4d_c, &
         & lcontainer=.TRUE., lrestart=.FALSE., loutput=.FALSE.)

    ! sl          p_source%sl(nproma,ndirs,nfreqs,nblks_c)
    cf_desc    = t_cf_var('sl', '-', 'TOTAL SOURCE FUNCTION', datatype_flt)
    grib2_desc = grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_source_list, 'sl', p_source%sl,                      &
         & GRID_UNSTRUCTURED_CELL, ZA_DIR_GENERIC, cf_desc, grib2_desc, &
         & ldims=shape4d_c, &
         & lcontainer=.TRUE., lrestart=.FALSE., loutput=.FALSE.)

    ! llws        p_source%llws(nproma,ndirs,nfreqs,nblks_c)
    cf_desc    = t_cf_var('llws', '-', '1 where sinput is positive', datatype_int)
    grib2_desc = grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_source_list, 'llws', p_source%llws,                  &
         & GRID_UNSTRUCTURED_CELL, ZA_DIR_GENERIC, cf_desc, grib2_desc, &
         & ldims=shape4d_c,                                             &
         & lcontainer=.TRUE., lrestart=.FALSE., loutput=.FALSE.)


    ALLOCATE(p_source%sl_ptr(wc%nfreqs),           &
      &      p_source%fl_ptr(wc%nfreqs),           &
      &      p_source%llws_ptr(wc%nfreqs), STAT=ist)
    IF (ist/=SUCCESS) CALL finish(routine, &
      &                    'allocation of sl_ptr, fl_ptr and llws_ptr failed')

    DO jf = 1, wc%nfreqs
      write(freq_ind_str,'(I0.3)') jf

      sl_name = 'sl_f'//TRIM(freq_ind_str)
      CALL add_ref(p_source_list, 'sl',                                     &
           & sl_name, p_source%sl_ptr(jf)%p_3d,                             &
           & GRID_UNSTRUCTURED_CELL, ZA_DIR_GENERIC,                        &
           & t_cf_var(sl_name, '-',sl_name, datatype_flt),                  &
           & grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_CELL), &
           & ldims=shape3d_c, opt_var_ref_pos=3, ref_idx=jf,                &
           & lrestart=.FALSE., loutput=.TRUE.)

      fl_name = 'fl_f'//TRIM(freq_ind_str)
      CALL add_ref(p_source_list, 'fl',                                     &
           & fl_name, p_source%fl_ptr(jf)%p_3d,                             &
           & GRID_UNSTRUCTURED_CELL, ZA_DIR_GENERIC,                        &
           & t_cf_var(fl_name, '-',fl_name, datatype_flt),                  &
           & grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_CELL), &
           & ldims=shape3d_c, opt_var_ref_pos=3, ref_idx=jf,                &
           & lrestart=.FALSE., loutput=.TRUE.)

      llws_name = 'llws_f'//TRIM(freq_ind_str)
      CALL add_ref(p_source_list, 'llws',                                   &
           & llws_name, p_source%llws_ptr(jf)%p,                            &
           & GRID_UNSTRUCTURED_CELL, ZA_DIR_GENERIC,                        &
           & t_cf_var(llws_name, '-',llws_name, datatype_int),              &
           & grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_CELL), &
           & ldims=shape3d_c, opt_var_ref_pos=3, ref_idx=jf,                &
           & lrestart=.FALSE., loutput=.TRUE.,                              &
           & in_group=groups("wave_debug","DWD_FG_WAVE_VARS"))
    END DO

  END SUBROUTINE new_wave_state_source_list



  SUBROUTINE new_wave_state_diag_list(p_patch, p_diag, p_diag_list, listname, var_in_output)

    TYPE(t_patch),         INTENT(IN)    :: p_patch
    TYPE(t_wave_diag),     INTENT(INOUT) :: p_diag
    TYPE(t_var_list_ptr),  INTENT(INOUT) :: p_diag_list
    CHARACTER(len=*),      INTENT(IN)    :: listname
    TYPE(t_wave_var_in_output), INTENT(IN)    :: &  !< optional diagnostic switches
      &  var_in_output

    CHARACTER(len=*), PARAMETER :: routine = modname//'::new_wave_state_diag_list'

    TYPE(t_cf_var)    :: cf_desc
    TYPE(t_grib2_var) :: grib2_desc

    INTEGER :: ibits         !< "entropy" of horizontal slice
    INTEGER :: datatype_flt  !< floating point accuracy in NetCDF output
    INTEGER :: nblks_c, nblks_e
    INTEGER :: nfreqs, ndirs, jmax
    INTEGER :: nlev ! number of Stokes lavels (midpoints)
    INTEGER :: jg,jf
    INTEGER :: ist
    INTEGER :: shape2d_c(2)
    INTEGER :: shape3d_freq_c(3), shape3d_freq_e(3)
    INTEGER :: shape3d_depth_c(3)
    INTEGER :: shape1d_freq_p4(1), shape1d_dir_2(2)
    INTEGER :: shape4d_c(4), shape3d_dir_c(3)

    CHARACTER(len=3) :: freq_ind_str
    CHARACTER(len=VNAME_LEN) :: out_name

    TYPE(t_wave_config),      POINTER :: wc

    !------------------------------
    ! Ensure that all pointers have a defined association status
    !------------------------------
    NULLIFY(p_diag%gv_c, &
    &       p_diag%gv_e, &
    &       p_diag%emean, &
    &       p_diag%emeanws, &
    &       p_diag%femean, &
    &       p_diag%hrms_frac, &
    &       p_diag%wbr_frac, &
    &       p_diag%wave_num_c, &
    &       p_diag%wave_num_e, &
    &       p_diag%f1mean, &
    &       p_diag%femeanws, &
    &       p_diag%akmean, &
    &       p_diag%xkmean, &
    &       p_diag%swell_mask, &
    &       p_diag%last_prog_freq_ind, &
    &       p_diag%flminfr_tab, &
    &       p_diag%ustar, &
    &       p_diag%z0, &
    &       p_diag%tauw, &
    &       p_diag%phiaw, &
    &       p_diag%tauhf, &
    &       p_diag%phihf, &
    &       p_diag%IKP, &
    &       p_diag%IKP1, &
    &       p_diag%IKM, &
    &       p_diag%IKM1, &
    &       p_diag%K1W, &
    &       p_diag%K2W, &
    &       p_diag%K11W, &
    &       p_diag%K21W, &
    &       p_diag%JA1, &
    &       p_diag%JA2, &
    &       p_diag%AF11, &
    &       p_diag%FKLAP, &
    &       p_diag%FKLAP1, &
    &       p_diag%FKLAM, &
    &       p_diag%FKLAM1, &
    &       p_diag%hs, &
    &       p_diag%hs_dir, &
    &       p_diag%tpp, &
    &       p_diag%kp, &
    &       p_diag%tmp, &
    &       p_diag%tm1, &
    &       p_diag%tm2, &
    &       p_diag%ds, &
    &       p_diag%emean_sea, &
    &       p_diag%femean_sea, &
    &       p_diag%f1mean_sea, &
    &       p_diag%hs_sea, &
    &       p_diag%hs_sea_dir, &
    &       p_diag%pp_sea, &
    &       p_diag%kp_sea, &
    &       p_diag%mp_sea, &
    &       p_diag%m1_sea, &
    &       p_diag%m2_sea, &
    &       p_diag%ds_sea, &
    &       p_diag%emean_swell, &
    &       p_diag%femean_swell, &
    &       p_diag%f1mean_swell, &
    &       p_diag%hs_swell, &
    &       p_diag%hs_swell_dir, &
    &       p_diag%pp_swell, &
    &       p_diag%kp_swell, &
    &       p_diag%mp_swell, &
    &       p_diag%m1_swell, &
    &       p_diag%m2_swell, &
    &       p_diag%ds_swell, &
    &       p_diag%drag, &
    &       p_diag%tauwn, &
    &       p_diag%beta, &
    &       p_diag%u_stokes, &
    &       p_diag%v_stokes, &
    &       p_diag%last_idx_depth, &
    &       p_diag%kbar, &
    &       p_diag%T_stokes, &
    &       p_diag%u3d_stokes, &
    &       p_diag%v3d_stokes, &
    &       p_diag%steepness, &
    &       p_diag%thp_adj, &
    &       p_diag%sigma_f, &
    &       p_diag%sigma_th, &
    &       p_diag%qp_goda, &
    &       p_diag%nu_f_LH, &
    &       p_diag%bfis, &
    &       p_diag%relw_fth, &
    &       p_diag%kurtosis, &
    &       p_diag%hmaxn, &
    &       p_diag%hmax, &
    &       p_diag%Tmax, &
    &       p_diag%tauoc_x, &
    &       p_diag%tauoc_y, &
    &       p_diag%tauoc, &
    &       p_diag%phioc)

    ! pointer to wave_config(jg) to save some paperwork
    wc => wave_config(p_patch%id)

    jg      = p_patch%id
    nblks_c = p_patch%nblks_c
    nblks_e = p_patch%nblks_e

    nfreqs  = wc%nfreqs
    ndirs   = wc%ndirs
    jmax    = wc%jmax
    nlev    = wc%oce_stokes_nlev

    shape1d_freq_p4   = (/nfreqs+4/)
    shape1d_dir_2     = (/ndirs, 2/)
    shape2d_c         = (/nproma, nblks_c/)
    shape3d_freq_c    = (/nproma, nfreqs, nblks_c/)
    shape3d_freq_e    = (/nproma, nfreqs, nblks_e/)
    shape3d_dir_c     = (/nproma, ndirs, nblks_c/)
    shape3d_depth_c   = (/nproma, nlev, nblks_c/)
    shape4d_c         = (/nproma, ndirs, nfreqs, nblks_c/)


    ibits = DATATYPE_PACK16   ! "entropy" of horizontal slice

    IF ( lnetcdf_flt64_output ) THEN
      datatype_flt = DATATYPE_FLT64
    ELSE
      datatype_flt = DATATYPE_FLT32
    ENDIF

    CALL vlr_add(p_diag_list, TRIM(listname), patch_id=p_patch%id, lrestart=.TRUE., &
      &         model_type=get_my_process_name())


    ! Wave group velocity
    cf_desc    = t_cf_var('gv_c', 'm s-1', 'group velocity at cells', datatype_flt)
    grib2_desc = grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'gv_c', p_diag%gv_c,                       &
         & GRID_UNSTRUCTURED_CELL, ZA_FREQ_GENERIC, cf_desc, grib2_desc, &
         & ldims=shape3d_freq_c, in_group=groups("wave_phy_ext"),        &
         & lrestart=.FALSE., loutput=.TRUE.)

    cf_desc    = t_cf_var('gv_e', 'm s-1', 'group velocity at edges', datatype_flt)
    grib2_desc = grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_EDGE)
    CALL add_var(p_diag_list, 'gv_e', p_diag%gv_e,                       &
         & GRID_UNSTRUCTURED_EDGE, ZA_FREQ_GENERIC, cf_desc, grib2_desc, &
         & ldims=shape3d_freq_e, in_group=groups("wave_phy_ext"),        &
         & lrestart=.FALSE., loutput=.TRUE.)

    ! Wave physics group
    cf_desc    = t_cf_var('emean', 'm^2', 'total wave energy', datatype_flt)
    grib2_desc = grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'emean', p_diag%emean,                &
         & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape2d_c, in_group=groups("wave_phy"))

    cf_desc    = t_cf_var('emeanws', 'm^2', 'wind sea wave energy', datatype_flt)
    grib2_desc = grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'emeanws', p_diag%emeanws,            &
         & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape2d_c, in_group=groups("wave_phy"))

    cf_desc    = t_cf_var('femean', 's-1', 'mean frequency (m0/m-1)', datatype_flt)
    grib2_desc = grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'femean', p_diag%femean,              &
         & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape2d_c, in_group=groups("wave_phy"))

    cf_desc    = t_cf_var('hrms_frac', '-', 'square ratio (Hrms / Hmax)^2', datatype_flt)
    grib2_desc = grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'hrms_frac', p_diag%hrms_frac,        &
         & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape2d_c)

    cf_desc    = t_cf_var('wbr_frac', '-', 'fraction of breaking waves', datatype_flt)
    grib2_desc = grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'wbr_frac', p_diag%wbr_frac,          &
         & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape2d_c, in_group=groups("wave_phy"))

    cf_desc    = t_cf_var('wave_num_c', '1/m', 'wave number at cell center', datatype_flt)
    grib2_desc = grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'wave_num_c', p_diag%wave_num_c,           &
         & GRID_UNSTRUCTURED_CELL, ZA_FREQ_GENERIC, cf_desc, grib2_desc, &
         & ldims=shape3d_freq_c,                                         &
         & lrestart=.FALSE., loutput=.TRUE.)

    cf_desc    = t_cf_var('wave_num_e', 'm-1', 'wave number at edge midpoint', datatype_flt)
    grib2_desc = grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_EDGE)
    CALL add_var(p_diag_list, 'wave_num_e', p_diag%wave_num_e,           &
         & GRID_UNSTRUCTURED_EDGE, ZA_FREQ_GENERIC, cf_desc, grib2_desc, &
         & ldims=shape3d_freq_e,                                         &
         & lrestart=.FALSE., loutput=.TRUE.)

    cf_desc    = t_cf_var('f1mean', 's-1', 'mean frequency based on f-moment (m1/m0)', datatype_flt)
    grib2_desc = grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'f1mean', p_diag%f1mean,              &
         & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape2d_c, in_group=groups("wave_phy"))

    cf_desc    = t_cf_var('femeanws', 's-1', 'wind sea mean frequency (m0/m-1)', datatype_flt)
    grib2_desc = grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'femeanws', p_diag%femeanws,          &
         & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape2d_c, in_group=groups("wave_phy"))

    cf_desc    = t_cf_var('akmean', '', 'Mean wavenumber based on SQRT(1/K)-moment, wm1', datatype_flt)
    grib2_desc = grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'akmean', p_diag%akmean,              &
         & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape2d_c, in_group=groups("wave_phy"))

    cf_desc    = t_cf_var('xkmean', '', 'Mean wavenumber based on SQRT(K)-moment, wm2', datatype_flt)
    grib2_desc = grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'xkmean', p_diag%xkmean,              &
         & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape2d_c, in_group=groups("wave_phy"))

    ! swell_mask       p_diag%swell_mask(nproma,ndirs,nfreqs,nblks_c)
    cf_desc    = t_cf_var('swell_mask', '-', 'swell mask for tracers', datatype_int)
    grib2_desc = grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'swell_mask', p_diag%swell_mask,&
         & GRID_UNSTRUCTURED_CELL, ZA_DIR_GENERIC, cf_desc, grib2_desc, &
         & lcontainer=.TRUE., lrestart=.FALSE., loutput=.FALSE.,    &
         & ldims=shape4d_c)

    ALLOCATE(p_diag%swmask_ptr(nfreqs), STAT=ist)
    IF (ist/=SUCCESS) CALL finish(routine,               &
          'allocation of swmask_ptr failed')

    DO jf = 1, nfreqs
      write(freq_ind_str,'(I0.3)') jf

      out_name = 'swmask_f'//TRIM(freq_ind_str)
      CALL add_ref(p_diag_list, 'swell_mask',                               &
           & out_name, p_diag%swmask_ptr(jf)%p,                             &
           & GRID_UNSTRUCTURED_CELL, ZA_DIR_GENERIC,                        &
           & t_cf_var(out_name, '-',out_name, datatype_int),                &
           & grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_CELL), &
           & opt_var_ref_pos=3, ref_idx=jf, ldims=shape3d_dir_c,            &
           & lrestart=.TRUE., loutput=.TRUE.,                               &
           & in_group=groups("wave_debug","DWD_FG_WAVE_VARS"))
    END DO


    cf_desc    = t_cf_var('last_prog_freq_ind', '-', 'last frequency index of the prognostic range', datatype_int)
    grib2_desc = grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'last_prog_freq_ind', p_diag%last_prog_freq_ind, &
         & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc,            &
         & lrestart=.FALSE., loutput=.TRUE.,                                   &
         & ldims=shape2d_c, in_group=groups("wave_phy"))

    cf_desc    = t_cf_var('flminfr_tab', 'm^2 Hz-1', 'minimum allowed energy level', datatype_flt)
    grib2_desc = grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'flminfr_tab', p_diag%flminfr_tab,          &
         & GRID_UNSTRUCTURED_CELL, ZA_FREQ_GENERIC, cf_desc, grib2_desc,  &
         & ldims=(/jmax, nfreqs/),                                        &
         & lrestart=.FALSE., loutput=.FALSE.)

    cf_desc    = t_cf_var('friction_velocity', 'm s-1', 'friction velocity', datatype_flt)
    grib2_desc = grib2_var(10, 0, 17, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'ustar', p_diag%ustar,                &
         & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape2d_c , in_group=groups("wave_phy", "DWD_FG_WAVE_VARS"))

    cf_desc    = t_cf_var('roughness_length', 'm', 'Surface roughness length', datatype_flt)
    grib2_desc = grib2_var(2, 0, 1, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'z0', p_diag%z0,                      &
         & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape2d_c , in_group=groups("wave_phy"))

    cf_desc    = t_cf_var('wave_stress', 'm2 s-2', 'wave stress divided by air density', datatype_flt)
    grib2_desc = grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'tauw', p_diag%tauw,                  &
         & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.TRUE., loutput=.TRUE.,                         &
         & ldims=shape2d_c , in_group=groups("wave_phy","wave_fluxes"))

    cf_desc    = t_cf_var('integrated_energy_flux', 'W m-2', 'integrated energy flux from wind into waves', datatype_flt)
    grib2_desc = grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'phiaw', p_diag%phiaw,                &
         & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape2d_c , in_group=groups("wave_phy","wave_fluxes"))

    cf_desc    = t_cf_var('tauhf', 'm2 s-2', 'high-fequency stress divided by air density', datatype_flt)
    grib2_desc = grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'tauhf', p_diag%tauhf,                &
         & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape2d_c, in_group=groups("wave_phy"))

    cf_desc    = t_cf_var('phihf', 'W m-2', 'high-frequency energy flux into waves', datatype_flt)
    grib2_desc = grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'phihf', p_diag%phihf,                &
         & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape2d_c, in_group=groups("wave_phy"))

    ! for discrete approximation of nonlinear transfer
    cf_desc    = t_cf_var('IKP', '-', 'IKP', datatype_int)
    grib2_desc = grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'IKP', p_diag%IKP,                    &
         & GRID_UNSTRUCTURED_EDGE, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape1d_freq_p4)

    cf_desc    = t_cf_var('IKP1', '-', 'IKP1', datatype_int)
    grib2_desc = grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'IKP1', p_diag%IKP1,                  &
         & GRID_UNSTRUCTURED_EDGE, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape1d_freq_p4)

    cf_desc    = t_cf_var('IKM', '-', 'IKM', datatype_int)
    grib2_desc = grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'IKM', p_diag%IKM,                    &
         & GRID_UNSTRUCTURED_EDGE, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape1d_freq_p4)

    cf_desc    = t_cf_var('IKM1', '-', 'IKM1', datatype_int)
    grib2_desc = grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'IKM1', p_diag%IKM1,                  &
         & GRID_UNSTRUCTURED_EDGE, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape1d_freq_p4)

    cf_desc    = t_cf_var('K1W', '-', 'K1W', datatype_int)
    grib2_desc = grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'K1W', p_diag%K1W,                    &
         & GRID_UNSTRUCTURED_EDGE, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape1d_dir_2)

    cf_desc    = t_cf_var('K2W', '-', 'K2W', datatype_int)
    grib2_desc = grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'K2W', p_diag%K2W,                    &
         & GRID_UNSTRUCTURED_EDGE, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape1d_dir_2)

    cf_desc    = t_cf_var('K11W', '-', 'K11W', datatype_int)
    grib2_desc = grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'K11W', p_diag%K11W,                  &
         & GRID_UNSTRUCTURED_EDGE, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape1d_dir_2)

    cf_desc    = t_cf_var('K21W', '-', 'K21W', datatype_int)
    grib2_desc = grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'K21W', p_diag%K21W,                  &
         & GRID_UNSTRUCTURED_EDGE, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape1d_dir_2)

    cf_desc    = t_cf_var('JA1', '-', 'JA1', datatype_int)
    grib2_desc = grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'JA1', p_diag%JA1,                    &
         & GRID_UNSTRUCTURED_EDGE, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape1d_dir_2)

    cf_desc    = t_cf_var('JA2', '-', 'JA2', datatype_int)
    grib2_desc = grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'JA2', p_diag%JA2,                    &
         & GRID_UNSTRUCTURED_EDGE, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape1d_dir_2)

    cf_desc    = t_cf_var('AF11', '-', 'AF11', datatype_flt)
    grib2_desc = grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'AF11', p_diag%AF11,                  &
         & GRID_UNSTRUCTURED_EDGE, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape1d_freq_p4)

    cf_desc    = t_cf_var('FKLAP', '-', 'FKLAP', datatype_flt)
    grib2_desc = grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'FKLAP', p_diag%FKLAP,                &
         & GRID_UNSTRUCTURED_EDGE, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape1d_freq_p4)

    cf_desc    = t_cf_var('FKLAP1', '-', 'FKLAP1', datatype_flt)
    grib2_desc = grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'FKLAP1', p_diag%FKLAP1,              &
         & GRID_UNSTRUCTURED_EDGE, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape1d_freq_p4)

    cf_desc    = t_cf_var('FKLAM', '-', 'FKLAM', datatype_flt)
    grib2_desc = grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'FKLAM', p_diag%FKLAM,                &
         & GRID_UNSTRUCTURED_EDGE, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape1d_freq_p4)

    cf_desc    = t_cf_var('FKLAM1', '-', 'FKLAM1', datatype_flt)
    grib2_desc = grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'FKLAM1', p_diag%FKLAM1,              &
         & GRID_UNSTRUCTURED_EDGE, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape1d_freq_p4)

    ! wave group
    ! total
    cf_desc    = t_cf_var('hs', 'm', 'Total significant wave height', datatype_flt)
    grib2_desc = grib2_var(10, 0, 3, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'hs', p_diag%hs,                      &
         & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
         & hor_interp=create_hor_interp_metadata(                   &
         &    hor_intp_type=HINTP_TYPE_LONLAT_BCTR,                 &
         &    fallback_type=HINTP_TYPE_LONLAT_NNB),                 &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape2d_c, in_group=groups("wave_short"))

    cf_desc    = t_cf_var('hs_dir', 'deg', 'Total mean wave direction', datatype_flt)
    grib2_desc = grib2_var(10, 0, 14, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'hs_dir', p_diag%hs_dir,              &
         & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape2d_c, in_group=groups("wave_short"))

    cf_desc    = t_cf_var('tpp', 's', 'Total wave peak period', datatype_flt)
    grib2_desc = grib2_var(10, 0, 34, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'tpp', p_diag%tpp,    &
         & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape2d_c, in_group=groups("wave_short"))

    cf_desc    = t_cf_var('kp', 'm-1', 'Total wave peak wavenumber', datatype_flt)
    grib2_desc = grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'kp', p_diag%kp,                      &
         & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape2d_c, in_group=groups("wave_short"))

    cf_desc    = t_cf_var('tmp', 's', 'Total wave mean period', datatype_flt)
    grib2_desc = grib2_var(10, 0, 15, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'tmp', p_diag%tmp,    &
         & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape2d_c, in_group=groups("wave_short"))

    cf_desc    = t_cf_var('tm1', 's', 'Total m1 wave period', datatype_flt)
    grib2_desc = grib2_var(10, 0, 25, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'tm1', p_diag%tm1,                    &
         & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape2d_c, in_group=groups("wave_short"))

    cf_desc    = t_cf_var('tm2', 's', 'Total m2 wave period', datatype_flt)
    grib2_desc = grib2_var(10, 0, 28, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'tm2', p_diag%tm2,                    &
         & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape2d_c, in_group=groups("wave_short"))

    cf_desc    = t_cf_var('ds', 'deg', 'Total directional wave spread', datatype_flt)
    grib2_desc = grib2_var(10, 0, 31, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'ds', p_diag%ds,                      &
         & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape2d_c, in_group=groups("wave_short"))

    ! wind sea
    cf_desc    = t_cf_var('emean_sea', 'm^2', 'Wind sea wave energy', datatype_flt)
    grib2_desc = grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'emean_sea', p_diag%emean_sea,        &
         & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape2d_c, in_group=groups("wave_phy"))

    cf_desc    = t_cf_var('femean_sea', 's-1', 'Wind sea mean frequency (m0/m-1)', datatype_flt)
    grib2_desc = grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'femean_sea', p_diag%femean_sea,      &
         & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape2d_c, in_group=groups("wave_phy"))

    cf_desc    = t_cf_var('f1mean_sea', 's-1', 'Wind sea mean frequency (m1/m0)', datatype_flt)
    grib2_desc = grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'f1mean_sea', p_diag%f1mean_sea,      &
         & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape2d_c, in_group=groups("wave_phy"))

    cf_desc    = t_cf_var('hs_sea', 'm', 'Sea significant wave height', datatype_flt)
    grib2_desc = grib2_var(10, 0, 5, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'hs_sea', p_diag%hs_sea,              &
         & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape2d_c, in_group=groups("wave_short"))

    cf_desc    = t_cf_var('hs_sea_dir', 'deg', 'Sea mean wave direction', datatype_flt)
    grib2_desc = grib2_var(10, 0, 4, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'hs_sea_dir', p_diag%hs_sea_dir,      &
         & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape2d_c, in_group=groups("wave_short"))

    cf_desc    = t_cf_var('pp_sea', 's', 'Sea wave peak period', datatype_flt)
    grib2_desc = grib2_var(10, 0, 35, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'pp_sea', p_diag%pp_sea,              &
         & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape2d_c, in_group=groups("wave_short"))

    cf_desc   = t_cf_var('kp_sea', 'm-1', 'Sea wave peak wavenumber', datatype_flt)
    grib2_desc = grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'kp_sea', p_diag%kp_sea,              &
         & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape2d_c, in_group=groups("wave_short"))

    cf_desc    = t_cf_var('mp_sea', 's', 'Sea wave mean period', datatype_flt)
    grib2_desc = grib2_var(10, 0, 6, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'mp_sea', p_diag%mp_sea,              &
         & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape2d_c, in_group=groups("wave_short"))

    cf_desc    = t_cf_var('m1_sea', 's', 'Sea m1 wave period', datatype_flt)
    grib2_desc = grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'm1_sea', p_diag%m1_sea,              &
         & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape2d_c, in_group=groups("wave_short"))

    cf_desc    = t_cf_var('m2_sea', 's', 'Sea m2 wave period', datatype_flt)
    grib2_desc = grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'm2_sea', p_diag%m2_sea,              &
         & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape2d_c, in_group=groups("wave_short"))

    cf_desc    = t_cf_var('ds_sea', 'deg', 'Sea directional wave spread', datatype_flt)
    grib2_desc = grib2_var(10, 0, 32, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'ds_sea', p_diag%ds_sea,              &
         & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape2d_c)   !, in_group=groups("wave_short"))

    ! swell
    cf_desc    = t_cf_var('emean_swell', 'm^2', 'Swell wave energy', datatype_flt)
    grib2_desc = grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'emean_swell', p_diag%emean_swell,    &
         & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape2d_c, in_group=groups("wave_phy"))

    cf_desc    = t_cf_var('femean_swell', 's-1', 'Swell mean frequency (m0/m-1)', datatype_flt)
    grib2_desc = grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'femean_swell', p_diag%femean_swell,  &
         & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape2d_c, in_group=groups("wave_phy"))

    cf_desc    = t_cf_var('f1mean_swell', 's-1', 'Swell mean frequency (m1/m0)', datatype_flt)
    grib2_desc = grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'f1mean_swell', p_diag%f1mean_swell,  &
         & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape2d_c, in_group=groups("wave_phy"))

    cf_desc    = t_cf_var('hs_swell', 'm', 'Swell significant wave height', datatype_flt)
    grib2_desc = grib2_var(10, 0, 8, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'hs_swell', p_diag%hs_swell,          &
         & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape2d_c, in_group=groups("wave_short"))

    cf_desc    = t_cf_var('hs_swell_dir', 'deg', 'Swell mean wave direction', datatype_flt)
    grib2_desc = grib2_var(10, 0, 7, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'hs_swell_dir', p_diag%hs_swell_dir,  &
         & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape2d_c, in_group=groups("wave_short"))

    cf_desc    = t_cf_var('pp_swell', 's', 'Swell wave peak period', datatype_flt)
    grib2_desc = grib2_var(10, 0, 36, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'pp_swell', p_diag%pp_swell,          &
         & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape2d_c, in_group=groups("wave_short"))

    cf_desc   = t_cf_var('kp_swell', 'm-1', 'Swell wave peak wavenumber', datatype_flt)
    grib2_desc = grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'kp_swell', p_diag%kp_swell,          &
         & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape2d_c, in_group=groups("wave_short"))

    cf_desc    = t_cf_var('mp_swell', 's', 'Swell wave mean period', datatype_flt)
    grib2_desc = grib2_var(10, 0, 9, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'mp_swell', p_diag%mp_swell,          &
         & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape2d_c, in_group=groups("wave_short"))

    cf_desc    = t_cf_var('m1_swell', 's', 'Swell m1 wave period', datatype_flt)
    grib2_desc = grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'm1_swell', p_diag%m1_swell,          &
         & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape2d_c, in_group=groups("wave_short"))

    cf_desc    = t_cf_var('m2_swell', 's', 'Swell m2 wave period', datatype_flt)
    grib2_desc = grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'm2_swell', p_diag%m2_swell,          &
         & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape2d_c, in_group=groups("wave_short"))

    cf_desc    = t_cf_var('ds_swell', 'deg', 'Swell directional wave spread', datatype_flt)
    grib2_desc = grib2_var(10, 0, 33, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'ds_swell', p_diag%ds_swell,          &
         & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape2d_c, in_group=groups("wave_short"))

    cf_desc    = t_cf_var('drag', '-', 'Drag coefficient', datatype_flt)
    grib2_desc = grib2_var(10, 0, 16, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'drag', p_diag%drag,                  &
         & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape2d_c, in_group=groups("wave_debug"))

    cf_desc    = t_cf_var('tauwn', '-', 'Normalized wave stress', datatype_flt)
    grib2_desc = grib2_var(10, 0, 19, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'tauwn', p_diag%tauwn,                &
         & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape2d_c, in_group=groups("wave_debug","wave_fluxes"))

    cf_desc    = t_cf_var('beta', '-', 'Charnock parameter', datatype_flt)
    grib2_desc = grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'beta', p_diag%beta,                  &
         & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape2d_c, in_group=groups("wave_debug"))

    cf_desc    = t_cf_var('u_stokes', 'ms-1', 'U-component surface Stokes drift', datatype_flt)
    grib2_desc = grib2_var(10, 0, 21, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'u_stokes', p_diag%u_stokes,          &
         & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape2d_c, in_group=groups("wave_stokes"))

    cf_desc    = t_cf_var('v_stokes', 'ms-1', 'V-component surface Stokes drift', datatype_flt)
    grib2_desc = grib2_var(10, 0, 22, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'v_stokes', p_diag%v_stokes,          &
         & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape2d_c, in_group=groups("wave_stokes"))

    !!------------------------------------------------------------------------------------------
    ! Extreme wave statistics and diagnostics
    !!------------------------------------------------------------------------------------------

    cf_desc    = t_cf_var('steepness', '-', 'Wave steepness', datatype_flt)
    grib2_desc = grib2_var(10, 0, 192, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'steepness', p_diag%steepness,        &
         & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape2d_c, in_group=groups("wave_extreme"))

    cf_desc    = t_cf_var('thp_adj', '-', 'Adjusted peak direction', datatype_flt)
    grib2_desc = grib2_var(10, 0, 46, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'thp_adj', p_diag%thp_adj,            &
         & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape2d_c, in_group=groups("wave_extreme"))

    cf_desc    = t_cf_var('sigma_f', '-', 'Frequency bandwith', datatype_flt)
    grib2_desc = grib2_var(255,255,255, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'sigma_f', p_diag%sigma_f,            &
         & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape2d_c, in_group=groups("wave_extreme"))

    cf_desc    = t_cf_var('sigma_th', '-', 'Directional bandwith', datatype_flt)
    grib2_desc = grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'sigma_th', p_diag%sigma_th,          &
         & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape2d_c, in_group=groups("wave_extreme"))

    cf_desc    = t_cf_var('qp_goda', '-', 'Goda peakedness parameter', datatype_flt)
    grib2_desc = grib2_var(10, 0, 98, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'qp_goda', p_diag%qp_goda,            &
         & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape2d_c, in_group=groups("wave_extreme"))

    cf_desc    = t_cf_var('nu_f_LH', '-', 'Longuet-Higgins broadbandness parameter', datatype_flt)
    grib2_desc = grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'nu_f_LH', p_diag%nu_f_LH,            &
         & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape2d_c, in_group=groups("wave_extreme"))

    cf_desc    = t_cf_var('bfis', '-', 'finite-depth Benjamin-Feir index', datatype_flt)
    grib2_desc = grib2_var(10, 0, 44, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'bfis', p_diag%bfis,                &
         & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape2d_c, in_group=groups("wave_extreme"))

    cf_desc    = t_cf_var('relw_fth', '-', 'Relative direction-frequency width', datatype_flt)
    grib2_desc = grib2_var(10, 0, 80, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'relw_fth', p_diag%relw_fth,          &
         & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape2d_c, in_group=groups("wave_extreme"))

    cf_desc    = t_cf_var('kurtosis', '-', 'Spectral kurtosis', datatype_flt)
    grib2_desc = grib2_var(10, 0, 43, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'kurtosis', p_diag%kurtosis,          &
         & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape2d_c, in_group=groups("wave_extreme"))

    cf_desc    = t_cf_var('hmaxn', '-', 'Normalised max. significant wave height', datatype_flt)
    grib2_desc = grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'hmaxn', p_diag%hmaxn,                &
         & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape2d_c, in_group=groups("wave_extreme"))

    ! The grib2 reference is for the envelope-max individual wave height
    cf_desc    = t_cf_var('hmax', 'm', 'Max. significant wave height', datatype_flt)
    grib2_desc = grib2_var(10, 0, 93, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'hmax', p_diag%hmax,                  &
         & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape2d_c, in_group=groups("wave_extreme"))

    cf_desc    = t_cf_var('Tmax', 's', 'Max. wave period', datatype_flt)
    grib2_desc = grib2_var(10, 0, 23, ibits, GRID_UNSTRUCTURED, GRID_CELL)
    CALL add_var(p_diag_list, 'Tmax', p_diag%Tmax,                  &
         & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
         & lrestart=.FALSE., loutput=.TRUE.,                        &
         & ldims=shape2d_c, in_group=groups("wave_extreme"))


    IF (var_in_output%last_idx_depth .OR. &
      & var_in_output%kbar           .OR. &
      & var_in_output%T_stokes       .OR. &
      & var_in_output%u3d_stokes     .OR. &
      & var_in_output%v3d_stokes)   THEN

      IF (TRIM(wc%oce_vct_filename) == "") THEN
        CALL finish(routine, "file name for ocean vertical interfaces table (namelist oce_vct_filename) is not defined")
      END IF

      cf_desc    = t_cf_var('last_idx_depth', '-', 'last index of depth layer', datatype_int)
      grib2_desc = grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_CELL)
      CALL add_var(p_diag_list, 'last_idx_depth', p_diag%last_idx_depth, &
           & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc,    &
           & lrestart=.FALSE., loutput=.TRUE.,                           &
           & ldims=shape2d_c)

      cf_desc    = t_cf_var('kbar', 'm-1', 'Breivik wavenumber', datatype_flt)
      grib2_desc = grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_CELL)
      CALL add_var(p_diag_list, 'kbar', p_diag%kbar,                  &
           & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
           & lrestart=.FALSE., loutput=.TRUE.,                        &
           & ldims=shape2d_c)

      cf_desc    = t_cf_var('T_stokes', 'm2s-1', 'Magnitude of Stokes transport', datatype_flt)
      grib2_desc = grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_CELL)
      CALL add_var(p_diag_list, 'T_stokes', p_diag%T_stokes,          &
           & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
           & lrestart=.FALSE., loutput=.TRUE.,                        &
           & ldims=shape2d_c)

      cf_desc    = t_cf_var('u3d_stokes', 'ms-1', 'U-component of 3d Stokes drift', datatype_flt)
      grib2_desc = grib2_var(10, 0, 21, ibits, GRID_UNSTRUCTURED, GRID_CELL)
      CALL add_var(p_diag_list, 'u3d_stokes', p_diag%u3d_stokes,              &
           & GRID_UNSTRUCTURED_CELL, ZA_DEPTH_BELOW_SEA, cf_desc, grib2_desc, &
           & lrestart=.FALSE., loutput=.TRUE.,                                &
           & ldims=shape3d_depth_c)

      cf_desc    = t_cf_var('v3d_stokes', 'ms-1', 'V-component of 3d Stokes drift', datatype_flt)
      grib2_desc = grib2_var(10, 0, 22, ibits, GRID_UNSTRUCTURED, GRID_CELL)
      CALL add_var(p_diag_list, 'v3d_stokes', p_diag%v3d_stokes,              &
           & GRID_UNSTRUCTURED_CELL, ZA_DEPTH_BELOW_SEA, cf_desc, grib2_desc, &
           & lrestart=.FALSE., loutput=.TRUE.,                                &
           & ldims=shape3d_depth_c)
    END IF

    IF (is_coupled_to_ocean() .OR. var_in_output%tauoc_x    &
      &                       .OR. var_in_output%tauoc_y    &
      &                       .OR. var_in_output%tauoc      &
      &                       .OR. var_in_output%phioc)  THEN

      ! wave stress normalised by roair: bare x wave stress has code (10,0,90) and units N/m^2
      cf_desc    = t_cf_var('tauoc_x', '(m/s)^2', 'Wave-to-ocean stress x-component', datatype_int)
      grib2_desc = grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_CELL)
      CALL add_var(p_diag_list, 'tauoc_x', p_diag%tauoc_x,               &
           & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc,    &
           & lrestart=.FALSE., loutput=.TRUE.,                           &
           & ldims=shape2d_c, in_group=groups("wave_fluxes"))

      ! wave stress normalised by roair: bare y stress has code (10,0,91) and units N/m^2
      cf_desc    = t_cf_var('tauoc_y', '(m/s)^2', 'Wave-to-ocean stress y-component', datatype_int)
      grib2_desc = grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_CELL)
      CALL add_var(p_diag_list, 'tauoc_y', p_diag%tauoc_y,               &
           & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc,    &
           & lrestart=.FALSE., loutput=.TRUE.,                           &
           & ldims=shape2d_c, in_group=groups("wave_fluxes"))

      ! wave stress normalised by roair:  normalised stress has code (10,0,84)
      cf_desc    = t_cf_var('tauoc', '(m/s)^2', 'Wave-to-ocean stress', datatype_int)
      grib2_desc = grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_CELL)
      CALL add_var(p_diag_list, 'tauoc', p_diag%tauoc,                &
           & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
           & lrestart=.FALSE., loutput=.TRUE.,                        &
           & ldims=shape2d_c, in_group=groups("wave_fluxes"))

      ! wave-to-ocean energy flux divided by roair: normalised flux has code (10,0,85)
      cf_desc    = t_cf_var('phioc', 'kg/s^3', 'Wave-to-ocean energy flux', datatype_int)
      grib2_desc = grib2_var(255, 255, 255, ibits, GRID_UNSTRUCTURED, GRID_CELL)
      CALL add_var(p_diag_list, 'phioc', p_diag%phioc,                &
           & GRID_UNSTRUCTURED_CELL, ZA_SURFACE, cf_desc, grib2_desc, &
           & lrestart=.FALSE., loutput=.TRUE.,                        &
           & ldims=shape2d_c, in_group=groups("wave_fluxes"))
    END IF



  END SUBROUTINE new_wave_state_diag_list

  !>
  !! Destruction of wave-specific variable lists and memory deallocation
  !!
  SUBROUTINE destruct_wave_state ()

    INTEGER :: ist
    INTEGER :: jg, jt
    CHARACTER(len=*), PARAMETER :: routine = modname//'::destruct_wave_state'

    DO jg = 1, n_dom
      ! delete prognostic state list elements
      DO jt = 1, SIZE(p_wave_state_lists(jg)%prog_list(:))
        CALL vlr_del(p_wave_state_lists(jg)%prog_list(jt))
      ENDDO

      ! delete source state list elements
      CALL vlr_del(p_wave_state_lists(jg)%source_list)

      ! delete diagnostics state list elements
      CALL vlr_del(p_wave_state_lists(jg)%diag_list)

      ! deallocate state lists and arrays
      DEALLOCATE(p_wave_state_lists(jg)%prog_list, stat=ist)
      IF (ist /= success) THEN
        CALL finish(routine,'deallocation for prog_list array failed')
      END IF

      DEALLOCATE(p_wave_state(jg)%prog, stat=ist)
      IF (ist /= success) THEN
        CALL finish(routine,'deallocation of prognostic state array failed')
      END IF
    ENDDO

    ! deallocate states
    DEALLOCATE(p_wave_state, p_wave_state_lists, stat=ist)
    IF (ist /= success) THEN
      CALL finish(routine,'deallocation for p_wave_state failed')
    END IF

  END SUBROUTINE destruct_wave_state


END MODULE mo_wave_state
