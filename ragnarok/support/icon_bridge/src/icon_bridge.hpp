// ICON
//
// ---------------------------------------------------------------
// Copyright (C) 2004-2025, DWD, MPI-M, DKRZ, KIT, ETH, MeteoSwiss
// Contact information: icon-model.org
//
// See AUTHORS.TXT for a list of authors
// See LICENSES/ for license information
// SPDX-License-Identifier: BSD-3-Clause
// ---------------------------------------------------------------

///
/// @file
/// @brief This header file contains the definitions required
/// for the data/procedure exchange with ICON Fortran code
///
//----------------------------

#ifndef RAGNAROK_ICON_BRIDGE_ICON_BRIDGE_H_
#define RAGNAROK_ICON_BRIDGE_ICON_BRIDGE_H_

#include "f2c_support.hpp"

namespace icon_bridge {

extern "C" void init_ragnarok_support(f2c_support::FunTable* ftab);

}  // namespace icon_bridge

#endif /* RAGNAROK_ICON_BRIDGE_ICON_BRIDGE_H_ */
