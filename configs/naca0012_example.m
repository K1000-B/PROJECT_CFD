function cfg = naca0012_example()
%NACA0012_EXAMPLE Return a documented baseline configuration.
%   CFG = NACA0012_EXAMPLE() returns a struct for GENERATE_NACA_MESH.
%   All lengths are in the same physical unit as CFG.chord (metres here).
%   The output directory is relative to the project root.

cfg.code = '0012';
cfg.chord = 1.0;
cfg.nPoints = 161;             % Points on each surface, including both edges.

cfg.domainRadius = 20 * cfg.chord;
cfg.domainCenter = [0.5 * cfg.chord, 0];

cfg.hNear = 0.008 * cfg.chord;
cfg.hFar = 1.0 * cfg.chord;
cfg.dMin = 0.10 * cfg.chord;
cfg.dMax = 3.00 * cfg.chord;
cfg.hEdge = 0.004 * cfg.chord;
cfg.edgeDMin = 0.02 * cfg.chord;
cfg.edgeDMax = 0.20 * cfg.chord;

cfg.outputDir = fullfile('meshes', 'generated', 'NACA0012');
cfg.runGmsh = false;           % Set true to produce the SU2 mesh as well.
cfg.makePlots = true;
cfg.gmshExecutable = 'gmsh';
end
