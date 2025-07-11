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

! provides access to icon functionlity for ragnarok
#ifndef __NO_RAGNAROK__

MODULE  mo_ragnarok_bridge
  USE ISO_C_BINDING, ONLY: c_int, c_ptr, c_null_ptr, c_loc, c_funptr, c_FUNLOC, &
       & c_char, c_f_pointer, c_bool, c_double
  USE mo_kind, ONLY: wp
  USE mo_exception, ONLY: message, message_text, finish, warning
  USE mo_parallel_config, ONLY: nproma
  USE mo_model_domain, ONLY: t_patch, p_patch
  USE mo_io_units, ONLY: filename_max
  USE mo_ragnarok_support, ONLY: t_f2c_ftable, t_dom_info, t_f2c_patch_descr, &
       & t_patch_info, init_ragnarok_support, &
       & t_comm_patch, t_comm_pattern_cdescr, &
       & ragnarok_sync_patch_array_r3_sync_c, &
       & t_process_info
  USE mo_communication, ONLY: t_comm_pattern,  exchange_data
  USE mo_communication_types, ONLY: t_comm_pattern_descr
  IMPLICIT NONE
  PRIVATE
  PUBLIC :: init_ragnarok_bridge

  CHARACTER(len=*), PARAMETER :: module_name = 'mo_ragnarok_bridge'
  LOGICAL, PRIVATE :: is_initialized = .FALSE.
CONTAINS

  SUBROUTINE init_ragnarok_bridge()
    CHARACTER(len=*), PARAMETER :: context = module_name //'::init_ragnarok_bridge'
    IF (is_initialized) RETURN
    CALL init_ragnarok_support( t_f2c_ftable( &
         & get_domain_info = c_funloc(get_domain_info), &
         & get_patch_info = c_funloc(get_patch_info), &
         & get_mo_model_domain_p_patch_descr = c_funloc(get_mo_model_domain_p_patch_descr), &
         & get_comm_patch = c_funloc(get_comm_patch), &
         & f2c_message = c_funloc(f2c_message), &
         & f2c_finish = c_funloc(f2c_finish), &
         & f2c_exchange_data_r3d = c_funloc(f2c_exchange_data_r3d), &
         & get_process_info = c_FUNLOC(get_process_info) &
         & ))
    CALL message(context,'ragnarok_bridge is initialized.')
    is_initialized = .TRUE.
#ifdef DEBUG_RAGNAROK_BRIDGE
    CALL test_ragnarok_sync_patch_array_r3_sync_c()
#endif
  END SUBROUTINE init_ragnarok_bridge

  FUNCTION get_process_info() RESULT(process_info) BIND(c)
    USE mo_mpi, ONLY: my_process_is_mpi_parallel
    TYPE(t_process_info) :: process_info
    process_info = t_process_info(is_mpi_parallel = my_process_is_mpi_parallel())
  END FUNCTION get_process_info

  SUBROUTINE f2c_exchange_data_r3d(pat_descr, lacc, recv, recv_shape) BIND(c)
    ! note: we do not implement the full interface (yet)
    TYPE(t_comm_pattern_cdescr), VALUE :: pat_descr
    LOGICAL(c_bool), VALUE :: lacc ! If true, use openacc
    INTEGER(c_int), INTENT(in) :: recv_shape(3)
    REAL(c_double), INTENT(INOUT) :: recv(recv_shape(1),recv_shape(2),recv_shape(3))

    CALL exchange_data(get_comm_pattern(pat_descr), LOGICAL(lacc), recv)

  END SUBROUTINE f2c_exchange_data_r3d

