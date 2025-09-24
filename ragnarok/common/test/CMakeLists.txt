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

set(kokkos_dependents main.cpp types.cpp)

add_executable(ragnarok_test ${kokkos_dependents})

set_source_files_properties(
  ${kokkos_dependents} PROPERTIES LANGUAGE ${Kokkos_COMPILE_LANGUAGE}
)

target_link_libraries(
  ragnarok_test PRIVATE ragnarok_common_headers GTest::gtest Kokkos::kokkos
)

# Delay test discovery until runtime (needed for cross-compilation):
gtest_discover_tests(ragnarok_test DISCOVERY_MODE PRE_TEST)
