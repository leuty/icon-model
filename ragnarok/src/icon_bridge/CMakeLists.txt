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

set(kokkos_dependents
    # cmake-format: sort
    icon_bridge.cpp
    icon_sync.cpp
    model_domain.cpp
    ragnarok.cpp
)

add_library(
  icon_bridge OBJECT
  # cmake-format: sort
  ${kokkos_dependents}
  f2c_support.cpp
  f2c_support.hpp
  icon_bridge.hpp
  icon_exception.cpp
  icon_exception.hpp
  icon_sync.hpp
  icon_sync.ipp
  mo_ragnarok.f90
  mo_ragnarok_support.f90
  model_domain.hpp
  ragnarok.hpp
)

set_source_files_properties(
  ${kokkos_dependents} PROPERTIES LANGUAGE ${Kokkos_COMPILE_LANGUAGE}
)

set(Fortran_MODULE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/mod")

set_target_properties(
  icon_bridge PROPERTIES Fortran_MODULE_DIRECTORY "${Fortran_MODULE_DIRECTORY}"
)

if(BUILD_SHARED_LIBS)
  set_target_properties(icon_bridge PROPERTIES POSITION_INDEPENDENT_CODE ON)
endif()

target_include_directories(
  icon_bridge PUBLIC $<BUILD_INTERFACE:${Fortran_MODULE_DIRECTORY}>
)

target_link_libraries(icon_bridge PUBLIC Kokkos::kokkos)
