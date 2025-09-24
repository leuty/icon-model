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

#ifndef RAGNAROK_ICON_BRIDGE_MODEL_DOMAIN_H_
#define RAGNAROK_ICON_BRIDGE_MODEL_DOMAIN_H_

#include <Kokkos_Core.hpp>

#include "f2c_support.hpp"
#include "icon_bridge.hpp"

namespace model_domain {

namespace f2c = f2c_support;

struct Patch : public f2c::PatchInfo {
  f2c::CommPatch comm_patch;
  void init(const f2c::PatchDescr f2c_patch_descr);

 private:
  f2c::PatchDescr f2c_descr;
};

void init();

const Patch& get_patch(int dom_id);

}  // namespace model_domain

#endif  // RAGNAROK_ICON_BRIDGE_MODEL_DOMAIN_H_
