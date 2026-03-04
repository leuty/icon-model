// ICON
//
// ---------------------------------------------------------------
// Copyright (C) 2004-2026, DWD, MPI-M, DKRZ, KIT, ETH, MeteoSwiss
// Contact information: icon-model.org
//
// See AUTHORS.TXT for a list of authors
// See LICENSES/ for license information
// SPDX-License-Identifier: BSD-3-Clause
// ---------------------------------------------------------------
#ifndef RAGNAROK_STANDALONE_AES_MICROPHYSICS_IO_NETCDF_CLIENT_H_
#define RAGNAROK_STANDALONE_AES_MICROPHYSICS_IO_NETCDF_CLIENT_H_

#include <algorithm>
#include <fstream>
#include <iostream>
#include <map>
#include <netcdf>
#include <string>

namespace io {

const int NC_ERR           = 2;
const std::string BASE_VAR = "zg";

template <typename T>
void input_vector(netCDF::NcFile& datafile, T*& v, const std::string input, int& ncells, int& nlev, int itime);

template <typename T>
void input_vector(netCDF::NcFile& datafile, T*& v, const std::string input, int& ncells, int& nlev);

template <typename T, typename NCT>
void output_vector(netCDF::NcFile& datafile, std::vector<netCDF::NcDim>& dims, const std::string output, T*& v,
                   int& ncells, int& nlev, int& deflate_level);

template <typename T, typename NCT>
void output_vector(netCDF::NcFile& datafile, std::vector<netCDF::NcDim>& dims, const std::string output,
                   std::map<std::string, netCDF::NcVarAtt>, T*& v, int& ncells, int& nlev, int& deflate_level);

template <typename T>
void read_fields(const std::string input_file, const int& itime, int& ncells, int& nlev, T*& z, T*& t, T*& p, T*& rho,
                 T*& qv, T*& qc, T*& qi, T*& qr, T*& qs, T*& qg);

template <typename T, typename NCT>
void write_fields(const std::string output_file, int& ncells, int& nlev, T*& t, T*& qv, T*& qc, T*& qi, T*& qr, T*& qs,
                  T*& qg, T*& prr_gsp, T*& pri_gsp, T*& prs_gsp, T*& prg_gsp, T*& pflx, T*& pre_gsp);

template <typename T, typename NCT>
void write_fields(const std::string output_file, const std::string input_file, int& ncells, int& nlev, T*& t, T*& qv,
                  T*& qc, T*& qi, T*& qr, T*& qs, T*& qg, T*& prr_gsp, T*& pri_gsp, T*& prs_gsp, T*& prg_gsp, T*& pflx,
                  T*& pre_gsp);

}  // namespace io

// include implementation
#include "netcdf_client.ipp"

#endif  // RAGNAROK_STANDALONE_AES_MICROPHYSICS_IO_NETCDF_CLIENT_H_
