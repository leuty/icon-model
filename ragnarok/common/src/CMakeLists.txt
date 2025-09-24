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

add_library(ragnarok_common_headers INTERFACE)

target_include_directories(
  ragnarok_common_headers
  INTERFACE
    $<BUILD_INTERFACE:$<$<NOT:$<COMPILE_LANGUAGE:Fortran>>:${CMAKE_CURRENT_SOURCE_DIR}>>
)

target_link_libraries(ragnarok_common_headers INTERFACE Kokkos::kokkos)
