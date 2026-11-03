function result = generate_naca_mesh(cfg)
%GENERATE_NACA_MESH Build a NACA 4-digit .geo file and optionally a SU2 mesh.
%   RESULT = GENERATE_NACA_MESH(CFG) builds an analytic airfoil, writes a
%   Gmsh .geo file, optionally calls Gmsh, and optionally plots the domain.
%   CFG is a scalar struct with fields listed in configs/naca0012_example.m.
%   Lengths use the unit of CFG.chord; plotting labels assume metres when
%   that unit is metres. CFG.outputDir may be absolute or project-relative.
%   RESULT.geoPath always names a written file. RESULT.su2Path is nonempty
%   only if Gmsh completed successfully; expectedSu2Path is the intended
%   mesh location regardless of whether Gmsh was run.
%
%   No SU2 solver configuration or CFD calculation is performed.

if nargin ~= 1 || ~isstruct(cfg) || ~isscalar(cfg)
    error('PROJECT_CFD:InvalidConfig', 'cfg must be a scalar struct.');
end

required = {'code','chord','nPoints','domainRadius','domainCenter', ...
    'hNear','hFar','dMin','dMax','hEdge','edgeDMin','edgeDMax', ...
    'outputDir','runGmsh','makePlots','gmshExecutable'};
for k = 1:numel(required)
    if ~isfield(cfg, required{k})
        error('PROJECT_CFD:MissingConfig', ...
            'Missing configuration field: %s.', required{k});
    end
end

validateattributes(cfg.chord, {'numeric'}, {'scalar','real','finite','positive'}, mfilename, 'cfg.chord');
validateattributes(cfg.nPoints, {'numeric'}, {'scalar','real','finite','integer','>=',21}, mfilename, 'cfg.nPoints');
validateattributes(cfg.domainRadius, {'numeric'}, {'scalar','real','finite','positive'}, mfilename, 'cfg.domainRadius');
validateattributes(cfg.domainCenter, {'numeric'}, {'vector','numel',2,'real','finite'}, mfilename, 'cfg.domainCenter');
lengthFields = {'hNear','hFar','dMin','dMax','hEdge','edgeDMin','edgeDMax'};
for k = 1:numel(lengthFields)
    field = lengthFields{k};
    validateattributes(cfg.(field), {'numeric'}, ...
        {'scalar','real','finite','positive'}, mfilename, ['cfg.' field]);
end
if ~(cfg.hEdge <= cfg.hNear && cfg.hNear < cfg.hFar && ...
        cfg.dMin < cfg.dMax && cfg.edgeDMin < cfg.edgeDMax)
    error('PROJECT_CFD:InvalidMeshSizes', ...
        'Require hEdge <= hNear < hFar, dMin < dMax, and edgeDMin < edgeDMax.');
end
validateattributes(cfg.runGmsh, {'logical'}, {'scalar'}, mfilename, 'cfg.runGmsh');
validateattributes(cfg.makePlots, {'logical'}, {'scalar'}, mfilename, 'cfg.makePlots');
cfg.outputDir = textScalar(cfg.outputDir, 'outputDir');
cfg.gmshExecutable = textScalar(cfg.gmshExecutable, 'gmshExecutable');

projectRoot = fileparts(mfilename('fullpath'));
sourcePath = fullfile(projectRoot, 'src');
oldPath = path;
cleanupPath = onCleanup(@() path(oldPath)); %#ok<NASGU>
addpath(sourcePath);

geom = geometry.naca4(cfg.code, cfg.chord, cfg.nPoints);
distanceToCenter = hypot(geom.contour(:,1) - cfg.domainCenter(1), ...
                         geom.contour(:,2) - cfg.domainCenter(2));
if any(distanceToCenter >= cfg.domainRadius)
    error('PROJECT_CFD:DomainTooSmall', ...
        'The entire airfoil must lie strictly inside the outer circle.');
end

outputDir = cfg.outputDir;
if ~isAbsolutePath(outputDir)
    outputDir = fullfile(projectRoot, outputDir);
end
if ~isfolder(outputDir)
    [ok, message] = mkdir(outputDir);
    if ~ok
        error('PROJECT_CFD:OutputDirectory', 'Cannot create output directory: %s', message);
    end
end

stem = ['naca' lower(geom.code)];
geoPath = fullfile(outputDir, [stem '.geo']);
expectedSu2Path = fullfile(outputDir, [stem '.su2']);
meshing.write_geo(geoPath, geom, cfg);

result = struct('geometry', geom, 'geoPath', geoPath, ...
    'expectedSu2Path', expectedSu2Path, 'su2Path', '', ...
    'meshGenerated', false);

if cfg.makePlots
    visualization.plot_domain(geom, cfg.domainCenter, cfg.domainRadius);
end

if cfg.runGmsh
    % Export to a unique temporary mesh so an old .su2 can never be
    % mistaken for the product of this invocation.
    temporarySu2Path = [tempname(outputDir) '.su2'];
    cleanupMesh = onCleanup(@() deleteIfExists(temporarySu2Path)); %#ok<NASGU>
    command = [shellQuote(cfg.gmshExecutable) ' -2 ' shellQuote(geoPath) ...
        ' -format su2 -o ' shellQuote(temporarySu2Path)];
    [status, output] = system(command);
    if status ~= 0 || ~isfile(temporarySu2Path)
        error('PROJECT_CFD:GmshFailed', ...
            'Gmsh did not produce a SU2 mesh (exit %d):\n%s', status, output);
    end
    [moved, message] = movefile(temporarySu2Path, expectedSu2Path, 'f');
    if ~moved
        error('PROJECT_CFD:MeshMoveFailed', ...
            'Cannot move the SU2 mesh to its final path: %s', message);
    end
    result.su2Path = expectedSu2Path;
    result.meshGenerated = true;
end
end

function deleteIfExists(filePath)
if isfile(filePath)
    delete(filePath);
end
end

function value = textScalar(value, fieldName)
if isstring(value) && isscalar(value)
    value = char(value);
end
if ~ischar(value) || ~isrow(value) || isempty(strtrim(value))
    error('PROJECT_CFD:InvalidText', '%s must be a nonempty text scalar.', fieldName);
end
end

function tf = isAbsolutePath(value)
if ispc
    tf = ~isempty(regexp(value, '^[A-Za-z]:[\\/]|^\\\\', 'once'));
else
    tf = value(1) == '/';
end
end

function quoted = shellQuote(value)
% Quote a single executable or path for MATLAB's platform shell.
if ispc
    if any(ismember(value, ['"' '%' '!' '^' '&' '|' '<' '>']))
        error('PROJECT_CFD:UnsafePath', ...
            'Windows shell paths cannot contain command metacharacters.');
    end
    quoted = ['"' value '"'];
else
    quoted = [char(39) strrep(value, char(39), ...
        [char(39) char(34) char(39) char(34) char(39)]) char(39)];
end
end