#ifdef DEBUG_RAGNAROK_BRIDGE
  SUBROUTINE test_ragnarok_sync_patch_array_r3_sync_c()
    USE mo_sync, ONLY: sync_patch_array, SYNC_C
    CHARACTER(len=*), PARAMETER :: context = module_name //'::test_ragnarok_sync_patch_array_r3_sync_c'

    INTEGER :: pid
    REAL(wp), ALLOCATABLE :: arr(:,:,:), ref(:,:,:)
    TYPE(t_patch), POINTER :: patch
    INTEGER :: ia, ib, k, na, p
    pid = LBOUND(p_patch,1)
    patch => p_patch(pid)
    ALLOCATE(ref(nproma, patch%nlev, patch%nblks_c))
    p = (patch%rank+1) * 10000
    ref = -REAL(p,wp)
    DO ib = 1, patch%nblks_c
      na = MERGE(nproma, patch%npromz_c, ib < patch%nblks_c)
      DO k = 1, patch%nlev
        DO ia = 1, na
          p = p + 1
          ref(ia,k,ib) = REAL(p,wp)
        ENDDO
      ENDDO
    ENDDO
    arr = ref
    CALL sync_patch_array(SYNC_C, patch, ref)
    IF (ALL(arr == ref)) CALL message(context,'Note: test not significant')
    CALL ragnarok_sync_patch_array_r3_sync_c(pid, arr,[nproma, patch%nlev, patch%nblks_c])
    IF (ALL(arr == ref)) THEN
      CALL message(context,'Test passed.')
    ELSE
      CALL finish(context,'Test failed')
    ENDIF
  END SUBROUTINE test_ragnarok_sync_patch_array_r3_sync_c
