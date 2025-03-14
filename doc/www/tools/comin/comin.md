```{image} ComIn_logo_black.svg
:class: only-light
```

```{image} ComIn_logo_white.svg
:class: only-dark
```

(ref_tools_comin)=
# Community Interface (ComIn)

The **Community Interface (ComIn)** organizes the data exchange and simulation events between the ICON model and "3rd party modules".
The concept can be logically divided into an Adapter Library and a Callback Register.

* **Adapter Library**: It is included in both, the ICON model and the 3rd party module.
It contains descriptive data structures, and regulates the access to existing and the creation of additional model variables.
* **Callback Register**: Subroutines of the 3rd party module may be called at pre-defined events during the model simulation.

Code contributions from different researchers and institutions ("third-party code") are usually not included in the main ICON code, but remain confined to project branches.
In any case, they add specific switches and calls to ICON's main loop, making the model code less readable.
On the other hand, to keep the third-party code compatible with new versions of ICON additional maintenance is required.
These problems are solved by providing a unified plugin interface.
While the core model remains unchanged, third-party code can be run alongside ICON, even if it is implemented in a programming language other than Fortran.
ComIn provides interfaces for **Fortran**, **C**, and **Python**.

:::{admonition} ComIn Documentation
:class: admonition-icontheme
For detailed information, see the  [**Documentation**](https://icon-comin.gitlab-pages.dkrz.de/comin/).
:::

(ref_tools_comin_exercises)=
# ComIn Exercises

In the [**ComIn Exercise Repository**](https://gitlab.dkrz.de/icon-comin/comin-training-exercises), you can find Notebooks that cover following topics:

Exercise P1:
: Programming a Rather Simple ComIn Python Plugin

Exercise P2:
: Masking (Non-)Prognostic Cells

Exercise P3:
: Implementing a Diagnostic Function as a ComIn Plugin

(ref_tools_comin_examples)=
# ComIn plugin examples

::::{grid} 1 2 2 2
:gutter: 1 1 1 2

:::{grid-item-card}
:img-top: comin_logLWP.PNG
:link: https://icon-comin.gitlab-pages.dkrz.de/comin/d4/d25/calc__water__column__plugin_8F90.html
**Implementing a new diagnostic (FORTRAN)**
^^^
* Add variables to ICON including metadata
* Access prognostic fields of ICON, e.g. humidity tracers, including conditional usage of graupel
* Access metrics data (height of half levels)

:::

:::{grid-item-card}
:img-top: comin_pntsrc.png
:link: https://icon-comin.gitlab-pages.dkrz.de/comin/df/d0b/point__source_8py.html
**Implementing a point-source tracer (Python)**
^^^
* request a tracer that participates in ICON's turbulence and convection schemes
* add point source emissions to this tracer
* update the tracer with tendencies received from ICON's turbulence and convection schemes
* exploit Python's incredibly vast library of useful modules
:::

::::
