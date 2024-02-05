! Set of routines shared by various coupling related modules
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

MODULE mo_coupling_utils

  USE mo_kind,            ONLY: wp
  USE mo_exception,       ONLY: message, warning, finish
  USE mo_parallel_config, ONLY: nproma
  USE mo_run_config,      ONLY: ltimer
  USE mo_timer,           ONLY: timer_start, timer_stop, timer_coupling_put, &
    &                           timer_coupling_get, timer_coupling_1stget
#ifdef YAC_coupling
  USE mo_yac_finterface,  ONLY: yac_fdef_field, yac_fdef_field_mask, &
    &                           yac_dble_ptr, yac_fput, yac_fget, &
    &                           yac_fget_field_collection_size, &
    &                           YAC_TIME_UNIT_ISO_FORMAT, &
    &                           YAC_ACTION_COUPLING, &
    &                           YAC_ACTION_PUT_FOR_RESTART, &
    &                           YAC_ACTION_GET_FOR_RESTART, &
    &                           YAC_ACTION_OUT_OF_BOUND
#endif
  USE mo_coupling,       ONLY: lyac_very_1st_get

  IMPLICIT NONE

  PRIVATE

  PUBLIC :: cpl_def_field
  PUBLIC :: cpl_get_field
  PUBLIC :: cpl_get_field_collection_size
  PUBLIC :: cpl_put_field

  CHARACTER(LEN=*), PARAMETER :: modname = 'mo_coupling_utils'

  ! registers a field to the coupler
  INTERFACE cpl_def_field
    MODULE PROCEDURE cpl_def_field_no_mask
    MODULE PROCEDURE cpl_def_field_mask
  END INTERFACE cpl_def_field

  ! receives cell-based field data through the coupler
  INTERFACE cpl_get_field
    MODULE PROCEDURE cpl_get_field_idx_lev_blk
    MODULE PROCEDURE cpl_get_field_idx_blk_collection
    MODULE PROCEDURE cpl_get_field_n_collection
  END INTERFACE cpl_get_field

  ! sends cell-based field data through the coupler
  INTERFACE cpl_put_field
    MODULE PROCEDURE cpl_put_field_idx_blk_collection
  END INTERFACE cpl_put_field

CONTAINS

  ! registers a field to the coupler without a mask
  SUBROUTINE cpl_def_field_no_mask( &
    comp_id, cell_point_id, timestepstring, &
    field_name, collection_size, field_id)

    INTEGER, INTENT(IN) :: comp_id                 ! component id
    INTEGER, INTENT(IN) :: cell_point_id           ! cell coordinate id
    CHARACTER(LEN=*), INTENT(IN) :: timestepstring ! time step of the field
    CHARACTER(LEN=*), INTENT(IN) :: field_name     ! name of the field
    INTEGER, INTENT(IN) :: collection_size         ! number of levels/bundle size
    INTEGER, INTENT(OUT) :: field_id               ! id of the field

#ifdef YAC_coupling
    CALL yac_fdef_field (                           &
      & field_name      = TRIM(field_name),         & !in
      & component_id    = comp_id,                  & !in
      & point_ids       = (/cell_point_id/),        & !in
      & num_pointsets   = 1,                        & !in
      & collection_size = collection_size,          & !in
      & timestep        = timestepstring,           & !in
      & time_unit       = YAC_TIME_UNIT_ISO_FORMAT, & !in
      & field_id        = field_id )                  !out
#endif

  END SUBROUTINE cpl_def_field_no_mask

  ! registers a field to the coupler with a mask
  SUBROUTINE cpl_def_field_mask( &
    comp_id, cell_point_id, cell_mask_id, timestepstring, &
    field_name, collection_size, field_id)

    INTEGER, INTENT(IN) :: comp_id                 ! component id
    INTEGER, INTENT(IN) :: cell_point_id           ! cell coordinate id
    INTEGER, INTENT(IN) :: cell_mask_id            ! cell mask id
    CHARACTER(LEN=*), INTENT(IN) :: timestepstring ! time step of the field
    CHARACTER(LEN=*), INTENT(IN) :: field_name     ! name of the field
    INTEGER, INTENT(IN) :: collection_size         ! number of levels/bundle size
    INTEGER, INTENT(OUT) :: field_id               ! id of the field

