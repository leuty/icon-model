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

add_library(ragnarok_support OBJECT)

add_subdirectory(icon_bridge)

target_link_libraries(ragnarok_support INTERFACE icon_bridge)
target_sources(ragnarok_support PUBLIC $<TARGET_OBJECTS:icon_bridge>)