#endif

  SUBROUTINE get_domain_info(dom_info) BIND(c)
    CHARACTER(len=*), PARAMETER :: context = module_name //'::get_domain_info'
    TYPE(t_dom_info), INTENT(out) :: dom_info
    dom_info%nproma = nproma
    IF (ALLOCATED(p_patch)) THEN
      dom_info%id_min = LBOUND(p_patch,1)
      dom_info%id_max = UBOUND(p_patch,1)
    ELSE
      CALL finish(context,'p_patch not allocated')
    ENDIF
  END SUBROUTINE get_domain_info

  SUBROUTINE get_patch_info(icon_patch, patch_info) BIND(c)
    TYPE(t_f2c_patch_descr), VALUE :: icon_patch
    TYPE(t_patch_info), INTENT(out) :: patch_info
    TYPE(t_patch), POINTER :: p
    CALL c_f_POINTER(icon_patch%cptr, p)
    patch_info = t_patch_info( &
         & id = p%id, &
         & nlev = p%nlev, &
         & nblks_c = p%nblks_c, &
         & nblks_e = p%nblks_e, &
         & nblks_v = p%nblks_v &
         & )
  END SUBROUTINE get_patch_info

  SUBROUTINE get_comm_patch(icon_patch, comm_patch) BIND(c)
    TYPE(t_f2c_patch_descr), VALUE, INTENT(in) :: icon_patch
    TYPE(t_comm_patch), INTENT(out) :: comm_patch
    TYPE(t_patch), POINTER :: patch
    CALL c_f_POINTER(icon_patch%cptr, patch)
    comm_patch = t_comm_patch( &
         & comm_pat_c = t_comm_pattern_cdescr(c_LOC(patch%comm_pat_c%descr)), &
         & comm_pat_e = t_comm_pattern_cdescr(c_LOC(patch%comm_pat_e%descr)), &
         & comm_pat_v = t_comm_pattern_cdescr(c_LOC(patch%comm_pat_v%descr)), &
         & comm_pat_c1 = t_comm_pattern_cdescr(c_LOC(patch%comm_pat_c1%descr)) )
  END SUBROUTINE get_comm_patch

  FUNCTION get_comm_pattern(cdescr) RESULT(pat_ptr)
    CHARACTER(len=*), PARAMETER :: context = module_name //'::get_comm_pattern'
    TYPE(t_comm_pattern_cdescr), INTENT(in) :: cdescr
    CLASS(t_comm_pattern), POINTER :: pat_ptr
    TYPE(t_comm_pattern_descr), pointer :: descr_ptr
    CALL c_f_POINTER(cdescr%cptr, descr_ptr)
    SELECT TYPE (ptr => descr_ptr%ptr)
    CLASS is (t_comm_pattern)
      pat_ptr => ptr
    CLASS DEFAULT
      CALL finish(context,"cannot resolve descr_ptr%ptr")
    END SELECT
  END FUNCTION get_comm_pattern

  FUNCTION get_mo_model_domain_p_patch_descr(id) RESULT(f2c_patch_descr) BIND(c)
    CHARACTER(len=*), PARAMETER :: context = module_name //'::get_mo_model_domain_p_patch_descr'
    INTEGER(c_int), VALUE, INTENT(in) :: id
    TYPE(t_f2c_patch_descr) :: f2c_patch_descr
    f2c_patch_descr%cptr = c_null_ptr
    IF (.NOT. ALLOCATED(p_patch)) CALL finish(context,'p_patch not allocated')
    IF (id >= LBOUND(p_patch,1) .AND. id <= UBOUND(p_patch,1)) THEN
      IF (p_patch(id)%id /= id) CALL finish(context,'unexpected patch%id')
      f2c_patch_descr%cptr = c_LOC(p_patch(id))
    ENDIF
  END FUNCTION get_mo_model_domain_p_patch_descr

  SUBROUTINE f2c_message(cname, cname_len, ctext, ctext_len) BIND(c)
    CHARACTER(c_char), DIMENSION(*), INTENT(in) :: cname, ctext
    INTEGER(c_int), VALUE :: cname_len, ctext_len
    INTEGER :: my_fname_len, my_ftext_len
    my_fname_len = MIN(cname_len, filename_max)
    my_ftext_len = MIN(ctext_len, filename_max)
    CALL my_msg()
  CONTAINS
    SUBROUTINE my_msg
      CHARACTER(len=my_fname_len) :: my_fname
      CHARACTER(len=my_ftext_len) :: my_ftext
      CALL aux_copy_cstring(cname, my_fname, my_fname_len)
      CALL aux_copy_cstring(ctext, my_ftext, my_ftext_len)
      CALL message(my_fname, my_ftext)
    END SUBROUTINE my_msg
  END SUBROUTINE f2c_message

  SUBROUTINE f2c_finish(cname, cname_len, ctext, ctext_len) BIND(c)
    CHARACTER(c_char), DIMENSION(*), INTENT(in) :: cname, ctext
    INTEGER(c_int), VALUE :: cname_len, ctext_len
    INTEGER :: my_fname_len, my_ftext_len
    my_fname_len = MIN(cname_len, filename_max)
    my_ftext_len = MIN(ctext_len, filename_max)
    CALL my_fin()
  CONTAINS
    SUBROUTINE my_fin
      CHARACTER(len=my_fname_len) :: my_fname
      CHARACTER(len=my_ftext_len) :: my_ftext
      CALL aux_copy_cstring(cname, my_fname, my_fname_len)
      IF (my_ftext_len > 0) THEN
        CALL aux_copy_cstring(ctext, my_ftext, my_ftext_len)
        CALL finish(my_fname, my_ftext)
      ELSE
        CALL finish(my_fname)
      ENDIF
    END SUBROUTINE my_fin
  END SUBROUTINE f2c_finish

  SUBROUTINE aux_copy_cstring(cstr, fstr, n)
    INTEGER, INTENT(in) :: n
    CHARACTER(c_char), DIMENSION(n), INTENT(in) :: cstr
    CHARACTER(len=n), INTENT(out) :: fstr
    INTEGER :: i
    DO i = 1, n
      fstr(i:i) = cstr(i)
    ENDDO
  END SUBROUTINE aux_copy_cstring

END MODULE mo_ragnarok_bridge
#endif /* __NO_RAGNAROK__ */
