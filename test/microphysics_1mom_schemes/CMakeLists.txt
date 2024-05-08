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
cmake_minimum_required(VERSION 3.18)

project(microphysics_1mom_schemes VERSION 0.1.0 LANGUAGES Fortran)

find_package(OpenACC QUIET)

option(BUILD_SHARED_LIBS "Build shared libraries" ON)
option(BUILD_OPENACC "Build with OpenACC support" ${OpenACC_Fortran_FOUND})
option(BUILD_LOOP_EXCHANGE "Build with the loop exchange feature" OFF)

include(GNUInstallDirs)

if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE "RelWithDebInfo" CACHE STRING
      "Choose the type of build, options are: Debug Release RelWithDebInfo" FORCE)
  message(STATUS "Setting build type to '${CMAKE_BUILD_TYPE}' as none was specified")
endif(NOT CMAKE_BUILD_TYPE)

#### Dependencies
include(FetchContent)
if ("${CMAKE_VERSION}" VERSION_GREATER_EQUAL "3.24")
  cmake_policy(SET CMP0135 NEW)
endif()

message(CHECK_START "${PROJECT_NAME}: Fetching the fortran-support library")
FetchContent_Declare(fortran-support
  GIT_REPOSITORY git@gitlab.dkrz.de:icon-libraries/libfortran-support.git
  GIT_TAG 192aa262677e02ef0116bdc3d767837ebf293e64)

FetchContent_MakeAvailable(fortran-support)
message(CHECK_PASS "done")

message(CHECK_START "${PROJECT_NAME}: Fetching the math-support library")
FetchContent_Declare(math-support
  GIT_REPOSITORY git@gitlab.dkrz.de:icon-libraries/libmath-support.git
  GIT_TAG 9ad96c8e12a58f0e485bdcef8b832ed15cfce0ca)
FetchContent_MakeAvailable(math-support)
message(CHECK_PASS "done")

if (BUILD_OPENACC)
  find_package(OpenACC REQUIRED)
endif()

