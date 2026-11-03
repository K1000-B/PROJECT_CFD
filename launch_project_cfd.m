function fig = launch_project_cfd()
%LAUNCH_PROJECT_CFD Open a MATLAB interface for NACA geometry and meshing.
%   FIG = LAUNCH_PROJECT_CFD() opens an interactive configuration window.
%   CHORD is in metres in the example. Other length fields are entered as
%   multiples of the chord, so the baseline domain scales with CHORD.
%   "Generate .geo" writes only Gmsh geometry instructions; "Generate SU2
%   mesh" also invokes Gmsh. The returned FIG is the UI figure handle.
%   No solver or CFD simulation is started by this interface.

projectRoot = fileparts(mfilename('fullpath'));
defaults = loadDefaults(projectRoot);
defaults.outputDir = fullfile('meshes', 'generated');

fig = uifigure('Name', 'PROJECT_CFD | NACA 4-digit launcher', ...
    'Position', [100 100 960 735], 'Color', [0.97 0.98 0.99]);
main = uigridlayout(fig, [5 1]);
main.RowHeight = {50, '1x', 125, 50, 78};
main.Padding = [18 15 18 15];
main.RowSpacing = 12;

heading = uilabel(main, 'Text', 'NACA 4-digit geometry and mesh', ...
    'FontSize', 20, 'FontWeight', 'bold');
heading.Layout.Row = 1;

parameters = uigridlayout(main, [1 2]);
parameters.Layout.Row = 2;
parameters.ColumnWidth = {'1x', '1x'};
parameters.ColumnSpacing = 12;
parameters.Padding = [0 0 0 0];

geometryPanel = uipanel(parameters, 'Title', 'Airfoil and fluid domain');
geometryPanel.Layout.Column = 1;
geometryGrid = uigridlayout(geometryPanel, [6 2]);
geometryGrid.ColumnWidth = {180, '1x'};
geometryGrid.RowHeight = repmat({'1x'}, 1, 6);

meshPanel = uipanel(parameters, 'Title', 'Mesh refinement');
meshPanel.Layout.Column = 2;
meshGrid = uigridlayout(meshPanel, [7 2]);
meshGrid.ColumnWidth = {180, '1x'};
meshGrid.RowHeight = repmat({'1x'}, 1, 7);

fields.code = textField(geometryGrid, 1, 'NACA code', defaults.code);
fields.chord = numericField(geometryGrid, 2, 'Chord [m]', defaults.chord);
fields.nPoints = numericField(geometryGrid, 3, 'Points per surface', defaults.nPoints);
fields.domainRadius = numericField(geometryGrid, 4, 'Outer radius [c]', defaults.domainRadius / defaults.chord);
fields.centerX = numericField(geometryGrid, 5, 'Circle centre x [c]', defaults.domainCenter(1) / defaults.chord);
fields.centerY = numericField(geometryGrid, 6, 'Circle centre y [c]', defaults.domainCenter(2) / defaults.chord);

fields.hNear = numericField(meshGrid, 1, 'Near-wall size [c]', defaults.hNear / defaults.chord);
fields.hFar = numericField(meshGrid, 2, 'Farfield size [c]', defaults.hFar / defaults.chord);
fields.dMin = numericField(meshGrid, 3, 'Wall transition start [c]', defaults.dMin / defaults.chord);
fields.dMax = numericField(meshGrid, 4, 'Wall transition end [c]', defaults.dMax / defaults.chord);
fields.hEdge = numericField(meshGrid, 5, 'Edge size [c]', defaults.hEdge / defaults.chord);
fields.edgeDMin = numericField(meshGrid, 6, 'Edge transition start [c]', defaults.edgeDMin / defaults.chord);
fields.edgeDMax = numericField(meshGrid, 7, 'Edge transition end [c]', defaults.edgeDMax / defaults.chord);

outputPanel = uipanel(main, 'Title', 'Output and Gmsh');
outputPanel.Layout.Row = 3;
outputGrid = uigridlayout(outputPanel, [2 3]);
outputGrid.RowHeight = {'1x', '1x'};
outputGrid.ColumnWidth = {135, '1x', 95};
outputGrid.ColumnSpacing = 10;
outputGrid.Padding = [10 6 10 6];

outputLabel = uilabel(outputGrid, 'Text', 'Output directory');
outputLabel.Layout.Row = 1;
outputLabel.Layout.Column = 1;
fields.outputDir = uieditfield(outputGrid, 'text', 'Value', defaults.outputDir);
fields.outputDir.Layout.Row = 1;
fields.outputDir.Layout.Column = 2;
browseButton = uibutton(outputGrid, 'Text', 'Browse...');
browseButton.Layout.Row = 1;
browseButton.Layout.Column = 3;
browseButton.ButtonPushedFcn = @(~,~) chooseOutput();

gmshLabel = uilabel(outputGrid, 'Text', 'Gmsh executable');
gmshLabel.Layout.Row = 2;
gmshLabel.Layout.Column = 1;
fields.gmshExecutable = uieditfield(outputGrid, 'text', ...
    'Value', defaults.gmshExecutable);
