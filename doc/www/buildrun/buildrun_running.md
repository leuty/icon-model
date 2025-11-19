```{eval-rst}
:orphan:
```

(ref_buildrun_running)=
# Running ICON

The ICON model is typically run through a *runscript*, which sets up the working directory, populates it with all required input files (grid files, namelists, etc.), sets environment variables, runs the model, and postprocesses its output.

You can generate a runscript with one of the two tools described in this document. The first tool [`mkexp`](ref_buildrun_mkexp) is well documented and continuously maintained. The only downside is that it does not have support for many environments and experiments that you can run with ICON yet. The second one [`make_runscript`](ref_buildrun_make_runscript) is a legacy, poorly documented set of shell scripts, which, however, supports a lot of (mainly HPC) environments and experiments.

(ref_buildrun_mkexp)=
## Using `mkexp` to prepare ICON experiments

[MakeExperiments! (`mkexp`)](https://gitlab.dkrz.de/esmenv/mkexp) is a Python tool for preparing experiments with ICON. It helps users set up an experimental workflow, and generate the runscript needed to execute supported configurations. The tool presently supports setting up ICON configurations in the DKRZ environment (CPU and GPU) and is and can be adapted to other environments.

You can find the `mkexp` tool in the `utils/mkexp` directory of the ICON source code repository, which is managed as a git submodule.

### Requirements

Before you start using `mkexp`, make sure that your software environment meets the following requirements:

1. You need to make sure that [Jinja2](https://pypi.org/project/Jinja2/) and [six](https://pypi.org/project/six/) are available in your Python environment.
   Another option is installing `mkexp` in your local or virtual Python environment with

    ```sh
    python3 -m pip install utils/mkexp
    ```

1. If ICON is configured and built [out-of-source](ref_buildrun_configuration_oos), you need to set the `MKEXP_PATH` environment variable to include the absolute path of the "`run`" subdirectory in your root build directory, like

    ```sh
    export MKEXP_PATH=.:/path/to/icon/build/directory/run
    ```

### Steps to run an experiment

Running an experiment using `mkexp` generally consists of three steps briefly described below in this section. For more details, see the [documentation](https://gitlab.dkrz.de/esmenv/mkexp/-/blob/master/doc/mkexp.pdf).

**Step 1: Create the configuration file**

The configuration file overrides the generic parameters specified in `run/mkexp/defaults/DEFAULT.config`. The experiment- and environment-specific parameters can be overridden or set via the `EXP_TYPE` and `ENVIRONMENT` variables of the configuration file. The values of those variables correspond to the `.config` files in the `run/mkexp/types` and `run/mkexp/environments` directories. The configuration file of an experiment can override or set additional parameters via the `EXP_OPTIONS` variable (the value corresponds to the files in the `run/mkexp/options` directory or directly. The resulting set of parameters is used by `mkexp` to create the experiment runscript, set the run environment and configure the required directory structure for the run.

The most simple way to create the configuration file for an experiment is to copy one of the `/run/examples` (e.g. `/run/examples/bubble.config`) and adjust it to your needs. First, you need to come up with the experiment identifier (e.g. `exp_id`) and copy the example configuration to the {{ '[`run`]({}/run)'.format(base_url) }} directory under the name that corresponds to that identifier:

```sh
cd ./run
cp ./examples/bubble.config ./exp_id.config
```

You may now review and edit the contents of `exp_id.config`. It should run on most personal computing devices without changes.

Running the experiment in an HPC environment may require adjustments. For example, if you intend to run the experiment on the DKRZ machine, make sure the `ACCOUNT` is set correctly (it should be set to the SLURM account that you normally submit jobs with):

```diff
@@ -15,2 +15,3 @@
 EXP_TYPE = torus
+ACCOUNT = xy1234

```

**Step 2: Generate the scripts and workflow environment**

Execute [`mkexp`](https://gitlab.dkrz.de/esmenv/mkexp/-/blob/master/mkexp):

```sh
../utils/mkexp/mkexp exp_id.config
```

The command will create the required directory structure. For example:

```sh
Script directory: '/path/to/icon-srcdir/experiments/exp_id/scripts'
Data directory: '/work/your-account-number/your-user-number/master/experiments/exp_id/outdata'
Work directory: '/scratch/your-account-type/your-account-number/master/experiments/exp_id/work'
Log directory: '/work/your-account-number/your-user-number/master/experiments/exp_id/log'
```

The command will also create the `exp_id.run_start` runscript and place it to the `Script directory`. Review the script to make sure that the path to the grid file (`icon_grid_G.nc`) is set correctly for your environment.

**Step 3: Execute the runscript.**

For the last step, switch to the aforementioned `Script directory` and either execute or submit (if you are in the HPC environment) the runscript:

```sh
cd ../experiments/exp_id/scripts
sbatch exp_id.run_start
```

(ref_buildrun_make_runscript)=
## Using `make_runscript` to prepare ICON experiments

The `make_runscript` shell script is an ICON-specific tool for runscript generation. It takes the experiment template files from the {{ '[`run`]({}/run)'.format(base_url) }} directory, prepends the environment-specific shell snippets from the `run/create_target_header` file, adjusts the result based on how ICON is configured and built (see `run/collect.set-up.info.in`) and produces a shell script that is ready for the execution or submission.

### Requirements

The tool does not support the [out-of-source](ref_buildrun_configuration_oos) builds. To circumvent this, most of the existing [configure wrappers](ref_buildrun_configuration_wrappers) make the required files available in the build directory:

```sh
# Copy runscript-related files when building out-of-source:
if test $(pwd) != $(cd "${icon_dir}"; pwd); then
  rsync -uavz ${icon_dir}/run . --exclude='*.in' --exclude='.*' --exclude='standard_*' --exclude=mkexp
  ln -sf -t run/ ${icon_dir}/run/{standard_*,mkexp}
  for dir in \
    'externals/art/runctrl_examples' \
    'externals/ecrad/data' \
    'externals/jsbach/data'
  do
    src="${icon_dir}/${dir}"
    test -d "${src}" && mkdir -p "${dir}" && rsync -uavz "${src}/" "${dir}"
  done
  rsync -uavz ${icon_dir}/make_runscripts .
  ln -sf ${icon_dir}/data
  ln -sf ${icon_dir}/vertical_coord_tables
fi
```

### Steps to run an experiment

To generate a runscript based on a particular template (e.g. `run/exp.atm_tracer_Hadley`), switch to the root build directory of ICON and run `make_runscript` while providing the name of the experiment (without the prefix) as an argument:

```sh
./make_runscripts atm_tracer_Hadley
```

Alternatively, you can generate runscripts for all existing experiments:

```sh
./make_runscripts --all
```

The generated runscripts are saved to the {{ '[`run`]({}/run)'.format(base_url) }} subdirectory of the build directory. The headers of the runscripts containing arguments for the HPC workload manager, e.g. [SLURM](https://slurm.schedmd.com/), might require additional manual adjustments regarding CPU time accounting, node allocation, etc.

Once the runscript is created and adjusted, switch to the {{ '[`run`]({}/run)'.format(base_url) }} subdirectory of the root build directory of ICON and either execute or submit (if you are in the HPC environment) the runscript:

```sh
cd ./run
sbatch ./exp.atm_tracer_Hadley.run
```

:::{admonition} checksuite.nwp specifics
:class: admonition-icontheme
Experiments in the `run/checksuite.nwp` directory are prepared to be run in the hybrid mode, which uses two icon binaries. To generate those experiments the user can specify the `-r <run directory to process>` argument:
```sh
./make_runscripts --all -r run/checksuite.nwp
```
In the case of the NEC-Aurora, the second binary is the host (or x86 scalar) binary. It can be found automatically if the two build directories are either `something/vector` and `something/host` or `something_else/VH` and `something_else/VE`. In either case, `./make_runscripts` must be called in the `vector` (or `VE`) build directory. Alternatively, the x86-host binary can be specified by the `-s <secondary build dir>` option:
```sh
./make_runscripts run_ICON_01_R3B9_lam -r run/checksuite.nwp -s ../host_gcc-9.1.0/
```
:::

:::{admonition} make_target_runscript
:class: admonition-icontheme
Alternatively, the users can employ the low-level tool `/run/make_target_runscript` for runscript generation offering more fine-grained control over certain parameters. For example, the wall clock limit and the number of allocated nodes can be injected into the runscript as follows:
```sh
cd ./run && ln -sf ./checksuite.ocean_internal/omip/exp.ocean_omip_long exp.ocean_omip_long
./make_target_runscript in_script=exp.ocean_omip_long in_script=exec.iconrun \
  EXPNAME=ocean_omip_long cpu_time=08:00:00 no_of_nodes=20
```
:::
