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
/// @brief partially implements mo_exception.f90 functionlity
///
//----------------------------

#include "icon_exception.hpp"

#include <cassert>

#include "f2c_support.hpp"

namespace icon_exception {

namespace f2c = f2c_support;

namespace {

bool is_initialized = false;

}  // namespace

void message(const std::string& name, const std::string& text) {
  f2c::get_fun_table().message(name.c_str(), name.length(), text.c_str(), text.length());
}

void finish(const std::string& name, const std::string& text) {
  f2c::get_fun_table().finish(name.c_str(), name.length(), text.c_str(), text.length());
}

void finish(const std::string& name) { f2c::get_fun_table().finish(name.c_str(), name.length(), "", 0); }

void init() {
  if (is_initialized) return;
  assert(f2c::is_initialized());
  is_initialized = true;
}

}  // namespace icon_exception
