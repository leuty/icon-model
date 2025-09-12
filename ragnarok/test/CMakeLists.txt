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
set(kokkos_dependents main.cpp)
add_executable(ragnarok_test ${kokkos_dependents})

set_source_files_properties(
  ${kokkos_dependents} PROPERTIES LANGUAGE ${Kokkos_COMPILE_LANGUAGE}
)

target_link_libraries(ragnarok_test PUBLIC GTest::gtest Kokkos::kokkos)

# tests are built standalone:
set_target_properties(ragnarok_test PROPERTIES LINKER_LANGUAGE CXX)
set_target_properties(ragnarok_test PROPERTIES CXX_STANDARD 20)

# delay test discovery until runtime; needed for cross-compilation
gtest_discover_tests(ragnarok_test DISCOVERY_MODE PRE_TEST)
