<!--
This file is written using Markdown language, which might make it difficult to
read it in a plain text editor. Please, visit ICON project page on DKRZ GitLab
(https://gitlab.dkrz.de/icon/icon) to see this file rendered or use a Markdown
viewer of your choice (https://www.google.com/search?q=markdown+viewer).
-->

# Table of contents
1. [Overview](#overview)
1. [Quick start with the bubble](#quickstart-with-the-bubble)
    - [Create the config file](#step-1-create-an-experiment-config-file)
    - [Generate the runscript](#step-2-generate-the-workflow-environment-and-scripts)
    - [Run your experiment](#step-3-submit-experiment-run)
2. [Supported configurations](#additional-configurations)
3. [A deeper dive into mkexp](#a-deeper-dive)
4. [Tips](#tips)
    - [macOS](#using-macos-and-homebrew)
    - [Using mkexp with an out-of-source build](#out-of-source-build)
    - [alternatives to mkexp](#using-make_runscripts-as-an-alternative)

# Overview

MakeExperiments! (*mkexp*) is a python tool for preparing experiments with ICON. It helps users set up an experimental workflow, and generate the runscript needed to execute supported configurations.

*mkexp* presently supports setting up ICON configurations in the DKRZ environment (CPU and GPU) and is and can be adapted to other environments. Below an example is given how to adapt for macOS with homebrew. The legacy shell script [make_runscript](./make_runscript.md) supports more sites, but is not well documented, maintained, nor easy to adapt for new machines.

# Quickstart with the bubble

Running the bubble involves three steps:
1. creating the mkexp config file
2. generating the scripts and workflow environment
3. submitting the job.

As outlined below these steps are subject to some assumptions: (i) an in-source build; (ii) a python environment that supports Jinja2 and six (iii) execution in the DKRZ computing environment. Some [tips](#tips) are provded below for adapting these instructions in the case that the assumptions are not fulfilled.

## Step 1: Create an experiment config file

This is used by mkexp to create the experiment runscript, set the run environment and configure a directory structure for the run.

Start by picking a name for the experiment identifier ```exp_id```.

Select the bubble congiguration (`bubble.config`) from the `/path/to/icon-srcdir/run/examples` and copy this to a configuration file identified by your ```exp_id```, i.e.,

```sh
cd run
cp examples/bubble.config exp_id.config
```

Next it will be necessary to edit the `exp_id.config` to include particular options. As a mininum adapting `ACCOUNT` will be needed to run batch jobs on the DKRZ machines.  Running on a local machine may require further modificaiton, e.g. as shown [here for the case of macOS](#using-macos-and-homebrew).

## Step 2: Generate the workflow environment and scripts

Execute *mkexp* by entering:
```sh
../utils/mkexp/mkexp exp_id.config
```
Doing so will create a directory structure for organizing experimental output and scripting. In the DKRZ environment the path to mkexp is set by loading the icon-levante module `/path/to/icon/etc/Modules/icon-levante`, and so it need not be specified directly.

The output of *mkexp* will look something like the following:

```sh
Script directory: '/path/to/icon-srcdir/experiments/exp_id/scripts'
Data directory: '/work/your-account-number/your-user-number/master/experiments/exp_id/outdata'
Work directory: '/scratch/your-account-type/your-account-number/master/experiments/exp_id/work'
Log directory: '/work/your-account-number/your-user-number/master/experiments/exp_id/log'
```

A runscript called ```exp_id.run_start``` will also be created and placed in the "Script directory."  Review the script to make sure that the path to the grid file (```icon_grid_G.nc```) is set correctly for your environment. 

## Step 3: Submit experiment (run)

For the last step simply change to the script directory and submit your job:

```sh
cd ../experiments/exp_id/scripts
sbatch exp_id.run_start
```

This will run ICON following the script *exp_id.run_start*.

## Changing the configuration
For small changes one can edit exp_id.config and use the comand ```upexp exp_id.config``` instead of ```mkexp exp_id.config```. This generate new scripts and saves the former one in `/path/to/icon-srcdir/experiments/exp_id/scripts/backup/<time_stamp>/`. Log files will not be deleted but when running again the work directory will be overwritten.

Altenernatively one can simply edit the runscript `exp_id.run_start`, but then you need to know what you are doing -- which is a good idea more generally.  Alternatively, for a cleaner workflow and less chances of overwriting old experiments, repeat the above steps with exp_id incremented to reflect the desired changes.


# Additional configurations

Currently *mkexp* and the MPI-M only supports the bubble.  Additional configurations will be added here once *mkexp* and the testing is updated to accommodate them.

To see the supported environments, have a look at run/mkexp/environments. Further options can be found in `run/mkexp/options`

# A deeper dive

To set up an experiment, *mkexp* is run with a config file as input. eg.

```sh
EXP_TYPE = torus
EXP_OPTIONS =
ENVIRONMENT = ios
[jobs]
  [[run_start]]
    time_limit = 00:05:00
```
Unless otherwise specified the configuration is gathered from default settings.  Specialized setting such as experiment type, possibly options, the computing environment settings, and finally the config file itself can be preselected.  Latter settings amend the former.

The resulting mkexp config file which produces the runs script is written to `experiments/exp_id/scripts/exp_id.dump.`

Technical details can be found in `utils/mkexp/doc/mkexp.pdf`.

# Tips

## Using macOS and homebrew

### Ensure you have the correct python environment. 

To execute mkexp you will need a python environment/build that includes the Jinja2 and six packages.  You will also need to make mtime when configuring and building icon, i.e.,

```sh
./config/generic/gcc --enable-bundled-python=mtime
```

### Modify your ```exp_id.config``` file

Currently the computing enviornment defaults do not support macOS.  Hence to generate a runscript that will run with macOS and homebrew it is necessary to edit your ```exp_id.config``` as follows:

   ```diff
    EXP_TYPE = torus

   -ENVIRONMENT = levante
   +INPUT_ROOT = $HOME/data

   ...
  
    OUTPUT_INTERVAL = $ATMO_TIME_STEP

   +# work around for set-up info
   +use_build_env =
   +
    [namelists]

    ...

          output_grid = true
   +    [[[parallel_nml]]]
   +      num_io_procs = 0

    ...

    [jobs]
        nodes = 1
   -    threads_per_task = 4
   +    cpus_per_node = 4
   +    threads_per_task = 2
   +    hardware_threads = true
   +    ldd = otool -L
        time_limit = 00:05:00
   ```

Many of these changes, whose function should be somewhat intutitve, will also be required on a linux laptop or workstation, only the ldd command is specific to the macOS.


Once your ```exp_id.config``` has been configured to make the correct runscript for macOS, continue with [step 2 of the quickstart](#step-2-generate-the-workflow-environment-and-scripts) to create the desired run environment and scripts.


## Out-of-source build

For an in-source build *mkexp* assumes that the build directory is given as *build* and nothing needs to be specified. In the case of an [out of source build](#out-of-source-configuration-building) the *build- directory* must be set explicitly, i.e.,

```sh
export ICON_BUILD_DIR=build-directory
```

