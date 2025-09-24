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
/// @brief This file contains the implementation for
/// accessing some of ICON's Fortran functionality
///
//----------------------------

#include "icon_bridge.hpp"

#include <cassert>

#include "f2c_support.hpp"
#include "model_domain.hpp"
#include "ragnarok.hpp"

namespace icon_bridge {

extern "C" void init_ragnarok_support(f2c_support::FunTable* fun_tab) {
  assert(ragnarok::is_initialized());
  f2c_support::init(fun_tab);
  model_domain::init();
}

}  // namespace icon_bridge