#ifdef YAC_coupling
    CALL yac_fdef_field_mask (                      &
      & field_name      = TRIM(field_name),         & !in
      & component_id    = comp_id,                  & !in
      & point_ids       = (/cell_point_id/),        & !in
      & mask_ids        = (/cell_mask_id/),         & !in
      & num_pointsets   = 1,                        & !in
      & collection_size = collection_size,          & !in
      & timestep        = timestepstring,           & !in
      & time_unit       = YAC_TIME_UNIT_ISO_FORMAT, & !in
      & field_id        = field_id )                  !out
#endif

  END SUBROUTINE cpl_def_field_mask

  ! gets the collection size of a field
  ! (only works after the respective field has been definied and
  !  its information has been distributed among all processes either
  !  by a call to yac_fsync_def or yac_fenddef)
  FUNCTION cpl_get_field_collection_size( &
    caller, comp_name, grid_name, field_name)

    CHARACTER(LEN=*), INTENT(IN) :: comp_name  ! name of the component
    CHARACTER(LEN=*), INTENT(IN) :: grid_name  ! name of the grid
    CHARACTER(LEN=*), INTENT(IN) :: field_name ! name of the field
    CHARACTER(LEN=*), INTENT(IN) :: caller     ! name of the calling routine (for debugging)

    INTEGER :: cpl_get_field_collection_size

#ifndef YAC_coupling
    CALL finish( &
      TRIM(caller) // ':cpl_get_field_collection_size', &
      'built without coupling support.')
#else

    cpl_get_field_collection_size = &
      yac_fget_field_collection_size(comp_name, grid_name, field_name)

! YAC_coupling
#endif

  END FUNCTION cpl_get_field_collection_size

