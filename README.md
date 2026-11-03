# PROJECT_CFD

PROJECT_CFD is a small, reproducible starting point for two-dimensional computational fluid dynamics around analytic NACA four-digit airfoils. Its first stage converts MATLAB parameters into a Gmsh geometry and, when requested, an unstructured triangular mesh in SU2 format. The intended first flow case is steady, subsonic, incompressible, inviscid flow governed by the Euler equations. Solver setup and flow simulation are future work.

No external `.dat` coordinate file is required. Geometry, domain and mesh sizes are all defined in MATLAB.

## Repository layout

```text
PROJECT_CFD/
├── launch_project_cfd.m              Graphical MATLAB launcher
├── generate_naca_mesh.m              MATLAB entry point
├── configs/
│   └── naca0012_example.m            Baseline configuration
├── src/
│   ├── +geometry/naca4.m              Analytic coordinates and checks
│   ├── +meshing/write_geo.m           Gmsh geometry and size fields
│   └── +visualization/plot_domain.m   Geometry inspection plots
├── meshes/                            Generated geometry and meshes go in meshes/generated/
├── simulations/                       Reserved for later solver runs
├── docs/                              Reserved for extended methods and results
├── .gitignore
└── LICENSE
```

The `+geometry`, `+meshing` and `+visualization` directories are MATLAB packages. The entry point adds `src` to the MATLAB path for the duration of its call. Generated mesh files and future solver run products are ignored by Git; source code, configurations and documentation are versioned.

## Requirements

