<!--
This file is written using Markdown language, which might make it difficult to
read it in a plain text editor. Please, visit ICON project page on DKRZ GitLab
(https://gitlab.dkrz.de/icon/icon/-/tree/master/config/generic) to see this file
rendered or use a Markdown viewer of your choice
(https://www.google.com/search?q=markdown+viewer).
-->

# Introduction

This directory includes generic
[configuration wrappers](/doc/Quick_Start.md#configuration-wrappers) designed
for ICON. You can use them either inside the
[docker containers](#docker-containers) or [natively](#native-building) on your
system:
- [macOS with MacPorts](#macos-with-macports)
- [macOS with Homebrew](#macos-with-homebrew)
- [Ubuntu with Apt](#ubuntu-with-apt)
- [Arch Linux with Pacman](#arch-linux-with-pacman)

# Docker containers

The easiest way to build and run ICON on your personal machine is to use Docker
images from the
[`iconmodel` repository on Docker Hub](https://hub.docker.com/u/iconmodel).

We recommend building and running ICON inside the container while managing and
editing the source code separately in another terminal, utilizing the tools
available on your machine. This scenario implies that the directory with ICON
source code is located on the host machine and mounted to the container. You
will also need to mount a so-called `pool` directory containing ICON input
files, e.g. grid files. The contents and the layout of the directory depend on
the experiment you want to run and are not covered in this document.

Run the container in interactive mode as follows:
```bash
docker run -it -v /path/to/icon-src:/home/icon/icon -v /path/to/pool:/home/icon/pool iconmodel/icon-dev
```
where `/path/to/icon-src` and `/path/to/pool` are paths to ICON source and
`pool` directories on your machine, and `/home/icon/icon` and `/home/icon/pool`
are respective mount points of the directories inside the container.

As a result of the previous command, you will get an interactive command prompt
of the container. You can now configure, build and run ICON using the following
commands as a reference:
```console
icon@dev-gcc$ cd ./icon
icon@dev-gcc$ ./config/generic/gcc
icon@dev-gcc$ make -j4
icon@dev-gcc$ ./make_runscripts atm_tracer_Hadley
icon@dev-gcc$ cd ./run
icon@dev-gcc$ ./exp.atm_tracer_Hadley.run
```
> **_NOTE:_** To be able to run ICON inside the container, you might need to
increase the amount of RAM available to Docker (Preferences->Resources->Memory).

# Native building

These generic wrappers assume that all required
[software libraries](#software-libraries) are installed under the same prefix.
The prefix defaults to `/opt/local` with a fallback to `/opt/homebrew` on macOS
and to `/usr` on other platforms. The default values can be overridden by
setting the environment variable `ICON_SW_PREFIX`:
```bash
export ICON_SW_PREFIX='/path/to/icon/prerequisites'
```

## Prerequisites

This section provides a list of software required for building and running ICON.
Users can build and install (to the same prefix) the listed packages manually or
use the [package managers](https://en.wikipedia.org/wiki/Package_manager)
available for their platform. Basic instructions on how to do it on several
popular platforms are provided in section [Tested platforms](#tested-platforms).

### Building tools

- [GNU Make](https://www.gnu.org/software/make) v3.81+
- [CMake](https://cmake.org) v3.18+
- [Python](https://www.python.org) v3.9+
- [Perl](https://www.perl.org) v5.10+
- Interoperable C, CXX and Fortran compilers

### Software libraries

- [MPICH](https://www.mpich.org), [OpenMPI](https://www.open-mpi.org) or any
other [MPI](https://www.mpi-forum.org) implementation that provides compiler
wrappers `mpicc`, `mpicxx` and `mpif90` for C, C++ and Fortran, respectively, as
well as the job launcher `mpiexec`
    > **_NOTE:_** The job launcher of OpenMPI fails to run more MPI processes
than the number of real processor cores available on the machine by default.
That might lead to failures when configuring or running ICON. The solution to
the problem is to run the configure wrapper with an additional argument
`MPI_LAUNCH='mpiexec --oversubscribe'` (alternatively, you can set the
`OMPI_MCA_rmaps_base_oversubscribe` environment variable to `1`).

    > **_NOTE:_** It is not rare that the latest versions (or the default
versions available via the package managers) of OpenMPI and MPICH are affected
with bugs that make the libraries unusable for ICON. A way to make sure that the
MPI library does not have significant defects is to switch to the root source
directory of ICON and run the following commands (do not forget the
aforementioned extra arguments for the configure wrapper if you are using
OpenMPI):
    > ```bash
    > ./config/generic/gcc --enable-yaxt --enable-cdi-pio --enable-coupling
    > make -j4 check-bundled TESTS=  # this step speeds up the next one but can be skipped
    > make check-bundled  # avoid running this step in parallel on a weak machine, i.e. omit the -j argument
    > test $? -eq 0 && echo "Everything is fine" || echo "Something went wrong"
    > ```
    > After that, you can clean up the source directory and reconfigure ICON the
way you need.
- [HDF5](https://www.hdfgroup.org/solutions/hdf5/) with high-level interface
(for <a href="#netcdf-c">NetCDF-С</a>), thread-safety (for
<a href="#cdo">CDO</a>), and szlib filtering support (only C interface required,
not a direct dependency of ICON)
- <a name="netcdf-c"/> [NetCDF-C](https://docs.unidata.ucar.edu/netcdf-c/current/)
with NetCDF-4 support
- [NetCDF-Fortran](https://docs.unidata.ucar.edu/netcdf-fortran/current/)
- [BLAS](http://www.netlib.org/blas)
- [LAPACK](http://www.netlib.org/lapack)
- [ecCodes](https://confluence.ecmwf.int/display/ECC) with JPEG2000 and AEC
support (only C interface required)
- [libfyaml](https://github.com/pantoniou/libfyaml)
- [Libxml2](http://www.xmlsoft.org)

See section [ICON dependencies](/doc/Quick_Start.md#icon-dependencies) for more
details.

### Optional tools

- <a name="cdo"/> [CDO](https://code.mpimet.mpg.de/projects/cdo) for pre- and
post-processing, also used by some of the
[generated runscripts](/doc/Quick_Start.md#running)
- [rsync](https://rsync.samba.org/) for the generated runscipts in the case of
[out-of-source building](/doc/Quick_Start.md#out-of-source-configuration-building)

## Tested platforms and tools

This section provides basic instructions on how to install most commonly
required subset of ICON dependencies on different operating systems using
relevant package managers.

### macOS with [MacPorts](https://www.macports.org)

**Tested on `macOS Sequoia 15.3`.**

> **_NOTE:_** If you prefer and use a different package manager on your macOS
but want or have to use MacPorts for ICON, you can avoid mixing tools installed
by MacPorts with the ones from another package manager by removing the `PATH`
modifications that MacPorts automatically introduces into `~/.zprofile`, i.e.
you can remove the line `export PATH="/opt/local/bin:/opt/local/sbin:$PATH"`.
The generic configuration wrapper does not need it.

Most of the required software packages are either already available on the
system or installed together with the
[Command Line Tools for Xcode](https://mac.install.guide/commandlinetools/),
which are a [prerequisite for MacPorts](https://www.macports.org/install.php).
The rest of the required software can be installed by running the following
commands:

```bash
# Install building tools and ICON dependencies:
sudo port -N install       \
  cmake                    \
  gcc14                    \
  mpich-gcc14              \
  hdf5 +hl+threadsafe+szip \
  netcdf                   \
  netcdf-fortran +gcc14    \
  eccodes                  \
  libxml2

# Install libfyaml, which is currently not available via MacPorts:
curl -OL https://github.com/pantoniou/libfyaml/releases/download/v0.8/libfyaml-0.8.tar.gz
tar xvf libfyaml-0.8.tar.gz
cd libfyaml-0.8
./configure --prefix=/opt/local
make -j
sudo make install

# The command above can be reverted as follows:
# curl -OL https://github.com/pantoniou/libfyaml/releases/download/v0.8/libfyaml-0.8.tar.gz
# tar xvf libfyaml-0.8.tar.gz
# cd libfyaml-0.8
# ./configure --prefix=/opt/local
# sudo make uninstall

# Select the compiler and MPI compiler wrappers:
sudo port select --set gcc mp-gcc14
sudo port select --set mpi mpich-gcc14-fortran
hash -r

# Install optional tools:
sudo port -N install cdo +netcdf
```
> **_NOTE:_** You can try replacing `mpich` with `openmpi` in the commands above
if the version of MPICH that is currently available via MacPorts fails the tests
described in the [Software libraries](#software-libraries) section.
<a name="macos-openmpi-note"/>Please note that OpenMPI is known to encounter
issues when running on macOS. Although the
[list of known issues](https://www.open-mpi.org/faq/?category=osx) is very
dated, some of them are still relevant. In particular,
[this one](https://www.open-mpi.org/faq/?category=osx#startup-errors-with-open-mpi-2.0.x)
(also see [here](https://github.com/open-mpi/ompi/issues/7393)). The solution
here is to run the configure wrapper with one more argument
`BUILD_ENV="export TMPDIR='/tmp';"` and make sure that the `TMPDIR` environment
variable is set to `/tmp` before running ICON.

### macOS with [Homebrew](https://brew.sh)

**Tested on `macOS Sequoia 15.3`.**

Most of the required software packages are either already available on the
system or installed together with the
[Command Line Tools for Xcode](https://mac.install.guide/commandlinetools/),
which are a
[prerequisite for Homebrew](https://docs.brew.sh/Installation#macos-requirements).
The rest of the required software can be installed by running the following
commands:

```bash
# Install building tools and ICON dependencies:
brew install     \
  cmake          \
  eccodes        \
  gcc            \
  hdf5           \
  libfyaml       \
  libxml2        \
  mpich          \
  netcdf         \
  netcdf-fortran

# Install optional tools:
brew install cdo
```

> **_NOTE:_** You can try replacing `mpich` with `open-mpi` in the commands
above if the version of MPICH that is currently available via Homebrew fails the
tests described in the [Software libraries](#software-libraries) section. See
also the [note above](#macos-openmpi-note).

> **_NOTE:_** The [generic gcc](./gcc) configuration wrapper expects the GNU C
and C++ compilers behind the MPI compiler wrappers. However, `mpicc` and
`mpicxx` provided by Homebrew call the Apple Clang ones (i.e. `clang` and
`clang++`, respectively) by default. Although the compiler flags specified in
the configuration wrapper are compatible with Apple Clang, the latter might not
have all required features (for example, it does not support OpenMP by default,
see [here](https://mac.r-project.org/openmp/)). A way to override the C and C++
compilers called by the MPI compiler wrappers is to set the `MPICH_CC` and
`MPICH_CXX` (or `OMPI_CC` and `OMPI_CXX` if you use `open-mpi`) environment
variables before configuring and building ICON:
> ```bash
> export MPICH_CC=gcc-14
> export MPICH_CXX=g++-14
> ```

> **_NOTE:_** By default, the `mpif90` MPI compiler wrapper provided by Homebrew
calls the latest version of `gfortran`, which might not be compatible with ICON.
In that case, you can switch to an older version. For example, to downgrade to
GCC 12, you can run the foolowing commands:
> ```bash
> # Install GCC 12:
> brew install gcc@12
>
> # Override the default compilers called by the MPI wrappers (MPICH):
> export MPICH_FC=gfortran-12
> export MPICH_CC=gcc-12
> export MPICH_CXX=g++-12
> ```
> Replace `MPICH_` with `OMPI_` in the commands above if you use `open-mpi`.

### Ubuntu with [Apt](https://wiki.debian.org/Apt)

**Tested on `Ubuntu Noble Numbat 24.04.2 LTS`.**

```bash
# Install building tools and ICON dependencies:
sudo apt install -y \
  build-essential   \
  cmake             \
  python3           \
  gcc               \
  gfortran          \
  libopenmpi-dev    \
  libhdf5-dev       \
  libnetcdf-dev     \
  libnetcdff-dev    \
  libeccodes-dev    \
  libblas-dev       \
  liblapack-dev     \
  libfyaml-dev      \
  libxml2-dev

# Select MPI libraries and compiler wrappers
sudo update-alternatives --set mpi /usr/bin/mpicc.openmpi
sudo update-alternatives --set mpirun /usr/bin/mpirun.openmpi

# If the previous non-interactive commands fail,
# attempt the following interactive alternatives:
# sudo update-alternatives --config mpi
# sudo update-alternatives --config mpirun

# Install optional tools:
sudo apt install -y cdo
```

### Arch Linux with [Pacman](https://wiki.archlinux.org/index.php/pacman)

**Tested on `Arch Linux 2023.07.23`.**

```bash
# Install building tools and ICON dependencies:
sudo pacman -S --noconfirm \
  base-devel               \
  git                      \
  cmake                    \
  python                   \
  gcc-fortran              \
  openmpi                  \
  hdf5                     \
  netcdf                   \
  netcdf-fortran           \
  blas                     \
  lapack                   \
  libxml2

# Install libfyaml from the Arch User Repository:
( git clone https://aur.archlinux.org/libfyaml.git && cd libfyaml && makepkg -csi --noconfirm )
# Install ecCodes from the Arch User Repository:
( git clone https://aur.archlinux.org/eccodes.git && cd eccodes && makepkg -csi --noconfirm )

# Install optional tools:
sudo pacman -S --noconfirm rsync
# Install CDO and its extra dependencies from the Arch User Repository:
( git clone https://aur.archlinux.org/udunits.git && cd udunits && makepkg -csi --noconfirm )
( git clone https://aur.archlinux.org/magics++.git && cd magics++ && makepkg -csi --noconfirm )
( git clone https://aur.archlinux.org/cdo.git && cd cdo && makepkg -csi --noconfirm )
```
