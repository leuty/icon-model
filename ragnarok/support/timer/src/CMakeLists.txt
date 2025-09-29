# ICON
#
# ---------------------------------------------------------------
# Copyright (C) 2004-2025, DWD, MPI-M, DKRZ, KIT, ETH, MeteoSwiss
# Contact information: icon-model.org
#
# See AUTHORS.TXT for a list of authors
# See LICENSES/ for license information
# SPDX-License-Identifier: BSD-3-Clause
# ---------------------------------------------------------------

if(RGK_ENABLE_STANDALONE)
  add_library(timer INTERFACE)
  target_include_directories(
    timer
    INTERFACE
      $<BUILD_INTERFACE:$<$<NOT:$<COMPILE_LANGUAGE:Fortran>>:${CMAKE_CURRENT_SOURCE_DIR}>>
  )
  target_link_libraries(timer INTERFACE Kokkos::kokkos)
else()
  add_library(timer OBJECT icon_timer.hpp icon_timer.cpp mo_ragnarok_timer.f90)

  set(Fortran_MODULE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/mod")

  set_target_properties(
    timer PROPERTIES Fortran_MODULE_DIRECTORY "${Fortran_MODULE_DIRECTORY}"
  )

  if(BUILD_SHARED_LIBS)
    set_target_properties(timer PROPERTIES POSITION_INDEPENDENT_CODE ON)
  endif()

  target_include_directories(
    timer
    PUBLIC
      $<BUILD_INTERFACE:$<$<NOT:$<COMPILE_LANGUAGE:Fortran>>:${CMAKE_CURRENT_SOURCE_DIR}>>
      $<BUILD_INTERFACE:$<$<COMPILE_LANGUAGE:Fortran>:${Fortran_MODULE_DIRECTORY}>>
  )

  target_link_libraries(timer PUBLIC icon_bridge)
endif()
