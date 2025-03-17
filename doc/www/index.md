# Welcome to the ICON Model documentation

:::topic 
_It's the job that's never started as takes longest to finish - J.R.R. Tolkien_
:::

The website **[docs.icon-model.org](https://docs.icon-model.org)** contains a collection of ICON documentation including references to documentation available at other places. We do not claim that this documentation is complete, but we hope you will still find it helpful.


```{toctree}
:hidden:
installation/installation.md
how_to_run/how_to_run.md
how_to_run/recommended_config/recommended_config.md
tools/tools.md
tools/comin/comin.md
atmosphere/atmosphere.md
atmosphere/art/art.md
ocean/ocean.md
land/land.md
infrastructure/infrastructure.md
literature/literature.md
```

:::{admonition} Release Information
:class: admonition-icontheme
You can find the latest ICON release [**here**](https://gitlab.dkrz.de/icon/icon-model).
It is planned to publish at least two major ICON open source releases per year, in April and October.
Here are some highlights of the upcoming **ICON Release 2025.04**:
* Changes to AES and NWP Physics
* Diagnostics for ICON Ocean
* Further QUINCY development
* Update of iconmath: version 1.1.1 for math-support and math-interpolation
* [Update of Comin](https://gitlab.dkrz.de/icon-comin/comin/-/releases) (support additional datatypes; automatic halo synchronization; various refactoring)
:::

::::{grid} 1 2 2 3
:gutter: 1 1 1 2

:::{grid-item-card}
**Installation**
^^^
[](ref_installation_building)  
[](ref_installation_testing)  
[](ref_installation_hardware)
:::

:::{grid-item-card}
**How to Run**
^^^
[](ref_how_to_run_gridextpar)  
[](ref_how_to_run_icbc)  
[](ref_how_to_run_recommconf)
:::

:::{grid-item-card}
**Interfaces & Tools**
^^^
[](ref_tools_gridextpargui)  
[](ref_tools_yac)  
[](ref_tools_cdo)  
[](ref_tools_comin)
:::

:::{grid-item-card}
**Atmosphere**
^^^
[](ref_atmosphere)  
[](ref_atmosphere_dycore)  
[](ref_atmosphere_physics)  
[](ref_atmosphere_nwp_waves)  
[](ref_atmosphere_art)
:::

:::{grid-item-card}
**Ocean**
^^^
[](ref_ocean_overview)  
[](ref_ocean_seaice)  
[](ref_ocean_biogeochem)
:::

:::{grid-item-card}
**Land**
^^^
[](ref_land)  
[](ref_land_schemes)  
[](ref_land_cover_change)  
[](ref_land_biogeochem)
:::

:::{grid-item-card}
**Infrastructure**
^^^
[](ref_infrastructure_parallelization)  
[](ref_infrastructure_io)
:::

:::{grid-item-card}
**Literature**
^^^
[](ref_literature_tutorials)  
[](ref_literature_technical)  
[](ref_literature_science)
:::

::::

