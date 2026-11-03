# PROJECT_CFD

A single MATLAB script builds a NACA four-digit airfoil, writes a circular 2D fluid domain for Gmsh, and exports a triangular mesh in SU2 format. It is intended as a readable starting point for a steady, subsonic, incompressible, inviscid CFD case. No SU2 solver setup is included.

## Requirements

- MATLAB
- Gmsh available as the `gmsh` command, or an executable path entered in the script

## Use

Open [`NACA_Mesh.m`](NACA_Mesh.m). Edit the **Parameters** section at the top, then click **Run** in MATLAB. For example, change `NACA = '0012'` to `NACA = '2412'` to build a cambered profile. The chord, number of points, farfield radius, mesh sizes, refinement distances, and Gmsh executable are also set directly in that section. All lengths are in metres in the example.

The script plots the airfoil and domain, writes `output/NACA_0012.geo`, then calls Gmsh to create `output/NACA_0012.su2` (or corresponding names for another NACA code). The `.geo` file contains geometry and mesh instructions; the `.su2` file is the generated mesh. Both are excluded from Git. The `output` folder is created automatically if needed.

The entire process, from the analytic NACA equations to the Gmsh command, can be read in order in this one file. No external airfoil coordinate file or MATLAB toolbox is required.

MIT License, copyright 2026 Camile Briard.
