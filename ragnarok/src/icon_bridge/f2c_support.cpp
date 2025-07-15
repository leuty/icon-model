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
/// @brief implements support for Fortran <-> C access
///
//----------------------------

#include "f2c_support.hpp"

#include <cassert>
#include <sstream>
#include <string>

namespace f2c_support {

// init static data of Internal class:
bool Internal::init_state;
FunTable Internal::fun_table;
DomainInfo Internal::dom_info;

namespace {

#ifdef DEBUG_RAGNAROK_BRIDGE
void show_debug_info() {
  const std::string context = "icon_bridge::show_debug_info";
  assert(is_initialized());
  auto &dom_info  = get_domain_info();
  auto &fun_table = get_fun_table();
  {
    std::stringstream buffer;

    buffer << "dom_info: "
           << "id_min = " << dom_info.id_min << ", "
           << "id_max = " << dom_info.id_max << ", "
           << "nproma = " << dom_info.nproma;
    auto text = buffer.str();
    fun_table.message(context.c_str(), context.size(), text.c_str(), text.size());
  }

  int id           = dom_info.id_min;
  auto patch_descr = fun_table.get_mo_model_domain_p_patch_descr(id);
  {
    PatchInfo pinfo;
    std::stringstream buffer;
    fun_table.get_patch_info(patch_descr, &pinfo);
    buffer << "patch_info: "
           << "id = " << pinfo.id << ", "
           << "nlev = " << pinfo.nlev << ", "
           << "nblks_c = " << pinfo.nblks_c << ", "
           << "nblks_e = " << pinfo.nblks_e << ", "
           << "nblks_v = " << pinfo.nblks_v << ", ";
    auto text = buffer.str();
    fun_table.message(context.c_str(), context.size(), text.c_str(), text.size());
  }
}
#endif

}  // namespace

void init(const FunTable *funtab) {
  auto &init_state = Internal::init_state;
  if (init_state) return;
  init_state      = true;
  // copy funtab:
  auto &fun_table = Internal::fun_table;
  fun_table       = *funtab;
  // provide dom_info:
  auto &dom_info  = Internal::dom_info;
  fun_table.get_domain_info(&dom_info);
  if (dom_info.id_max < dom_info.id_min) {
    const std::string context = "init_f2c_support";
    const std::string text    = "no domain available";
    fun_table.finish(context.c_str(), context.size(), text.c_str(), text.size());
  }

#ifdef DEBUG_RAGNAROK_BRIDGE
  show_debug_info();  // for debug only
#endif
}

}  // namespace f2c_support