fields.gmshExecutable.Layout.Row = 2;
fields.gmshExecutable.Layout.Column = 2;
gmshHint = uilabel(outputGrid, 'Text', 'PATH or file');
gmshHint.Layout.Row = 2;
gmshHint.Layout.Column = 3;

actions = uigridlayout(main, [1 4]);
actions.Layout.Row = 4;
actions.ColumnWidth = {175, 190, '1x', 145};
actions.ColumnSpacing = 12;
actions.Padding = [0 0 0 0];
geoButton = uibutton(actions, 'Text', 'Generate .geo');
geoButton.Layout.Column = 1;
geoButton.ButtonPushedFcn = @(~,~) generate(false);
meshButton = uibutton(actions, 'Text', 'Generate SU2 mesh');
meshButton.Layout.Column = 2;
meshButton.ButtonPushedFcn = @(~,~) generate(true);
fields.makePlots = uicheckbox(actions, 'Text', 'Show geometry plots', ...
    'Value', defaults.makePlots);
fields.makePlots.Layout.Column = 3;
resetButton = uibutton(actions, 'Text', 'Reset defaults');
resetButton.Layout.Column = 4;
resetButton.ButtonPushedFcn = @(~,~) resetFields();

status = uitextarea(main, 'Editable', 'off', ...
    'Value', {'Ready. Generate .geo writes geometry only; Generate SU2 mesh also runs Gmsh.'});
status.Layout.Row = 5;

    function chooseOutput()
        selected = uigetdir(projectRoot, 'Select output directory');
        if ischar(selected)
            fields.outputDir.Value = selected;
        end
    end

    function resetFields()
        fields.code.Value = defaults.code;
        fields.chord.Value = defaults.chord;
        fields.nPoints.Value = defaults.nPoints;
        fields.domainRadius.Value = defaults.domainRadius / defaults.chord;
        fields.centerX.Value = defaults.domainCenter(1) / defaults.chord;
        fields.centerY.Value = defaults.domainCenter(2) / defaults.chord;
        names = {'hNear','hFar','dMin','dMax','hEdge','edgeDMin','edgeDMax'};
        for k = 1:numel(names)
            fields.(names{k}).Value = defaults.(names{k}) / defaults.chord;
        end
        fields.outputDir.Value = defaults.outputDir;
        fields.gmshExecutable.Value = defaults.gmshExecutable;
        fields.makePlots.Value = defaults.makePlots;
        status.Value = {'Defaults restored.'};
    end

    function generate(runGmsh)
        cfg = defaults;
        cfg.code = strtrim(fields.code.Value);
        cfg.chord = fields.chord.Value;
        cfg.nPoints = fields.nPoints.Value;
        cfg.domainRadius = fields.domainRadius.Value * cfg.chord;
        cfg.domainCenter = [fields.centerX.Value, fields.centerY.Value] * cfg.chord;
        names = {'hNear','hFar','dMin','dMax','hEdge','edgeDMin','edgeDMax'};
        for k = 1:numel(names)
            cfg.(names{k}) = fields.(names{k}).Value * cfg.chord;
        end
        cfg.outputDir = strtrim(fields.outputDir.Value);
        cfg.gmshExecutable = strtrim(fields.gmshExecutable.Value);
        cfg.makePlots = fields.makePlots.Value;
        cfg.runGmsh = runGmsh;

        geoButton.Enable = 'off';
        meshButton.Enable = 'off';
        status.Value = {'Working...'};
        drawnow;
        try
            result = generate_naca_mesh(cfg);
            if result.meshGenerated
                status.Value = {['Geometry: ' result.geoPath], ...
                    ['SU2 mesh: ' result.su2Path]};
            else
                status.Value = {['Geometry: ' result.geoPath], ...
                    'SU2 mesh not requested.'};
            end
        catch err
            status.Value = {['Generation failed: ' err.message]};
            uialert(fig, err.message, 'PROJECT_CFD error');
        end
        geoButton.Enable = 'on';
        meshButton.Enable = 'on';
    end
end

function cfg = loadDefaults(projectRoot)
oldPath = path;
restorePath = onCleanup(@() path(oldPath)); %#ok<NASGU>
addpath(fullfile(projectRoot, 'configs'));
cfg = naca0012_example();
end

function field = numericField(grid, row, labelText, value)
label = uilabel(grid, 'Text', labelText);
label.Layout.Row = row;
label.Layout.Column = 1;
field = uieditfield(grid, 'numeric', 'Value', value);
field.Layout.Row = row;
field.Layout.Column = 2;
end

function field = textField(grid, row, labelText, value)
label = uilabel(grid, 'Text', labelText);
label.Layout.Row = row;
label.Layout.Column = 1;
field = uieditfield(grid, 'text', 'Value', value);
field.Layout.Row = row;
field.Layout.Column = 2;
end