#ifdef YAC_coupling

  ! basic routine for sending a field through the coupler
  SUBROUTINE put( &
    caller, field_id, field_name, field, write_restart)

    CHARACTER(LEN=*), INTENT(in) :: caller
    INTEGER, INTENT(in) :: field_id
    CHARACTER(LEN=*), INTENT(in) :: field_name
    TYPE(yac_dble_ptr), INTENT(in) :: field(:, :)
    LOGICAL, OPTIONAL, INTENT(out) :: write_restart

    INTEGER :: num_pointsets, collection_size
    INTEGER :: info, ierr

    num_pointsets = SIZE(field, 1)
    collection_size = SIZE(field, 2)

    IF (ltimer) CALL timer_start(timer_coupling_put)

    CALL yac_fput( &
      field_id, num_pointsets, collection_size, field, info, ierr)

    IF (ltimer) CALL timer_stop(timer_coupling_put)

    IF ( info == YAC_ACTION_PUT_FOR_RESTART ) THEN
      CALL message( &
        caller // ':put', &
        'YAC says it is put for restart - ' // TRIM(field_name))
    ENDIF
    IF ( info == YAC_ACTION_OUT_OF_BOUND ) THEN
      CALL warning( &
        caller // ':put', &
        'YAC says put called after end of run - ' // TRIM(field_name))
    ENDIF

    IF (PRESENT(write_restart)) &
      write_restart = (info == YAC_ACTION_PUT_FOR_RESTART)

  END SUBROUTINE put

! YAC_coupling
#endif

  ! sends one or more fields through the coupler
  ! remark:
  !   * field data has the dimensions (nidx,nblk)
  !     with nidx * nblk >= num_points
  !   * number of provided fields has to match the collection size
  !     associated with the provided field id
  SUBROUTINE cpl_put_field_idx_blk_collection( &
    caller, field_collection_id, field_collection_name, num_points, &
    field_1, field_2, field_3, field_4, write_restart)

    CHARACTER(LEN=*), INTENT(in) :: caller                            ! name of the calling routine (for debugging)
    INTEGER, INTENT(in) :: field_collection_id                        ! field id of the field collection
    CHARACTER(LEN=*), INTENT(in) :: field_collection_name             ! name of the field collection (for debugging)
    INTEGER, INTENT(in) :: num_points                                 ! number of points in the field data (e.g. number of cells)
    REAL(wp), CONTIGUOUS, TARGET, INTENT(IN):: field_1(:,:)           ! field data
    REAL(wp), CONTIGUOUS, TARGET, OPTIONAL, INTENT(IN):: field_2(:,:) ! optional field data
    REAL(wp), CONTIGUOUS, TARGET, OPTIONAL, INTENT(IN):: field_3(:,:) ! optional field data
    REAL(wp), CONTIGUOUS, TARGET, OPTIONAL, INTENT(IN):: field_4(:,:) ! optional field data
    LOGICAL, OPTIONAL, INTENT(out) :: write_restart                   ! .TRUE. if it was the last valid put

#ifndef YAC_coupling
    CALL finish( &
      TRIM(caller) // ':cpl_put_field_idx_blk_collection', &
      'built without coupling support.')
#else

    INTEGER :: collection_size

    TYPE(yac_dble_ptr) :: send_field_collection(1, 4)

    collection_size = 1
    send_field_collection(1,collection_size)%p(1:num_points) => &
      field_1(:,:)
    IF (PRESENT(field_2)) THEN
      collection_size = collection_size + 1
      send_field_collection(1,collection_size)%p(1:num_points) => &
        field_2(:,:)
    END IF
    IF (PRESENT(field_3)) THEN
      collection_size = collection_size + 1
      send_field_collection(1,collection_size)%p(1:num_points) => &
        field_3(:,:)
    END IF
    IF (PRESENT(field_4)) THEN
      collection_size = collection_size + 1
      send_field_collection(1,collection_size)%p(1:num_points) => &
        field_4(:,:)
    END IF

    CALL put( &
      caller // ':cpl_put_field_idx_blk_collection', field_collection_id, &
      field_collection_name, send_field_collection(:,1:collection_size), &
      write_restart)

! YAC_coupling
#endif

  END SUBROUTINE cpl_put_field_idx_blk_collection

#ifdef YAC_coupling

  ! basic routine for receiving a field through the coupler
  SUBROUTINE get( &
    caller, field_id, field_name, field, &
    received_data, write_restart)

    CHARACTER(LEN=*), INTENT(in) :: caller
    INTEGER, INTENT(in) :: field_id
    CHARACTER(LEN=*), INTENT(in) :: field_name
    TYPE(yac_dble_ptr), INTENT(inout) :: field(:)
    LOGICAL, OPTIONAL, INTENT(out) :: received_data
    LOGICAL, OPTIONAL, INTENT(out) :: write_restart

    INTEGER :: collection_size
    INTEGER :: get_timer, info, ierr

    collection_size = SIZE(field, 1)

    IF (ltimer) THEN
      get_timer = &
        MERGE(timer_coupling_1stget, timer_coupling_get, lyac_very_1st_get)
      CALL timer_start(get_timer)
      lyac_very_1st_get = .FALSE.
    END IF

    CALL yac_fget(field_id, collection_size, field, info, ierr)

    IF (ltimer) CALL timer_stop(get_timer)

    IF ( info == YAC_ACTION_GET_FOR_RESTART ) THEN
      CALL message( &
        caller // ':get', &
        'YAC says it is get for restart - ' // TRIM(field_name))
    ENDIF
    IF ( info == YAC_ACTION_OUT_OF_BOUND ) THEN
      CALL warning( &
        caller // ':get', &
        'YAC says get called after end of run - ' // TRIM(field_name))
    ENDIF

    IF (PRESENT(received_data)) &
      received_data = &
        (info == YAC_ACTION_COUPLING) .OR. (info == YAC_ACTION_GET_FOR_RESTART)
    IF (PRESENT(write_restart)) &
      write_restart = (info == YAC_ACTION_GET_FOR_RESTART)

  END SUBROUTINE get

! YAC_coupling
#endif

  ! receives one or more fields through the coupler
  ! remark:
  !   * field data has the dimensions (num points, collection size)
  !   * all field data is provided in a single contiguous buffer
  !   * collection size has to match the one associated with the provided
  !     field id
  !   * depending on the field and coupling timestep, no data my actually
  !     be received by this call
  SUBROUTINE cpl_get_field_n_collection( &
    caller, field_collection_id, field_collection_name, &
    field_collection, received_data, write_restart)

    CHARACTER(LEN=*), INTENT(in) :: caller                ! name of the calling routine (for debugging)
    INTEGER, INTENT(in) :: field_collection_id            ! field id of the field collection
    CHARACTER(LEN=*), INTENT(in) :: field_collection_name ! name of the field collection (for debugging)
    REAL(wp), CONTIGUOUS, TARGET, INTENT(INOUT):: &
      field_collection(:,:)                               ! field data
    LOGICAL, OPTIONAL, INTENT(out) :: received_data       ! .TRUE. if data was received by this call
    LOGICAL, OPTIONAL, INTENT(out) :: write_restart       ! .TRUE. if it was the last valid get

#ifndef YAC_coupling
    CALL finish( &
      TRIM(caller) // ':cpl_get_field_n_collection', &
      'built without coupling support.')
#else

    INTEGER :: num_points, collection_size
    INTEGER :: i

    TYPE(yac_dble_ptr) :: recv_field_collection(SIZE(field_collection,2))

    num_points = SIZE(field_collection, 1)
    collection_size = SIZE(field_collection, 2)

    DO i = 1, collection_size
      recv_field_collection(i)%p(1:num_points) => field_collection(:,i)
    END DO

    CALL get( &
      caller // ':cpl_get_field_n_collection', field_collection_id, &
      field_collection_name, recv_field_collection, received_data, &
      write_restart)

! YAC_coupling
#endif

  END SUBROUTINE cpl_get_field_n_collection

  ! receives one or more fields through the coupler
  ! remark:
  !   * field data has the dimensions (nidx,nblk)
  !     with nidx * nblk >= num_points
  !   * number of provided fields has to match the collection size
  !     associated with the provided field id
  !   * depending on the field and coupling timestep, no data my actually
  !     be received by this call
  SUBROUTINE cpl_get_field_idx_blk_collection( &
    caller, field_collection_id, field_collection_name, num_points, &
    field_1, field_2, field_3, field_4, received_data, write_restart)

    CHARACTER(LEN=*), INTENT(in) :: caller                               ! name of the calling routine (for debugging)
    INTEGER, INTENT(in) :: field_collection_id                           ! field id of the field collection
    CHARACTER(LEN=*), INTENT(in) :: field_collection_name                ! name of the field collection (for debugging)
    INTEGER, INTENT(in) :: num_points                                    ! number of points in the field data (e.g. number of cells)
    REAL(wp), CONTIGUOUS, TARGET, INTENT(INOUT):: field_1(:,:)           ! field data
    REAL(wp), CONTIGUOUS, TARGET, OPTIONAL, INTENT(INOUT):: field_2(:,:) ! optional field data
    REAL(wp), CONTIGUOUS, TARGET, OPTIONAL, INTENT(INOUT):: field_3(:,:) ! optional field data
    REAL(wp), CONTIGUOUS, TARGET, OPTIONAL, INTENT(INOUT):: field_4(:,:) ! optional field data
    LOGICAL, OPTIONAL, INTENT(out) :: received_data                      ! .TRUE. if data was received by this call
    LOGICAL, OPTIONAL, INTENT(out) :: write_restart                      ! .TRUE. if it was the last valid get

#ifndef YAC_coupling
    CALL finish( &
      TRIM(caller) // ':cpl_get_field_idx_blk_collection', &
      'built without coupling support.')
#else

    INTEGER :: collection_size

    TYPE(yac_dble_ptr) :: recv_field_collection(4)

    collection_size = 1
    recv_field_collection(collection_size)%p(1:num_points) => &
      field_1(:,:)
    IF (PRESENT(field_2)) THEN
      collection_size = collection_size + 1
      recv_field_collection(collection_size)%p(1:num_points) => &
        field_2(:,:)
    END IF
    IF (PRESENT(field_3)) THEN
      collection_size = collection_size + 1
      recv_field_collection(collection_size)%p(1:num_points) => &
        field_3(:,:)
    END IF
    IF (PRESENT(field_4)) THEN
      collection_size = collection_size + 1
      recv_field_collection(collection_size)%p(1:num_points) => &
        field_4(:,:)
    END IF

    CALL get( &
      caller // ':cpl_get_field_idx_blk_collection', field_collection_id, &
      field_collection_name, recv_field_collection(1:collection_size), &
      received_data, write_restart)

! YAC_coupling
#endif

  END SUBROUTINE cpl_get_field_idx_blk_collection

  ! receives multiple levels of a single field through the coupler
  ! remark:
  !   * field data has the dimensions (nidx,nlev,nblk)
  !     with nidx * nblk >= num_points
  !   * receive buffer has the dimensions (num points, nlev_)
  !     with nlev_ >= nlev
  !   * number of levels match the collection size associated with
  !     the provided field id
  !   * depending on the field and coupling timestep, no data my actually
  !     be received by this call
  SUBROUTINE cpl_get_field_idx_lev_blk( &
    caller, field_id, field_name, field, recv_buf, scale_factor, &
    received_data, write_restart)

    CHARACTER(LEN=*), INTENT(in) :: caller          ! name of the calling routine (for debugging)
    INTEGER, INTENT(in) :: field_id                 ! field id of the field
    CHARACTER(LEN=*), INTENT(in) :: field_name      ! name of the field (for debugging)
    REAL(wp), INTENT(inout) :: field(:,:,:)         ! field data
    REAL(wp), CONTIGUOUS, TARGET, INTENT(inout) :: &
      recv_buf(:,:)                                 ! contiguous temporary buffer used by this routine
    REAL(wp), OPTIONAL, INTENT(in) :: scale_factor  ! optional: multiply whole field by this factor
                                                    ! (only if data was received)
    LOGICAL, OPTIONAL, INTENT(out) :: received_data ! .TRUE. if data was received by this call
    LOGICAL, OPTIONAL, INTENT(out) :: write_restart ! .TRUE. if it was the last valid get

#ifndef YAC_coupling
    CALL finish( &
      TRIM(caller) // ':cpl_get_field_idx_lev_blk', &
      'built without coupling support.')
#else

    INTEGER :: nidx, nlev, nblk, num_points
    LOGICAL :: coupling
    INTEGER :: i, j, k

    TYPE(yac_dble_ptr) :: recv_field(SIZE(field, 2))

    nidx = SIZE(field, 1)
    nlev = SIZE(field, 2)
    nblk = SIZE(field, 3)
    num_points = SIZE(recv_buf, 1)

    IF (nlev > SIZE(recv_buf, 2)) &
      CALL finish( &
        TRIM(caller) // ':cpl_get_field_idx_lev_blk', &
        'insufficient recv_buf size')

    ! MoHa:
    !   remarks:
    !     * Since independent fields may use different field mask
    !       cells written by yac_fget may be different as well. Therefore
    !       it is easier if the caller provides the receive buffer. Otherwise
    !       we would have to reinitialise it every time.

    DO i = 1, nlev
      recv_field(i)%p => recv_buf(:,i)
    END DO

    CALL get( &
      caller // ':cpl_get_field_idx_lev_blk', field_id, field_name, recv_field, &
      coupling, write_restart)

    ! if data was received
    IF (coupling) THEN

      ! unpack data
      IF (PRESENT(scale_factor)) THEN
        DO i = 1, nblk
          DO j = 1, nlev
            DO k = 1, nidx
              IF ((i-1) * nidx + k > num_points) CYCLE
              field(k,j,i) = scale_factor * recv_buf((i-1)*nidx+k,j)
            END DO
          END DO
        END DO
      ELSE
        DO i = 1, nblk
          DO j = 1, nlev
            DO k = 1, nidx
              IF ((i-1) * nidx + k > num_points) CYCLE
              field(k,j,i) = recv_buf((i-1)*nidx+k,j)
            END DO
          END DO
        END DO
      END IF

    END IF

    IF (PRESENT(received_data)) received_data = coupling

! YAC_coupling
#endif

  END SUBROUTINE cpl_get_field_idx_lev_blk

END MODULE mo_coupling_utils
