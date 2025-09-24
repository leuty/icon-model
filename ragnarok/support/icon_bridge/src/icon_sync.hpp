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

#ifndef RAGNAROK_ICON_BRIDGE_ICON_SYNC_H_
#define RAGNAROK_ICON_BRIDGE_ICON_SYNC_H_

#include "f2c_support.hpp"

namespace icon_sync {

void sync_patch_array(int typ, f2c_support::PatchDescr patch, double arr[], int shape[3]);

struct SyncC {
  static constexpr int value = 1;
};

struct SyncE {
  static constexpr int value = 2;
};

struct SyncV {
  static constexpr int value = 3;
};

struct SyncC1 {
  static constexpr int value = 4;
};

constexpr SyncC sync_c;
constexpr SyncE sync_e;
constexpr SyncV sync_v;
constexpr SyncC1 sync_c1;

inline const f2c_support::ProcessInfo& get_process_info() {
  static const f2c_support::ProcessInfo process_info = f2c_support::get_fun_table().get_process_info();
  return process_info;
}

}  // namespace icon_sync

#include "icon_sync.ipp"

#endif