- MATLAB with support for local functions and package folders (R2019b or newer is recommended).
- [Gmsh](https://gmsh.info/) on the system `PATH`, or an explicit path to its executable, to create a mesh. The baseline configuration only writes the `.geo` file, so Gmsh is not needed for that step.
- [SU2](https://su2code.github.io/) for later CFD calculations. This repository does not yet contain a SU2 `.cfg` file or invoke a solver.

Use one consistent physical length unit throughout a configuration. The example uses metres, and plot labels display metres.

## Quick start

Clone the repository, open MATLAB, and change to the repository root:

```matlab
launch_project_cfd
```

The launcher exposes the airfoil code, chord, point count, circular domain, mesh-size parameters, output directory and Gmsh executable. Its domain and refinement fields are **multiples of the chord** (`[c]`), so changing the chord scales those distances automatically. **Generate .geo** writes the geometry instructions without running Gmsh. **Generate SU2 mesh** also invokes Gmsh and reports the completed mesh path. The checkbox controls the geometry plots. The default output directory is `meshes/generated/`; generated filenames include the NACA code. Input errors appear in the launcher window.

For use without the graphical interface:

```matlab
addpath('configs');
cfg = naca0012_example();
result = generate_naca_mesh(cfg);
disp(result.geoPath)
```

This writes `meshes/generated/NACA0012/naca0012.geo` and opens two geometry plots. It does **not** run Gmsh because `cfg.runGmsh` is `false`. The result reports `meshGenerated = false` and an empty `su2Path`; `expectedSu2Path` is only the intended mesh filename.

To generate a NACA 2412 mesh in a later session:

```matlab
addpath('configs');
cfg = naca0012_example();
cfg.code = '2412';
cfg.outputDir = fullfile('meshes', 'generated', 'NACA2412');
cfg.runGmsh = true;
result = generate_naca_mesh(cfg);
disp(result.su2Path)
```

`generate_naca_mesh` creates the output directory if necessary. A relative `outputDir` is resolved from the repository root, independently of MATLAB's current working directory. Absolute output paths are also accepted, including paths with spaces. The Gmsh command quotes executable and file paths for the platform shell. A failed Gmsh command raises an error and is never reported as a produced SU2 mesh.

### Configurable parameters

All distances below have the same unit as `chord`. The values are set in [`configs/naca0012_example.m`](configs/naca0012_example.m).

| Field | Example | Meaning |
| --- | ---: | --- |
| `code` | `'0012'` | Four-character NACA designation; keep leading zeros. |
| `chord` | `1.0` | Chord length. |
| `nPoints` | `161` | Points on each surface, including both edges. |
| `domainRadius` | `20*chord` | Radius of the outer circular boundary. |
| `domainCenter` | `[0.5*chord, 0]` | Centre of the outer circle. |
| `hNear` | `0.008*chord` | Target element size near the airfoil. |
| `hFar` | `1.0*chord` | Target size away from the airfoil. |
| `dMin`, `dMax` | `0.10*chord`, `3.00*chord` | Start and end distances of the wall-size transition. |
| `hEdge` | `0.004*chord` | Smaller target size at leading and trailing edges. |
| `edgeDMin`, `edgeDMax` | `0.02*chord`, `0.20*chord` | Edge-refinement transition distances. |
| `outputDir` | `meshes/generated/NACA0012` | Project-relative or absolute output directory. |
| `runGmsh` | `false` | Whether to invoke Gmsh and request SU2 export. |
| `makePlots` | `true` | Whether to open inspection plots. |
| `gmshExecutable` | `'gmsh'` | Gmsh command or executable path. |

Inputs are checked for type, finiteness and compatible positive sizes. A cambered code with a zero camber-position digit and a zero-thickness profile are rejected. The generated polygon is checked for degeneracy and self-intersection. The airfoil must fit strictly inside the outer circle. These checks cannot substitute for inspecting the resulting mesh quality.

## Airfoil equations and point order

For a code `ABCD`, the maximum camber, its chordwise location and relative thickness are

\[
m=A/100,\qquad p=B/10,\qquad t=(10C+D)/100.
\]

With \(\xi=x/c\), the cosine-spaced stations are \(\xi_i=(1-\cos\beta_i)/2\), where \(\beta_i\) runs from 0 to \(\pi\). The half-thickness is

\[
y_t=5tc\left(0.2969\sqrt{\xi}-0.1260\xi-0.3516\xi^2
                 +0.2843\xi^3-0.1036\xi^4\right).
\]

The final coefficient gives a closed trailing edge. For \(m>0\), the mean camber line is

\[
y_c=\begin{cases}
\dfrac{mc}{p^2}(2p\xi-\xi^2),&\xi<p,\\[3pt]
\dfrac{mc}{(1-p)^2}(1-2p+2p\xi-\xi^2),&\xi\ge p.
\end{cases}
\]

Its slope \(dy_c/dx\) follows by differentiating each branch. Let \(\theta=\arctan(dy_c/dx)\). Then the upper surface is \((x-y_t\sin\theta,\,y_c+y_t\cos\theta)\) and the lower surface is \((x+y_t\sin\theta,\,y_c-y_t\cos\theta)\). For symmetric profiles \(m=0\), both camber and slope are set directly to zero, avoiding division by \(p=0\) for NACA 0012.

The unique contour starts at the trailing edge, follows the upper surface to the leading edge, and returns along the lower surface. The shared edge points are written once. The coordinate data are stored in `result.geometry` for inspection.

## Gmsh construction and mesh refinement

The outer boundary is a circle centred at `(0.5*c, 0)` with radius `20*c` by default. Four quarter-circle arcs form its counterclockwise loop. Two airfoil splines form the inner loop, reversed as a clockwise hole. A single plane surface is the fluid region. The file defines named physical groups `airfoil` (wall curves), `farfield` (outer arcs) and `fluid` (surface), which provide boundary identifiers for later SU2 setup.

Gmsh `Distance` and `Threshold` fields control the target size around the airfoil curves. A second pair of fields supplies smaller target sizes around the leading and trailing edge points. A `Min` field combines the two target sizes. The size grows from `hNear` or `hEdge` toward `hFar` over the configured distance intervals. Gmsh's Frontal-Delaunay 2D algorithm creates first-order triangles. This Euler-oriented mesh has no viscous boundary-layer prisms.

The default sizes are initial engineering choices, not a claim of grid convergence. Inspect element quality and perform mesh refinement studies before using the mesh for quantitative CFD.

## Generated files and manual Gmsh use

The MATLAB entry point first writes `nacaXXXX.geo`. If `runGmsh = true`, it asks Gmsh to write `nacaXXXX.su2` beside it. The `.geo` file is geometry and mesh instructions; it is **not** a completed mesh. You can inspect and export manually from the repository root:

```sh
gmsh "meshes/generated/NACA0012/naca0012.geo"
gmsh -2 "meshes/generated/NACA0012/naca0012.geo" -format su2 -o "meshes/generated/NACA0012/naca0012.su2"
```

The same meshing command is assembled and executed by MATLAB when `cfg.runGmsh = true`. Both `.geo` and `.su2` files under `meshes/generated/` are intentionally untracked.

## Current limits and roadmap

This initial version provides geometry generation, Gmsh instructions, optional mesh export and visualization only. It does not include a SU2 flow configuration, solver run, mesh-quality report, force calculation, validation case or automated tests. The analytic NACA representation is limited to four-digit profiles with positive thickness and a closed trailing edge. The circle is a simple farfield choice; its size should be checked for a particular flow case.

Planned steps are to inspect and validate exported meshes, add an Euler SU2 configuration for a reproducible subsonic case, compare against reference data, then extend the workflow to compressible transonic and supersonic conditions. Viscous modelling and boundary layers require a separate meshing strategy and are outside this first stage.

## License

MIT, copyright 2026 Camile Briard. See [LICENSE](LICENSE).
