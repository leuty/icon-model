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
macro(probtest_target parent_target scheme total_tests )
    add_custom_target(${scheme}_stats)
        foreach(case RANGE 1 ${total_tests})
            set(target_name "${scheme}_${case}")
            
            add_custom_target(${target_name}
                COMMAND ${CMAKE_BINARY_DIR}/create_stats_wrapper.sh ${scheme} ${case}
                WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
                COMMENT "Running probtest_stats_check for ${target_name}"
                DEPENDS ${parent_target}
            )
            
            # Add dependencies to ensure correct order
            add_dependencies(${scheme}_stats ${target_name})
        endforeach()
endmacro()
