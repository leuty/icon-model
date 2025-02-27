(ref_how_to_run)=
# How to Run

(ref_how_to_run_gridextpar)=
## Grids & External Parameters

### Grid Files

The ICON model receives information about the horizontal grid from so-called **grid files** in the [NetCDF format](https://www.unidata.ucar.edu/software/netcdf/).
These files store coordinates and topological index relations between cells, edges and vertices of the chosen domain.
A detailed description of the content of these grid files is provided in the _Necessary Input Data_ section of the **{term}`ICON Tutorial 2024`**.

The grid files for ICON usually follow the nomenclature `R<n>B<k>`, where `<n>` denotes the number of root divisions and `<k>` the number of subsequent bisections.
From `<n>` and `<k>` the resolution of the grid can be estimated by the formula:

```{math}
\Delta x \sim \frac{5050}{n \cdot 2^k} \quad km.
```

:::{admonition} Download Grid & External Parameter Data
:class: admonition-icontheme
A set of predefined grid and external parameter datasets is available at **[http://icon-downloads.mpimet.mpg.de/](http://icon-downloads.mpimet.mpg.de/)**.
:::

(ref_how_to_run_external_param)=
### External Parameters (NWP)

_Please note that this description applies to the [](ref_atmosphere_nwp_physics)_.

External parameter datasets contain topological and climatological data that is assumed to be constant during a typical NWP integration.
These datasets are aggregated to a given ICON grid using the **[EXTPAR Software](http://www.cosmo-model.org/content/support/software/default.htm)**.
Like for the grid files, a more detailed description is given in the _Necessary Input Data_ section of the **{term}`ICON Tutorial 2024`**.

(ref_how_to_run_icbc)=
## Initial & Boundary Data
