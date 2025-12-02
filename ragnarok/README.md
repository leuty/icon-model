# ICON RAGNAROK

Ragnarok is the C++ implementation of the AES physics based on the [Kokkos](https://github.com/kokkos/kokkos) programming model.


## Project Structure

```
└── 📁ragnarok
    └── 📁cmake
        └── 📁caches
            ├── levante_cpu.cmake
            ├── levante_gpu.cmake
    └── 📁common
        ├── CMakeLists.txt
        ├── types_test.cpp
        ├── types.hpp
    └── 📁support
        └── 📁icon_bridge
        └── 📁testing
        └── 📁timer
        ├── CMakeLists.txt
    └── 📁aes_component
        ├── CMakeLists.txt
    ├── CMakeLists.txt
    ├── CONTRIBUTING.md
    └── README.md
```

Shared functionality that is used across physics components belongs in the `common/` directory.

The `support/` directory provides infrastructure used throughout Ragnarok:

* `icon_bridge` provides access to the data and functionality available in the main ICON code. Additionally, it also provides initialize and finalize routines for Ragnarok. Its support will be extended as needed.
* `timer` mirrors the ICON timer infrastructure. When Ragnarok is built as part of ICON, calls to `start` and `stop` are forwarded to `mo_timer.f90` so that Ragnarok timers appear in the experiment logfile. When built standalone, Ragnarok provides an ICON-compatible timer implementation based on `Kokkos::Timer`.
* `testing` provides the entry point for standalone unit testing and is also used in the GitLab CI pipelines.

## Usage

Ragnarok is integrated into ICON and is built automatically when ICON is configured with `--enable-ragnarok`. The ICON build system also ensures that the correct compilation flags and the appropriate Kokkos backend (from the `externals/kokkos` submodule) are used.

## Available Compile Options

> **Note:** default options are marked in __bold__

* _Unit-test_ - compile unit-tests
  * BUILD_TESTING=__ON__/OFF
* Standalone - compile standalone components
  * RGK_ENABLE_STANDALONE=__ON__/OFF

### Build as part of ICON

The ICON configuration scripts automatically configure both Ragnarok and Kokkos.

### Build Standalone

Ragnarok can also be built independently of ICON. Cache files for Levante are available under `ragnarok/cmake/caches/`. For example:

  ```
  cmake -B build -S ragnarok -C ragnarok/cmake/caches/levante_cpu.cmake`
  ```

## Testing

Ragnarok uses GoogleTest for unit testing. To run the tests:

  ```
  cd build && ctest
  ```
