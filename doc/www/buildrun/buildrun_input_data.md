```{eval-rst}
:orphan:
```

(ref_buildrun_input_data)=
# Input Data

(ref_buildrun_grid_files)=
## Grid Files

The ICON model receives information about the horizontal grid from so-called **grid files** in the [NetCDF format](https://www.unidata.ucar.edu/software/netcdf/).
These files store coordinates and topological index relations between cells, edges and vertices of the chosen domain.
A detailed description of the content of these grid files is provided in the _Necessary Input Data_ section of the **{term}`ICON Tutorial`**.

The grid files for ICON usually follow the nomenclature `R<n>B<k>`, where `<n>` denotes the number of root divisions and `<k>` the number of subsequent bisections.
From `<n>` and `<k>` the resolution of the grid can be estimated by the formula:

```{math}
\Delta x \sim \frac{5050}{n \cdot 2^k} \quad km.
```

(ref_buildrun_external_param)=
## External Parameters (NWP)

{material-regular}`warning;2em;pst-color-secondary` _Please note that this description applies to the [](ref_atmosphere_nwp_physics)_.

External parameter datasets contain topological and climatological data that is assumed to be constant during a typical NWP integration.
These datasets are aggregated to a given ICON grid using the **[EXTPAR Software](http://www.cosmo-model.org/content/support/software/default.htm)**.
Further information is available in the **[EXTPAR Documentation](https://c2sm.github.io/extpar/)** and in the _Necessary Input Data_ section of the **{term}`ICON Tutorial`**.

### Obtaining Grid & External Parameter Files

Currently, there are two options to obtain [grid](ref_buildrun_grid_files) and [external parameter](ref_buildrun_external_param) data:

- A set of predefined grid and external parameter datasets is available at **[icon-downloads.mpimet.mpg.de/](http://icon-downloads.mpimet.mpg.de/)**.

- For users, who want to specify a custom domain, the **[Zonda Webinterface](ref_tools_gridextpargui)** provides all relevant options.

(ref_buildrun_ini_bound_data)=
## Initial & Boundary Data

Besides horizontal grid files and external parameters, ICON needs data describing
the initial state of the component to run. NWP runs require data for atmosphere,
land and sea. When running ICON in limited-area mode also lateral boundary data have
to be provided in regular time intervals.

ICON can take data from DWD's Data Assimilation Coding Environment (DACE), from
its own forecasts, and data interpolated from IFS forecasts or analysis.
Depending on which data is taken, several steps are necessary to process these
data in a way that they can be read by ICON.

* [Data Assimilation System]
* [ICON forecasts]
* [IFS analysis or forecasts](ref_buildrun_icbcifs)
