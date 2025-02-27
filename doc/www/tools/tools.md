(ref_tools)=
# Interfaces & Tools

(ref_tools_gridextpargui)=
## Grid & Extpar WebGUI

_A publicly available tool for the generation of grid files and external parameter datasets is currently under development.
For the time being, we have to refer to the **[list of predefined grids and external parameter datasets](http://icon-downloads.mpimet.mpg.de/)**
and the **[](ref_how_to_run_recommconf)**._

(ref_tools_yac)=
## Coupling (YAC)

YAC (Yet Another Coupler) is a flexibe coupling library which comes with ICON.
Its interface is compatible to the well known OASIS coupler and it can be
used as a full replacement of it.
YAC supports many different horizontal interpolations and a unique
interpolation stack to control alternatives in case direct interpolation is not
feasable. It is not only used for coupling atmosphere and ocean components of
ICON, but also for a highly flexible output method.

```{image} yak_small_black.svg
:alt: yac
:class: only-light
:width: 200px
:align: center
:target: https://yac.gitlab-pages.dkrz.de/YAC-dev
```

```{image} yak_small_white.svg
:alt: yac
:class: only-dark
:width: 200px
:align: center
:target: https://yac.gitlab-pages.dkrz.de/YAC-dev
```

:::{admonition} YAC Documentation
:class: admonition-icontheme
You can find further information in the  [**YAC Documentation**](https://yac.gitlab-pages.dkrz.de/YAC-dev).
:::

(ref_tools_cdo)=
## Data Analyslis & Remapping (CDO)

[CDO](https://code.mpimet.mpg.de/projects/cdo) is a well know data anlysis tool
developed by [Max-Planck-Institute for Meteorology](https://mpimet.mpg.de/en). CDO supports the ICON native horizontal grid so that ICON
model output can be easily analysed.

Examples:
- [Horizontal interlations](https://code.mpimet.mpg.de/projects/cdo/wiki/FAQ#How-can-I-remap-ICON-data-when-the-grid-information-is-stored-in-a-separated-file) can be done with a wide range of methods
- Vertical interpolation from ICON (atm) vertical sigma hight coordinate with the `ap2pl` operator:
  - (optional) add CF-conform name for pressure with
  ```shell
  ncatted -O -a standard_name,pres,o,c,"air_pressure" <input> <output>     # using NCO
  ```
  or
  ```shell
  cdo -setattribute,pres@standard_name='air_pressure' <input> <output>
  ```
  - call the `ap2pl` operator in this case for a remapping to the 500 hPa and 825 hPa levels
  ```shell
  cdo ap2pl,50000,82500 <input> <output>
  ```
