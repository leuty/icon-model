# ICON
#
# ---------------------------------------------------------------
# Copyright (C) 2004-2024, DWD, MPI-M, DKRZ, KIT, ETH, MeteoSwiss
# Contact information: icon-model.org
#
# See AUTHORS.TXT for a list of authors
# See LICENSES/ for license information
# SPDX-License-Identifier: BSD-3-Clause
# ---------------------------------------------------------------
macro(register_tolerance_test scheme total_tests)
    add_test(NAME run_${scheme}
        COMMAND microphysics_1mom_driver ${scheme})
  foreach(test_number RANGE 1 ${total_tests})
    add_test(
        NAME ${scheme}_stats_${test_number}
        COMMAND ${Python_EXECUTABLE} ${PROJECT_SOURCE_DIR}/../../externals/probtest/probtest.py stats --no-ensemble  --file-id "NetCDF" "${scheme}_${test_number}.nc" --stats-file-name "${scheme}_${test_number}"
    )
    add_test(
        NAME ${scheme}_check_${test_number}
    COMMAND ${Python_EXECUTABLE} ${PROJECT_SOURCE_DIR}/../../externals/probtest/probtest.py check --input-file-ref "${PROJECT_SOURCE_DIR}/reference/${scheme}_${test_number}_ref" --input-file-cur "${scheme}_${test_number}" --tolerance-file-name "${PROJECT_SOURCE_DIR}/tolerance/${scheme}_${test_number}"
    )
  endforeach()
endmacro()