list(APPEND CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake/Modules")
message(STATUS ${CMAKE_MODULE_PATH})

find_package(NetCDF COMPONENTS Fortran REQUIRED)

set(MICROPHYSICS_PATH ${CMAKE_CURRENT_SOURCE_DIR}/../../src/granules/microphysics_1mom_schemes)
set(SATAD_PATH ${CMAKE_CURRENT_SOURCE_DIR}/../../src/atm_phy_schemes)

# Add the library with the specified files
add_library(microphysics_1mom_schemes
  ${SATAD_PATH}/mo_satad.f90
  ${SATAD_PATH}/mo_lookup_tables_constants.f90
  ${MICROPHYSICS_PATH}/gscp_graupel.f90
  ${MICROPHYSICS_PATH}/gscp_data.f90
  ${MICROPHYSICS_PATH}/gscp_kessler.f90
  ${MICROPHYSICS_PATH}/gscp_cloudice.f90
  ${MICROPHYSICS_PATH}/gscp_ice.f90
  ${MICROPHYSICS_PATH}/microphysics_1mom_schemes.f90
)
add_library(${PROJECT_NAME}::microphysics_1mom_schemes ALIAS microphysics_1mom_schemes)

add_executable(microphysics_1mom_driver
  microphysics_1mom_driver.f90
)
set(Fortran_MODULE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/mod")
set_target_properties(microphysics_1mom_schemes
  PROPERTIES
    Fortran_PREPROCESS ON
    Fortran_MODULE_DIRECTORY "${Fortran_MODULE_DIRECTORY}"
    EXPORT_NAME ${PROJECT_NAME}::microphysics_1mom_schemes
)

set_target_properties(microphysics_1mom_driver
  PROPERTIES
    Fortran_PREPROCESS ON
    Fortran_MODULE_DIRECTORY "${Fortran_MODULE_DIRECTORY}"
    EXPORT_NAME ${PROJECT_NAME}::microphysics_1mom_driver.f90
)

target_include_directories(microphysics_1mom_schemes
  PUBLIC
    $<BUILD_INTERFACE:${Fortran_MODULE_DIRECTORY}>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
  INTERFACE
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
)

target_link_libraries(microphysics_1mom_schemes PUBLIC fortran-support::fortran-support 
  math-support::math-support)

target_link_libraries(microphysics_1mom_driver 
  PUBLIC fortran-support::fortran-support 
  math-support::math-support
  NetCDF::NetCDF_Fortran
  microphysics_1mom_schemes::microphysics_1mom_schemes)
if (BUILD_OPENACC)
  target_compile_options(microphysics_1mom_driver PRIVATE ${OpenACC_Fortran_OPTIONS})
  target_link_libraries(microphysics_1mom_driver PRIVATE OpenACC::OpenACC_Fortran)
  target_compile_options(microphysics_1mom_schemes PRIVATE ${OpenACC_Fortran_OPTIONS})
  target_link_libraries(microphysics_1mom_schemes PRIVATE OpenACC::OpenACC_Fortran)
endif()
if (BUILD_LOOP_EXCHANGE)
  target_compile_definitions(microphysics_1mom_schemes PRIVATE _LOOP_EXCHANGE=1)
endif()

find_package(Python COMPONENTS Interpreter REQUIRED)
enable_testing()

configure_file(${PROJECT_SOURCE_DIR}/create_stats_wrapper.sh.in ${CMAKE_BINARY_DIR}/create_stats_wrapper.sh @ONLY)
configure_file(${PROJECT_SOURCE_DIR}/run_all_schemes.sh.in ${CMAKE_BINARY_DIR}/run_all_schemes.sh)

set(FILE_NAME "aes-new-gr_moderate-dt30s_atm_3d_ml_20080801T000000Z.nc")
set(INPUT_FILE_NAME "input-data.nc")
set(DOWNLOAD_URL "https://swift.dkrz.de/v1/dkrz_f23c4ba9-4a6c-4d70-8739-7bca74b37234/muphys_data/${FILE_NAME}")
add_custom_target(fetch_input
    COMMAND ${CMAKE_COMMAND} -E echo "Fetching input file..."
    COMMAND ${CMAKE_COMMAND} -E make_directory "${CMAKE_CURRENT_BINARY_DIR}"
    COMMAND wget -P "${CMAKE_CURRENT_BINARY_DIR}" "${DOWNLOAD_URL}" "-O" "${INPUT_FILE_NAME}"
    COMMAND ${CMAKE_COMMAND} -E echo "Input file fetched."
)

add_custom_target(probtest_prepare
    COMMAND ${CMAKE_COMMAND} -E echo "Running probtest initialization..."
    COMMAND ${Python_EXECUTABLE} ${PROJECT_SOURCE_DIR}/../../externals/probtest/probtest.py init --codebase-install ${CMAKE_CURRENT_BINARY_DIR} --template-name ${PROJECT_SOURCE_DIR}/../../externals/probtest/templates/granule.jinja --experiment-name 1mom --member-num 9
    COMMAND ${CMAKE_COMMAND} -E echo "Running probtest perturbation..."
    COMMAND ${Python_EXECUTABLE} ${PROJECT_SOURCE_DIR}/../../externals/probtest/probtest.py perturb
    COMMAND ${CMAKE_COMMAND} -E echo "Running probtest ensemble..."
    COMMAND ${Python_EXECUTABLE} ${PROJECT_SOURCE_DIR}/../../externals/probtest/probtest.py run-ensemble
    DEPENDS fetch_input
)


# define number of tests for each scheme
set(GRAUPEL_NUM_TESTS 3)
set(KESSLER_NUM_TESTS 1)
set(CLOUDICE_NUM_TESTS 3)
set(CLOUDICE2MOM_NUM_TESTS 3)

include("${PROJECT_SOURCE_DIR}/cmake/probtest_custom_target.cmake")

probtest_target(probtest_prepare graupel ${GRAUPEL_NUM_TESTS})
probtest_target(probtest_prepare kessler ${KESSLER_NUM_TESTS})
probtest_target(probtest_prepare cloudice ${CLOUDICE_NUM_TESTS})
probtest_target(probtest_prepare cloudice2mom ${CLOUDICE2MOM_NUM_TESTS})

add_custom_target(tolerance 
COMMAND cp ${CMAKE_CURRENT_BINARY_DIR}/*_ref ${PROJECT_SOURCE_DIR}/reference/.
COMMAND cp ${CMAKE_CURRENT_BINARY_DIR}/tolerance/* ${PROJECT_SOURCE_DIR}/tolerance/.
DEPENDS graupel_stats cloudice_stats kessler_stats cloudice2mom_stats)

# prepare build-dir for testing
add_test(NAME fetch_input 
  COMMAND wget -P "${CMAKE_CURRENT_BINARY_DIR}" "${DOWNLOAD_URL}" -O "${INPUT_FILE_NAME}")

add_test(NAME init_probtest
         COMMAND python ${PROJECT_SOURCE_DIR}/../../externals/probtest/probtest.py init --codebase-install . --template-name ${PROJECT_SOURCE_DIR}/../../externals/probtest/templates/granule.jinja --experiment-name 1mom)


include("${PROJECT_SOURCE_DIR}/cmake/tolerance_helper.cmake")

register_tolerance_test(graupel ${GRAUPEL_NUM_TESTS})
register_tolerance_test(cloudice ${CLOUDICE_NUM_TESTS})
register_tolerance_test(cloudice2mom ${CLOUDICE2MOM_NUM_TESTS})
register_tolerance_test(kessler ${KESSLER_NUM_TESTS})

install(
  DIRECTORY
    "${Fortran_MODULE_DIRECTORY}/"
  TYPE INCLUDE
)

install(
  TARGETS microphysics_1mom_schemes
  EXPORT "${PROJECT_NAME}-targets"
)

#### Installation
export(
  EXPORT "${PROJECT_NAME}-targets"
  FILE "${PROJECT_BINARY_DIR}/${PROJECT_NAME}-targets.cmake"
)

include(CMakePackageConfigHelpers)
configure_package_config_file(
  "${PROJECT_SOURCE_DIR}/cmake/config.cmake.in"
  "${PROJECT_BINARY_DIR}/${PROJECT_NAME}-config.cmake"
  INSTALL_DESTINATION "${CMAKE_INSTALL_LIBDIR}/cmake"
  NO_SET_AND_CHECK_MACRO
  NO_CHECK_REQUIRED_COMPONENTS_MACRO
)

write_basic_package_version_file(
  "${PROJECT_BINARY_DIR}/${PROJECT_NAME}-config-version.cmake"
  VERSION "${${PROJECT_NAME}_VERSION_MAJOR}.${${PROJECT_NAME}_VERSION_MINOR}"
  COMPATIBILITY AnyNewerVersion
)

install(
  EXPORT "${PROJECT_NAME}-targets"
  DESTINATION "${CMAKE_INSTALL_LIBDIR}/${PROJECT_NAME}/cmake"
)

install(
  FILES
    "${PROJECT_BINARY_DIR}/${PROJECT_NAME}-config.cmake"
    "${PROJECT_BINARY_DIR}/${PROJECT_NAME}-config-version.cmake"
  DESTINATION
    "${CMAKE_INSTALL_LIBDIR}/${PROJECT_NAME}/cmake"
)
