```{eval-rst}
:orphan:
```

(ref_buildrun_supportedconf)=
# Supported Configurations

ICON partners provide a number of supported scientific configurations, which already provide everything necessary for running ICON. Please note that there is no support for configurations that are not listed below.


## AES Configurations

These configurations are supported by the Max Planck Institute for Meteorology. AES (Atmosphere in the Earth System) indicates the use of AES physics, which is designed for high-performance computing platforms and simulations with horizontal grids of 10 km or less on a variety of domains. The AES configurations can be generated using {{ '[mkexp]({}/doc/www/buildrun/buildrun_running.md)'.format(base_url) }}.

[Aquaplanet](ref_buildrun_aquaplanet)
: This configuration runs the ICON atomspheric component in interaction with an idealized ocean (e.g., SST-QOBS). This set-up allows a fast integration to achieve a climate mean state in comparisson to AMIP simulations.

[Bubble](ref_buildrun_bubble):
: This is a simple idealized case used for code development.  It simulates a buoyant, slab symmetric, bubble, on a small bi-periodic domain. The short simulation time (120 min, 240 timesteps) and the small domain (160 cells) allows output to be written at every timestep and grid point. The slab-symmetric setupt makes it easy to visualize.

[Nest](ref_buildrun_nest):
: This case tests ICON's capability of handling several meshes, nested within one another. The configuration uses a global R2B4 parent mesh, a first-level nested domain that covers the Atlantic ocean, and two second-level nested domains focused over the ITCZ and stratocumulus southern region. The latter two domains share the same parent mesh, which slightly complexifies the case. This allows to test both the parent-child nesting and most features pertaining to limited-area runs.

[AMIP](ref_buildrun_amip):
: This configuration follows the Atmospheric Model Intercomparison Project (AMIP) protocol. In this configuration, ICON solves the fluid dynamics equations in the atmosphere on the entire Globe using horizontal grid spacing of 40 km and finer. The atmosphere is coupled to a 1-D land module and to a non-dynamical ocean and sea ice. This means that sea surface temperature and sea ice area is prescribed. The atmosphere is vertically discretized in 90 levels, and the land is represented by 5 soil layers.

[RCE](ref_buildrun_rce):
: This configuration is intended to study the Radiative Convective Equilibrium (RCE) achieved in ICON. RCE is an important conceptualization for understanding climate. RCE inquires about the thermodynamical equilibrium that a moist atmosphere would attain under constant incoming solar radiation, and is the result of a balance between the latent heating by condensation and the long-wave radiative cooling of the atmosphere. Simulated times in the order of 200 days give insight into how RCE is achieved in ICON. For the purposes of code development this case is run for 6 simulated hours.


### Coupled configurations

[Coupled AES](ref_buildrun_aes_coupled):
: Unified coupled atmosphere/ocean configuration based on a simplified version of the [nextGEMS](https://nextgems-h2020.eu/) experiments. The full version is currenty under development.


## OES Configurations

The OES (Ocean in the Earth System) configurations are supported by the Max Planck Institute for Meteorology.

[OMIP](ref_buildrun_omip):
: This is a close-to-production configuration for ICON's ocean model componed used for code development. It can be regarded as the main ocean configuration that enables all major available features as far as they can be activated simultaneously.


## NWP Use Cases

The use cases for NWP (Numerical Weather Prediction) are supported by Deutscher Wetterdienst (DWD).

[NWP Global (R2B06)](ref_buildrun_nwp_global):
: This use case runs a global ICON application with a resolution of about 40 km (R02B06). It includes a nest (R02B07) over Europe.

[NWP Local (R19B07)](ref_buildrun_nwp_local):
: This use case runs a limited-area (local) ICON application over Germany with a resolution of about 2 km (R19B07).
  It is comparable to DWD's operational application ICON-D2.
