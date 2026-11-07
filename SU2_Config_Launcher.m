function SU2_Config_Launcher
% SU2_CONFIG_LAUNCHER  GUI for creating SU2 v8.x configuration files.
% Run: SU2_Config_Launcher
% One standalone MATLAB file. No extra toolbox required (uifigure needed).
% For the full SU2 catalog use 'Download SU2 template' on the Advanced tab.
% No CFD simulation is launched by this application.

app = struct();
app.meshPath = '';
app.bc = initialBC();
app.advanced = builtInCatalog();
app.filtered = 1:numel(app.advanced);
app.selectedAdvanced = 0;
app.templateName = 'Built-in catalog (offline)';
app.lastFile = '';
app.loading = false;
% Reuse a previously downloaded official template on subsequent launches.
localTemplate = fullfile(fileparts(mfilename('fullpath')), ...
    'SU2_config_template_v8.6.0.cfg');
if exist(localTemplate,'file')==2
    try
        app.advanced=parseTemplate(localTemplate);
        app.templateName=localTemplate;
    catch
        % Standalone/offline catalog remains available as fallback.
    end
end
ui = struct();

fig = uifigure('Name','SU2 Config Launcher | MATLAB', ...
    'Position',[60 60 1420 850],'Color',[0.96 0.97 0.99]);
uilabel(fig,'Text','SU2 CONFIG LAUNCHER', ...
    'Position',[18 807 300 27],'FontWeight','bold','FontSize',17);
uilabel(fig,'Text','SU2 v8.6 • guided configuration + full template catalog', ...
    'Position',[323 807 570 27],'FontColor',[.33 .4 .51]);
meshButton = uibutton(fig,'Text','Open .su2 mesh', ...
    'Position',[18 764 140 29],'ButtonPushedFcn',@chooseMesh);
meshLabel = uilabel(fig,'Text','No mesh loaded (you can still create a CFG)', ...
    'Position',[171 764 1042 28],'FontColor',[.24 .38 .52]);
uibutton(fig,'Text','Import .cfg','Position',[1095 807 140 28], ...
    'ButtonPushedFcn',@importCFG);
uibutton(fig,'Text','Export .cfg','Position',[1242 807 156 28], ...
    'ButtonPushedFcn',@exportCFG);
status = uilabel(fig,'Text','Ready','Position',[20 7 1380 26], ...
    'FontColor',[.15 .33 .48]);
tg = uitabgroup(fig,'Position',[15 42 1390 716]);
tCase = uitab(tg,'Title','1. Physics & case');
tBC = uitab(tg,'Title','2. Boundaries');
tNum = uitab(tg,'Title','3. Numerics & time');
tOut = uitab(tg,'Title','4. Convergence & output');
tAdv = uitab(tg,'Title','5. Advanced catalog');
tPreview = uitab(tg,'Title','6. CFG preview');

% ---- Physics / case ----------------------------------------------
section(tCase,26,653,'SIMULATION');
put(tCase,'solver','Solver',{'EULER','NAVIER_STOKES','RANS', ...
    'INC_EULER','INC_NAVIER_STOKES','INC_RANS', ...
    'FEM_EULER','FEM_NAVIER_STOKES','FEM_RANS','FEM_LES', ...
    'NEMO_EULER','NEMO_NAVIER_STOKES','HEAT_EQUATION_FVM','ELASTICITY'}, ...
    [28 609], 'Specialized FEM/NEMO/heat/elasticity require additional options and a compatible mesh.');
put(tCase,'turb','Turbulence model',{'NONE','SA','SST'},[28 563], ...
    'Only meaningful with RANS or INC_RANS.');
put(tCase,'trans','Transition model',{'NONE','LM'},[28 517], ...
    'Langtry-Menter transition model requires compatible turbulence setup.');
put(tCase,'sgs','LES subgrid model',{'NONE','IMPLICIT_LES','SMAGORINSKY','WALE','VREMAN'}, ...
    [28 471],'For FEM_LES only.');
put(tCase,'fluid','Fluid model',{'STANDARD_AIR','IDEAL_GAS','CONSTANT_DENSITY', ...
    'INC_IDEAL_GAS','VW_GAS','PR_GAS','COOLPROP'},[28 425], ...
    'Not every fluid model works with every solver.');
put(tCase,'init','Initialization',{'REYNOLDS','TD_CONDITIONS'},[28 379], ...
    'Reynolds-based viscosity setting or thermodynamic-condition initialization.');
put(tCase,'restart', 'Restart existing solution?', false,[28 333], ...
    'To restart, set SOLUTION_FILENAME in Advanced catalog.');

section(tCase,524,653,'FREESTREAM / FLUID PROPERTIES');
put(tCase,'mach','Mach number',0.2,[525 609], ...
    'Compressible freestream Mach; Mach=0 is not a useful compressible freestream.');
put(tCase,'aoa','AOA inside SU2 [deg]',0,[525 563], ...
    'Keep zero if the airfoil has already been rotated in Gmsh.');
put(tCase,'pressure','Static pressure [Pa]',101325,[525 517], ...
    'FREESTREAM_PRESSURE for compressible solvers.');
put(tCase,'temp','Static temperature [K]',288.15,[525 471], ...
    'FREESTREAM_TEMPERATURE.');
put(tCase,'reynolds','Reynolds number',1e6,[525 425], ...
    'Based on REYNOLDS_LENGTH, only if initialization is REYNOLDS.');
put(tCase,'reLength','Reynolds length [m]',1,[525 379], ...
    'Usually the airfoil chord.');
put(tCase,'gamma','Gamma',1.4,[525 333], ...
    'For IDEAL_GAS; STANDARD_AIR uses its own constants.');
put(tCase,'gasConstant','Gas constant [J/kg/K]',287.058,[525 287], ...
    'For an ideal gas, if it is enabled.');
put(tCase,'viscosity','Viscosity model',{'SUTHERLAND','CONSTANT_VISCOSITY'}, ...
    [525 241],'Viscous solvers.');
put(tCase,'muConstant','Constant viscosity [Pa.s]',1.716e-5,[525 195], ...
    'Only used for CONSTANT_VISCOSITY.');

section(tCase,1008,653,'INCOMPRESSIBLE / REFERENCE');
put(tCase,'incDensity','Initial density [kg/m3]',1.225,[1008 609], ...
    'Used only for incompressible solvers.');
put(tCase,'incU','Initial Ux [m/s]',50,[1008 563], ...
    'Incompressible initial velocity, x component.');
put(tCase,'incV','Initial Uy [m/s]',0,[1008 517], ...
    'Incompressible initial velocity, y component.');
put(tCase,'refLength','Reference length [m]',1,[1008 471], ...
    'Used for nondimensional aerodynamic moments.');
put(tCase,'refArea','Reference area [m2]',1,[1008 425], ...
    'For 2D, commonly c times unit span.');
put(tCase,'momentX','Moment origin x [m]',0.25,[1008 379], ...
    'Choose the same physical pivot as the geometry if applicable.');
put(tCase,'momentY','Moment origin y [m]',0,[1008 333], ...
    'Moment reference location in laboratory coordinates.');
put(tCase,'meshName','Mesh filename in SU2','mesh.su2',[1008 287], ...
    'The path as seen by SU2 (e.g. inside Docker, not macOS).');
put(tCase,'copyMesh','Copy mesh beside .cfg',true,[1008 241], ...
    'Recommended when the .cfg and mesh run in the same Docker working directory.');
uilabel(tCase,'Text',sprintf(['Geometry-based incidence: AOA = 0 is normally required.\n' ...
    'SU2 does not automatically infer the rotation used in your Gmsh mesh.']), ...
    'Position',[1009 133 352 79],'FontColor',[.3 .38 .49]);
section(tCase,28,266,'QUICK START PRESETS');
uibutton(tCase,'Text','Euler','Position',[28 223 110 31], ...
    'ButtonPushedFcn',@(~,~) applyPreset('Euler'));
uibutton(tCase,'Text','Laminar NS','Position',[145 223 145 31], ...
    'ButtonPushedFcn',@(~,~) applyPreset('Laminar NS'));
uibutton(tCase,'Text','RANS SA','Position',[297 223 115 31], ...
    'ButtonPushedFcn',@(~,~) applyPreset('RANS SA'));
uibutton(tCase,'Text','RANS SST','Position',[28 185 130 31], ...
    'ButtonPushedFcn',@(~,~) applyPreset('RANS SST'));
uilabel(tCase,'Text',['Presets set consistent model combinations. ' ...
    'Check Reynolds, CFL, boundary conditions and mesh quality.'], ...
    'Position',[28 100 438 70],'FontColor',[.31 .4 .52]);

% ---- Boundary conditions -------------------------------------------------
section(tBC,24,658,'BOUNDARY MARKERS READ FROM THE .SU2 MESH');
uilabel(tBC,'Text',['Edit each marker. For parameterized conditions, enter ' ...
    'the numeric payload AFTER the marker name.'], ...
    'Position',[25 622 1260 27]);
bcTypes = {'Farfield','Euler wall','Adiabatic no-slip','Isothermal no-slip', ...
    'Symmetry','Inlet total','Outlet pressure','Supersonic inlet', ...
    'Supersonic outlet','Inlet velocity (INC)'};
bcTable = uitable(tBC,'Position',[24 175 1060 438], ...
    'ColumnName',{'Mesh marker','Condition','Parameters','Monitor forces'}, ...
    'ColumnFormat',{'char',bcTypes,'char','logical'}, ...
    'ColumnEditable',[false true true true], ...
    'ColumnWidth',{210 220 470 135}, ...
    'CellEditCallback',@editBC);
uilabel(tBC,'Text','Parameter examples', ...
    'Position',[1102 568 254 26],'FontWeight','bold');
examples = sprintf([ ...
    'Farfield / symmetry / Euler wall:\n    leave empty\n\n' ...
    'Adiabatic no-slip:\n    0 (heat flux in W/m2)\n\n' ...
    'Isothermal no-slip:\n    300 (wall temperature K)\n\n' ...
    'Inlet total (compressible):\n    T0, p0, dx, dy, dz\n\n' ...
    'Outlet pressure:\n    p_static (Pa)\n\n' ...
    'Supersonic inlet:\n    T, p, ux, uy, uz\n\n' ...
    'Inlet velocity (INC):\n    T, U, dx, dy, dz']);
uitextarea(tBC,'Value',regexp(examples,'\n','split'), ...
    'Position',[1102 181 260 383],'Editable','off');
uilabel(tBC,'Text',['Tip: for external flow, inlet/outlet/top/bottom can all be ' ...
    'Farfield. Other conditions require values and compatibility checks.'], ...
    'Position',[24 114 1290 40],'FontColor',[.22 .36 .5]);
uibutton(tBC,'Text','Reset boundary assignments', ...
    'Position',[26 67 244 31],'ButtonPushedFcn',@resetBC);

% ---- Numerics ------------------------------------------------------------
section(tNum,26,655,'SPATIAL SCHEME & LINEAR SOLVER');
put(tNum,'flux','Convective scheme',{'ROE','AUSM','AUSMPLUSUP','AUSMPLUSUP2', ...
    'HLLC','JST','JST_KE','LAX-FRIEDRICH','SLAU','SLAU2','L2ROE','LMROE'}, ...
    [28 611],'Check solver compatibility in the installed SU2 version.');
put(tNum,'muscl','MUSCL second order',true,[28 565], ...
    'MUSCL_FLOW=YES enables second-order reconstruction.');
put(tNum,'limiter','Slope limiter',{'VENKATAKRISHNAN','BARTH_JESPERSEN', ...
    'VAN_ALBADA_EDGE','NONE'},[28 519], 'Limit numerical oscillations near shocks.');
put(tNum,'grad','Gradient method',{'WEIGHTED_LEAST_SQUARES','GREEN_GAUSS'}, ...
    [28 473],'Spatial gradient reconstruction method.');
put(tNum,'implicit','Flow time discretization', ...
    {'EULER_IMPLICIT','EULER_EXPLICIT','RUNGE-KUTTA_EXPLICIT'},[28 427], ...
    'Implicit typically used for steady CFD.');
put(tNum,'linear','Linear solver',{'FGMRES','BCGSTAB','RESTARTED_FGMRES','SMOOTHER'}, ...
    [28 381],'Krylov solver for implicit formulations.');
put(tNum,'preconditioner','Preconditioner',{'ILU','LU_SGS','JACOBI','LINELET'}, ...
    [28 335],'Preconditioner for implicit linear solve.');
put(tNum,'linearTol','Linear tolerance',1e-6,[28 289], ...
    'LINEAR_SOLVER_ERROR.');
put(tNum,'linearIter','Max linear iterations',10,[28 243], ...
    'LINEAR_SOLVER_ITER.');
put(tNum,'mg','Multigrid levels',0,[28 197], ...
    'MGLEVEL=0 disables multigrid.');

section(tNum,520,655,'CFL / ADAPTIVE CFL');
put(tNum,'cfl','Initial CFL',2,[521 611], ...
    'Start conservatively for compressible transonic shock problems.');
put(tNum,'cflAdapt','Adaptive CFL',false,[521 565], ...
    'Automatically changes CFL using CFL_ADAPT_PARAM.');
put(tNum,'cflDown','CFL decrease factor',0.1,[521 519], ...
    'Factor-down in CFL_ADAPT_PARAM.');
put(tNum,'cflUp','CFL increase factor',1.2,[521 473], ...
    'Factor-up in CFL_ADAPT_PARAM.');
put(tNum,'cflMin','Minimum CFL',1,[521 427], ...
    'Lower permitted CFL.');
put(tNum,'cflMax','Maximum CFL',100,[521 381], ...
    'Initial limit 100 (adjust only after convergence tests).');
put(tNum,'cflLinear','Accepted linear tolerance',0.001,[521 335], ...
    'Convergence threshold in CFL_ADAPT_PARAM.');
put(tNum,'cflStart','Adaptive starting iteration',0,[521 289], ...
    'Start of the adaptive algorithm.');

section(tNum,1008,655,'PHYSICAL TIME');
put(tNum,'time','Time marching',{'NO','TIME_STEPPING', ...
    'DUAL_TIME_STEPPING-1ST_ORDER','DUAL_TIME_STEPPING-2ND_ORDER', ...
    'HARMONIC_BALANCE'},[1008 611], ...
    'NO is steady. Other modes require a physical time step / period.');
put(tNum,'dt','Time step [s]',1e-4,[1008 565], ...
    'Used for unsteady time-marching with UNST_CFL_NUMBER=0.');
put(tNum,'maxTime','Physical time [s]',0.1,[1008 519], ...
    'MAX_TIME.');
put(tNum,'timeIter','Time iterations',1000,[1008 473], ...
    'TIME_ITER.');
put(tNum,'innerIter','Inner iterations',1000,[1008 427], ...
    'Steady iterations, or pseudo-time iterations per physical step.');
put(tNum,'unstCFL','Unsteady CFL',0,[1008 381], ...
    'UNST_CFL_NUMBER=0 uses prescribed TIME_STEP.');
uilabel(tNum,'Text',['Rigid pitching / moving meshes, gusts, harmonic balance ' ...
    'and other special models are available in the Advanced catalog.'], ...
    'Position',[1008 268 348 91],'FontColor',[.31 .4 .52]);

% ---- Outputs ------------------------------------------------------------
section(tOut,27,653,'CONVERGENCE');
put(tOut,'convField','Convergence field',{'RMS_DENSITY','RMS_PRESSURE','DRAG','LIFT'}, ...
    [28 609],'Select a residual / aerodynamic coefficient compatible with the solver.');
put(tOut,'convMin','Minimum log10 residual',-8,[28 563], ...
    'Convergence threshold in log10 units.');
put(tOut,'convStart','Convergence start iteration',10,[28 517], ...
    'Delay convergence test until this iteration.');
put(tOut,'convCauchy','Cauchy window size',100,[28 471], ...
    'Used if an aerodynamic coefficient criterion is selected.');
put(tOut,'convCauchyEps','Cauchy tolerance',1e-8,[28 425], ...
    'Threshold for coefficient variation.');
section(tOut,524,653,'OUTPUT FILES');
put(tOut,'writeRestart','Restart file',true,[525 609], ...
    'Writes a restart solution.');
put(tOut,'writeVolume','Paraview volume',true,[525 563], ...
    'Writes volume fields in ParaView format.');
put(tOut,'writeSurface','Paraview surface',true,[525 517], ...
    'Writes surface fields.');
put(tOut,'writeCSV','Surface CSV',true,[525 471], ...
    'Useful for Cp and aerodynamic post-processing.');
put(tOut,'outputFreq','Output frequency',100,[525 425], ...
    'Frequency for the enabled output files.');
put(tOut,'screenFreq','Screen frequency',1,[525 379], ...
    'SCREEN_WRT_FREQ_INNER.');
put(tOut,'historyFreq','History frequency',1,[525 333], ...
    'HISTORY_WRT_FREQ_INNER.');
put(tOut,'historyName','Convergence history name','history',[525 287], ...
    'File basename without extension.');
put(tOut,'volumeName','Volume solution name','flow',[525 241], ...
    'File basename without extension.');
put(tOut,'surfaceName','Surface solution name','surface_flow',[525 195], ...
    'File basename without extension.');
section(tOut,1008,653,'OUTPUT VARIABLES');
put(tOut,'volumeVars','VOLUME_OUTPUT', ...
    '(COORDINATES, SOLUTION, PRIMITIVE)',[1008 609], ...
    'SU2 variable groups; use SU2_CFD -d config.cfg for accepted fields.');
put(tOut,'historyVars','HISTORY_OUTPUT', ...
    '(ITER, RMS_RES, AERO_COEFF)',[1008 563], ...
    'History output groups; actual compatibility is solver-dependent.');
put(tOut,'screenVars','SCREEN_OUTPUT', ...
    '(INNER_ITER, RMS_DENSITY, RMS_MOMENTUM-X, RMS_MOMENTUM-Y, RMS_ENERGY)', ...
    [1008 517],'Screen fields vary by solver.');
put(tOut,'restartName','Restart filename','restart_flow',[1008 471], ...
    'Restart output name.');
put(tOut,'plotMarkers','Plot monitored markers',true,[1008 425], ...
    'MARKER_PLOTTING selects monitored surfaces.');
put(tOut,'solutionName','Restart input filename','solution_flow.dat',[1008 379], ...
    'SOLUTION_FILENAME used when RESTART_SOL = YES.');
uilabel(tOut,'Text','You can edit output variable lists manually, or find further options in the Advanced catalog.', ...
    'Position',[1008 319 348 74],'FontColor',[.31 .4 .52]);

% ---- Advanced catalog ---------------------------------------------------
uilabel(tAdv,'Text','Search options / descriptions:', ...
    'Position',[22 655 230 28],'FontWeight','bold');
advSearch = uieditfield(tAdv,'text','Value','', ...
    'Position',[253 654 540 29],'ValueChangedFcn',@refreshAdvanced);
sectionSelector = uidropdown(tAdv,'Items',{'All sections'},'Value','All sections', ...
    'Position',[812 654 260 29],'ValueChangedFcn',@refreshAdvanced);
uibutton(tAdv,'Text','Load template.cfg','Position',[1084 654 135 29], ...
    'ButtonPushedFcn',@chooseTemplate);
uibutton(tAdv,'Text','Download SU2 v8.6 template','Position',[1226 654 143 29], ...
    'ButtonPushedFcn',@downloadTemplate);
advTable = uitable(tAdv,'Position',[22 213 1345 428], ...
    'ColumnName',{'Use','Option','Value','Section'}, ...
    'ColumnEditable',[true false true false], ...
    'ColumnWidth',{55 275 425 548}, ...
    'CellSelectionCallback',@selectAdvanced, ...
    'CellEditCallback',@editAdvanced);
advDescription = uitextarea(tAdv,'Value',{'Select an option to read its description.'}, ...
    'Position',[22 122 1345 79],'Editable','off');
uilabel(tAdv,'Text','New custom option','Position',[22 81 145 24]);
newKey = uieditfield(tAdv,'text','Position',[164 80 265 27]);
uilabel(tAdv,'Text','Value','Position',[441 81 45 24]);
newValue = uieditfield(tAdv,'text','Position',[484 80 430 27]);
uibutton(tAdv,'Text','Add / update override','Position',[927 80 215 28], ...
    'ButtonPushedFcn',@addAdvanced);
uibutton(tAdv,'Text','Disable all overrides','Position',[1150 80 214 28], ...
    'ButtonPushedFcn',@clearOverrides);
advNote = uilabel(tAdv,'Text','Advanced options override guided parameters with the same key. Use carefully.', ...
    'Position',[23 39 1325 27],'FontColor',[.6 .28 .15]);

% ---- Preview ------------------------------------------------------------
uibutton(tPreview,'Text','Refresh CFG preview','Position',[24 649 201 32], ...
    'ButtonPushedFcn',@refreshPreview);
uibutton(tPreview,'Text','Export current configuration','Position',[238 649 247 32], ...
    'ButtonPushedFcn',@exportCFG);
preview = uitextarea(tPreview,'Value',{'Generating preview...'}, ...
    'Position',[22 68 1342 568],'Editable','off', ...
    'FontName','Menlo','FontSize',12);
previewNote = uilabel(tPreview,'Text','', ...
    'Position',[22 19 1333 42],'FontColor',[.47 .31 .16]);

sectionSelector.Items=[{'All sections'},unique({app.advanced.section},'stable')];
refreshBoundaryTable(); refreshAdvanced(); refreshPreview();

% ------- UI helpers ------------------------------------------------------
    function section(parent,x,y,str)
        uilabel(parent,'Text',str,'Position',[x y 410 24], ...
            'FontWeight','bold','FontColor',[.19 .35 .57],'FontSize',13);
    end
    function put(parent,key,label,value,xy,helpText)
        x=xy(1); y=xy(2);
        labelWidth = 172;
        ctlWidth = 260;
        if x>990, labelWidth=164;ctlWidth=184;end
        uilabel(parent,'Text',label,'Position',[x y labelWidth 26], ...
            'Tooltip',helpText);
        if islogical(value)
            h=uicheckbox(parent,'Text','', 'Value',value, ...
                'Position',[x+labelWidth+8 y 30 27], ...
                'ValueChangedFcn',@changed,'Tooltip',helpText);
        elseif iscell(value)
            h=uidropdown(parent,'Items',value,'Value',value{1}, ...
                'Position',[x+labelWidth+8 y ctlWidth 28], ...
                'ValueChangedFcn',@changed,'Tooltip',helpText);
        elseif isnumeric(value)
            h=uieditfield(parent,'numeric','Value',value, ...
                'Position',[x+labelWidth+8 y ctlWidth 28], ...
                'ValueChangedFcn',@changed,'Tooltip',helpText);
        else
            h=uieditfield(parent,'text','Value',char(value), ...
                'Position',[x+labelWidth+8 y ctlWidth 28], ...
                'ValueChangedFcn',@changed,'Tooltip',helpText);
        end
        ui.(key)=h;
    end
    function applyPreset(name)
        app.loading=true;
        ui.mach.Value=0.2;ui.aoa.Value=0;
        ui.fluid.Value='STANDARD_AIR';
        ui.turb.Value='NONE';ui.trans.Value='NONE';
        ui.time.Value='NO';ui.init.Value='REYNOLDS';
        ui.cflAdapt.Value=false;ui.cfl.Value=2;
        switch name
            case 'Euler',ui.solver.Value='EULER';
            case 'Laminar NS',ui.solver.Value='NAVIER_STOKES';
            case 'RANS SA',ui.solver.Value='RANS';ui.turb.Value='SA';
            case 'RANS SST',ui.solver.Value='RANS';ui.turb.Value='SST';
        end
        app.loading=false;
        adjustBCForSolver();refreshPreview();
        status.Text=['Preset applied: ' name];
    end
    function changed(src,~)
        if app.loading,return;end
        if isequal(src,ui.solver)
            adjustBCForSolver();
            if isIncompressible(ui.solver.Value)
                ui.convField.Value='RMS_PRESSURE';
                ui.screenVars.Value='(INNER_ITER, RMS_PRESSURE, RMS_MOMENTUM-X, RMS_MOMENTUM-Y)';
            else
                ui.convField.Value='RMS_DENSITY';
                ui.screenVars.Value='(INNER_ITER, RMS_DENSITY, RMS_MOMENTUM-X, RMS_MOMENTUM-Y, RMS_ENERGY)';
            end
        end
        refreshPreview();
    end
    function chooseMesh(~,~)
        [fn,pn]=uigetfile({'*.su2','SU2 mesh (*.su2)'},'Choose SU2 mesh');
        if isequal(fn,0),return;end
        try
            names=readMeshMarkers(fullfile(pn,fn));
            if isempty(names),error('No MARKER_TAG entries found in the SU2 file.');end
            app.meshPath=fullfile(pn,fn);
            ui.meshName.Value=fn;
            old=app.bc;
            b=emptyBC();
            for k=1:numel(names)
                m=names{k}; b(k)=defaultBoundary(m,ui.solver.Value); %#ok<AGROW>
                pos=find(strcmp({old.name},m),1);
                if ~isempty(pos),b(k)=old(pos);end
            end
            app.bc=b;
            meshLabel.Text=sprintf('%s  |  %d boundary markers',app.meshPath,numel(names));
            refreshBoundaryTable(); refreshPreview();
            status.Text='Mesh markers loaded. Check every condition before exporting.';
        catch ME
            uialert(fig,ME.message,'Mesh import failed');
        end
    end
    function adjustBCForSolver()
        for k=1:numel(app.bc)
            if strcmp(app.bc(k).type,'Euler wall') && isViscous(ui.solver.Value)
                app.bc(k).type='Adiabatic no-slip';app.bc(k).params='0';
            elseif strcmp(app.bc(k).type,'Adiabatic no-slip') && ~isViscous(ui.solver.Value)
                app.bc(k).type='Euler wall';app.bc(k).params='';
            end
        end
        refreshBoundaryTable();
    end
    function refreshBoundaryTable()
        data=cell(numel(app.bc),4);
        for k=1:numel(app.bc)
            data(k,:)={app.bc(k).name,app.bc(k).type,app.bc(k).params,app.bc(k).monitor};
        end
        bcTable.Data=data;
    end
    function editBC(~,event)
        k=event.Indices(1);col=event.Indices(2);
        if k<1 || k>numel(app.bc),return;end
        switch col
            case 2
                app.bc(k).type=char(event.NewData);
                app.bc(k).params=boundaryDefaults(app.bc(k).type);
            case 3
                app.bc(k).params=char(event.NewData);
            case 4
                app.bc(k).monitor=logical(event.NewData);
        end
        refreshBoundaryTable();refreshPreview();
    end
    function resetBC(~,~)
        for k=1:numel(app.bc)
            app.bc(k)=defaultBoundary(app.bc(k).name,ui.solver.Value);
        end
        refreshBoundaryTable();refreshPreview();
    end
    function refreshAdvanced(~,~)
        query=lower(strtrim(char(advSearch.Value)));
        s=sectionSelector.Value;
        entries=app.advanced;
        idx=[];
        for k=1:numel(entries)
            matches=isempty(query) || contains(lower([entries(k).key ' ' entries(k).description]),query);
            if matches && (strcmp(s,'All sections') || strcmp(entries(k).section,s))
                idx(end+1)=k; %#ok<AGROW>
            end
        end
        app.filtered=idx;
        data=cell(numel(idx),4);
        for j=1:numel(idx)
            e=entries(idx(j));
            data(j,:)={e.enabled,e.key,e.value,e.section};
        end
        advTable.Data=data;
        advNote.Text=sprintf('%d / %d options • %d enabled • %s • Advanced overrides take precedence.', ...
            numel(idx),numel(entries),sum([entries.enabled]),app.templateName);
    end
    function selectAdvanced(~,event)
        if isempty(event.Indices),return;end
        row=event.Indices(1,1);
        if row<1 || row>numel(app.filtered),return;end
        app.selectedAdvanced=app.filtered(row);
        e=app.advanced(app.selectedAdvanced);
        advDescription.Value={['OPTION: ' e.key '   |   SECTION: ' e.section], ...
            ['CURRENT: ' e.value], e.description};
    end
    function editAdvanced(~,event)
        row=event.Indices(1);col=event.Indices(2);
        if row<1 || row>numel(app.filtered),return;end
        k=app.filtered(row);
        if col==1
            app.advanced(k).enabled=logical(event.NewData);
        elseif col==3
            app.advanced(k).value=strtrim(char(string(event.NewData)));
        end
        refreshAdvanced();refreshPreview();
    end
    function addAdvanced(~,~)
        key=upper(strtrim(char(newKey.Value)));
        value=strtrim(char(newValue.Value));
        if isempty(regexp(key,'^[A-Z][A-Z0-9_]*$','once')) || isempty(value)
            uialert(fig,'Enter a valid SU2 KEY and a nonempty value.','Invalid option');return
        end
        k=find(strcmp({app.advanced.key},key),1);
        if isempty(k)
            app.advanced(end+1)=makeEntry(key,value,'User-defined','Custom option; compatibility not verified.',true);
        else
            app.advanced(k).value=value;app.advanced(k).enabled=true;
        end
        advSearch.Value='';sectionSelector.Value='All sections';
        refreshAdvanced();refreshPreview();
        status.Text=['Activated advanced override ' key];
    end
    function clearOverrides(~,~)
        for k=1:numel(app.advanced),app.advanced(k).enabled=false;end
        refreshAdvanced();refreshPreview();
    end
    function chooseTemplate(~,~)
        [fn,pn]=uigetfile({'*.cfg','SU2 template (*.cfg)'}, ...
            'Select an official SU2 config_template.cfg');
        if isequal(fn,0),return;end
        installTemplate(fullfile(pn,fn));
    end
    function downloadTemplate(~,~)
        url='https://raw.githubusercontent.com/su2code/SU2/v8.6.0/config_template.cfg';
        try
            dirPath=fileparts(mfilename('fullpath'));
            localPath=fullfile(dirPath,'SU2_config_template_v8.6.0.cfg');
            websave(localPath,url);
            installTemplate(localPath);
        catch ME
            uialert(fig,['Could not download the official template: ' ME.message newline ...
                'Download it manually from the SU2 GitHub v8.6.0 release.'], ...
                'Download failed');
        end
    end
    function installTemplate(path)
        try
            newEntries=parseTemplate(path);
            if numel(newEntries)<50
                error('This file does not look like an official SU2 config_template.cfg.');
            end
            old=app.advanced;
            for k=1:numel(newEntries)
                j=find(strcmp({old.key},newEntries(k).key),1);
                if ~isempty(j) && old(j).enabled
                    newEntries(k).value=old(j).value;
                    newEntries(k).enabled=true;
                end
            end
            % Preserve enabled custom options absent from the new version.
            for j=1:numel(old)
                if old(j).enabled && ~any(strcmp({newEntries.key},old(j).key))
                    newEntries(end+1)=old(j); %#ok<AGROW>
                end
            end
            app.advanced=newEntries;
            app.templateName=path;
            cats=unique({newEntries.section},'stable');
            sectionSelector.Items=[{'All sections'},cats];
            sectionSelector.Value='All sections';
            refreshAdvanced();refreshPreview();
            status.Text=sprintf('Official template loaded: %d unique options.',numel(newEntries));
        catch ME
            uialert(fig,ME.message,'Template parse failed');
        end
    end
    function importCFG(~,~)
        [fn,pn]=uigetfile('*.cfg','Import an existing SU2 configuration');
        if isequal(fn,0),return;end
        try
            values=readConfigFile(fullfile(pn,fn));
            app.loading=true;
            guided=mappingGuided();
            for k=1:size(guided,1)
                key=guided{k,1}; field=guided{k,2};
                j=find(strcmp({values.key},key),1,'last');
                if isempty(j),continue;end
                val=values(j).value;
                h=ui.(field);
                if isa(h,'matlab.ui.control.CheckBox')
                    h.Value=strcmpi(val,'YES');
                elseif isa(h,'matlab.ui.control.NumericEditField')
                    x=str2double(val);if isfinite(x),h.Value=x;end
                elseif isa(h,'matlab.ui.control.DropDown')
                    if any(strcmp(h.Items,val)),h.Value=val;end
                else
                    h.Value=val;
                end
            end
            % Convert the imported time flag if it is missing in the template.
            if any(strcmp({values.key},'TIME_MARCHING'))
                v=values(find(strcmp({values.key},'TIME_MARCHING'),1,'last')).value;
                if any(strcmp(ui.time.Items,v)),ui.time.Value=v;end
            end
            % Import grouped outputs and selected tuple values without
            % leaving contradictory hidden advanced overrides.
            j=find(strcmp({values.key},'OUTPUT_FILES'),1,'last');
            if ~isempty(j)
                outputList=upper(values(j).value);
                ui.writeRestart.Value=contains(outputList,'RESTART');
                ui.writeVolume.Value=~isempty(regexp(outputList,'(^|[,\s])PARAVIEW([,\s]|$)','once'));
                ui.writeSurface.Value=contains(outputList,'SURFACE_PARAVIEW');
                ui.writeCSV.Value=contains(outputList,'SURFACE_CSV');
            end
            j=find(strcmp({values.key},'OUTPUT_WRT_FREQ'),1,'last');
            if ~isempty(j)
                terms=splitNumericPayload(regexprep(values(j).value,'[()]',''));
                if ~isempty(terms) && all(isfinite(str2double(terms)))
                    nums=str2double(terms);
                    if all(nums==nums(1)),ui.outputFreq.Value=nums(1);end
                end
            end
            j=find(strcmp({values.key},'CFL_ADAPT_PARAM'),1,'last');
            if ~isempty(j)
                terms=splitNumericPayload(regexprep(values(j).value,'[()]',''));
                if numel(terms)>=4 && all(isfinite(str2double(terms)))
                    nums=str2double(terms);
                    ui.cflDown.Value=nums(1);ui.cflUp.Value=nums(2);
                    ui.cflMin.Value=nums(3);ui.cflMax.Value=nums(4);
                    if numel(nums)>=5,ui.cflLinear.Value=nums(5);end
                    if numel(nums)>=6,ui.cflStart.Value=nums(6);end
                end
            end
            j=find(strcmp({values.key},'INC_VELOCITY_INIT'),1,'last');
            if ~isempty(j)
                terms=splitNumericPayload(regexprep(values(j).value,'[()]',''));
                if numel(terms)>=2 && all(isfinite(str2double(terms(1:2))))
                    nums=str2double(terms(1:2));
                    ui.incU.Value=nums(1);ui.incV.Value=nums(2);
                end
            end
            % Only truly advanced / unsupported keys remain overrides.
            guidedKeys=guided(:,1);
            bcKeys=boundaryKeys();
            generatedKeys={'TIME_DOMAIN','OUTPUT_FILES','OUTPUT_WRT_FREQ', ...
                'CFL_ADAPT_PARAM','INC_VELOCITY_INIT','MESH_FORMAT', ...
                'MARKER_MONITORING','MARKER_PLOTTING'};
            for k=1:numel(values)
                key=values(k).key;val=values(k).value;
                if ismember(key,guidedKeys) || ismember(key,bcKeys) || ...
                        ismember(key,generatedKeys)
                    continue
                end
                j=find(strcmp({app.advanced.key},key),1);
                if isempty(j)
                    app.advanced(end+1)=makeEntry(key,val,'Imported CFG', ...
                        'Imported configuration entry: verify for your installed SU2 version.',true);
                else
                    app.advanced(j).value=val;app.advanced(j).enabled=true;
                end
            end
            importedBC=readBoundaryFromConfig(values);
            if ~isempty(importedBC)
                if isempty(app.meshPath)
                    app.bc=importedBC;
                else
                    for k=1:numel(app.bc)
                        j=find(strcmpi({importedBC.name},app.bc(k).name),1);
                        if ~isempty(j)
                            app.bc(k).type=importedBC(j).type;
                            app.bc(k).params=importedBC(j).params;
                            app.bc(k).monitor=importedBC(j).monitor;
                        end
                    end
                end
            end
            app.lastFile=fullfile(pn,fn);
            app.loading=false;
            refreshBoundaryTable();refreshAdvanced();refreshPreview();
            status.Text='CFG imported. Inspect advanced overrides and BCs before export.';
        catch ME
            app.loading=false;
            uialert(fig,ME.message,'Import failed');
        end
    end
    function refreshPreview(~,~)
        try
            [txt,warn]=renderCFG(ui,app.bc,app.advanced);
            preview.Value=cellstr(splitlines(string(txt)));
            if isempty(warn)
                previewNote.Text='No major consistency warnings (not a full SU2 solver validation).';
            else
                previewNote.Text=strjoin(warn(1:min(2,numel(warn))),' | ');
            end
            status.Text=sprintf('Preview updated • %d markers • %d active advanced overrides.', ...
                numel(app.bc),sum([app.advanced.enabled]));
        catch ME
            previewNote.Text=['Invalid configuration: ' ME.message];
            status.Text=ME.message;
        end
    end
    function exportCFG(~,~)
        try
            [txt,warn]=renderCFG(ui,app.bc,app.advanced);
            if ~isempty(warn)
                message=strjoin(warn,newline);
                answ=uiconfirm(fig,['Review these warnings:' newline newline message newline newline ...
                    'Export anyway?'],'CFG checks', ...
                    'Options',{'Export anyway','Cancel'},'DefaultOption',2,'CancelOption',2);
                if ~strcmp(answ,'Export anyway'),return;end
            end
            baseDir=pwd;
            if ~isempty(app.meshPath),baseDir=fileparts(app.meshPath);end
            [fn,pn]=uiputfile('*.cfg','Export SU2 configuration',fullfile(baseDir,'NACA_run.cfg'));
            if isequal(fn,0),return;end
            outputPath=fullfile(pn,fn);
            meshForSU2=strtrim(char(ui.meshName.Value));
            if ui.copyMesh.Value && ~isempty(app.meshPath)
                dest=fullfile(pn,meshForSU2);
                if ~strcmp(app.meshPath,dest)
                    if contains(meshForSU2,'/') || contains(meshForSU2,'\')
                        error('When copying the mesh, MESH_FILENAME must be a simple filename.');
                    end
                    [ok,msg]=copyfile(app.meshPath,dest);
                    if ~ok,error('Cannot copy mesh: %s',msg);end
                end
            end
            fid=fopen(outputPath,'w');
            if fid==-1,error('Cannot open %s for writing.',outputPath);end
            cleanup=onCleanup(@() fclose(fid));
            fprintf(fid,'%s',txt);
            clear cleanup
            app.lastFile=outputPath;
            status.Text=['Exported ' outputPath];
            uialert(fig,['Configuration exported:' newline outputPath newline newline ...
                'Run in the directory containing the mesh, or use a Docker-visible path:' newline ...
                'SU2_CFD ' fn],'Export successful','Icon','success');
        catch ME
            uialert(fig,ME.message,'CFG export failed');
        end
    end
end

% ==================== DATA AND PARSERS ====================
function b=emptyBC()
b=struct('name',{},'type',{},'params',{},'monitor',{});
end
function b=initialBC()
b=[defaultBoundary('airfoil','EULER'), ...
   defaultBoundary('inlet','EULER'),defaultBoundary('outlet','EULER'), ...
   defaultBoundary('top','EULER'),defaultBoundary('bottom','EULER')];
end
function b=defaultBoundary(name,solver)
wall=strcmpi(name,'airfoil') || contains(lower(name),'wall');
if wall && isViscous(solver)
    typ='Adiabatic no-slip';
elseif wall
    typ='Euler wall';
else
    typ='Farfield';
end
b=struct('name',name,'type',typ,'params',boundaryDefaults(typ), ...
    'monitor',wall);
end
function value=boundaryDefaults(kind)
switch kind
    case 'Adiabatic no-slip', value='0';
    case 'Isothermal no-slip', value='300';
    case 'Inlet total',value='288.15, 101325, 1, 0, 0';
    case 'Outlet pressure',value='101325';
    case 'Supersonic inlet',value='288.15, 101325, 300, 0, 0';
    case 'Inlet velocity (INC)',value='288.15, 50, 1, 0, 0';
    otherwise,value='';
end
end
function tf=isIncompressible(solver)
tf=startsWith(char(solver),'INC_');
end
function tf=isViscous(solver)
s=char(solver);
tf=contains(s,'NAVIER_STOKES') || contains(s,'RANS') || strcmp(s,'FEM_LES');
end
function names=readMeshMarkers(file)
fid=fopen(file,'r');
if fid<0,error('Cannot open mesh: %s',file);end
cleanup=onCleanup(@() fclose(fid));
names={};
while ~feof(fid)
    t=fgetl(fid);
    if ~ischar(t),break;end
    m=regexp(t,'^\s*MARKER_TAG\s*=\s*(\S+)','tokens','once');
    if ~isempty(m)
        name=strtrim(m{1});
        if ~any(strcmp(names,name)),names{end+1}=name;end %#ok<AGROW>
    end
end
end
function vals=readConfigFile(file)
fid=fopen(file,'r');
if fid<0,error('Cannot read %s',file);end
cleanup=onCleanup(@() fclose(fid));
vals=struct('key',{},'value',{});
while ~feof(fid)
    l=fgetl(fid);if ~ischar(l),break;end
    l=regexprep(l,'%.*$','');
    m=regexp(l,'^\s*([A-Za-z][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$','tokens','once');
    if isempty(m),continue;end
    vals(end+1)=struct('key',upper(m{1}),'value',strtrim(m{2})); %#ok<AGROW>
end
end
function entries=parseTemplate(path)
% Parse the actual SU2 config_template.cfg. The descriptions and defaults
% are taken from the selected version, not invented by the GUI.
fid=fopen(path,'r');if fid<0,error('Cannot read template');end
cleanup=onCleanup(@() fclose(fid));
entries=struct('key',{},'value',{},'section',{},'description',{},'enabled',{});
section='General'; comments={};
while ~feof(fid)
    line=fgetl(fid);if ~ischar(line),break;end
    hdr=regexp(line,'^\s*%\s*-{3,}\s*(.*?)\s*-{3,}\s*%?\s*$','tokens','once');
    if ~isempty(hdr)
        section=strtrim(hdr{1});comments={};continue
    end
    if startsWith(strtrim(line),'%')
        comment=regexprep(line,'^\s*%\s?','');
        if ~isempty(strtrim(comment)) && ~all(comment=='%')
            comments{end+1}=strtrim(comment); %#ok<AGROW>
            if numel(comments)>8,comments=comments(end-7:end);end
        elseif isempty(strtrim(comment))
            comments={};
        end
        continue
    end
    match=regexp(line,'^\s*([A-Z][A-Z0-9_]*)\s*=\s*(.*?)\s*$','tokens','once');
    if ~isempty(match)
        key=match{1};value=strtrim(match{2});
        if ~any(strcmp({entries.key},key))
            description=strjoin(comments,' ');
            entries(end+1)=makeEntry(key,value,section,description,false); %#ok<AGROW>
        end
        comments={};
    elseif ~isempty(strtrim(line))
        comments={};
    end
end
end
function e=makeEntry(key,val,sec,desc,enabled)
e=struct('key',char(key),'value',char(val),'section',char(sec), ...
    'description',char(desc),'enabled',logical(enabled));
end
function entries=builtInCatalog()
% Standalone fallback when the official template is unavailable.
% The full catalog can be loaded with the template button in the GUI.
raw={...
'SA_OPTIONS','NONE','RANS','SA corrections: NEGATIVE, EDWARDS, QCR2000, COMPRESSIBILITY, ROTATION';...
'SST_OPTIONS','NONE','RANS','SST options: V2003m, V1994m, VORTICITY, KATO_LAUNDER';...
'LM_OPTIONS','NONE','Transition','Langtry-Menter transition correlations';...
'FREESTREAM_TURBULENCEINTENSITY','0.05','Turbulence','Freestream turbulence intensity';...
'FREESTREAM_TURB2LAMVISCRATIO','10.0','Turbulence','Freestream turbulent to laminar viscosity ratio';...
'HYBRID_RANSLES','SA_DDES','LES / DES','SA_DES, SA_DDES, SA_ZDES, SA_EDDES';...
'DES_CONST','0.65','LES / DES','DES model constant';...
'LES_FILTER_WIDTH','-1','LES / DES','LES filter width';...
'MAX_UPDATE_FLOW','0.2','Numerics','Nonlinear flow state update limiter';...
'REF_DIMENSIONALIZATION','DIMENSIONAL','Fluid','Compressible reference scaling';...
'PRANDTL_LAM','0.72','Fluid','Laminar Prandtl number';...
'PRANDTL_TURB','0.9','Fluid','Turbulent Prandtl number';...
'MU_REF','1.716E-5','Fluid','Sutherland reference viscosity';...
'MU_T_REF','273.15','Fluid','Sutherland reference temperature';...
'SUTHERLAND_CONSTANT','110.4','Fluid','Sutherland law constant';...
'TIME_DISCRE_TURB','EULER_IMPLICIT','Numerics','Time discretization for turbulent transport';...
'UNST_CFL_NUMBER','0','Time','Unsteady CFL; zero uses TIME_STEP';...
'TIME_INSTANCES','1','Time','Harmonic Balance time instances';...
'HB_PERIOD','-1','Time','Harmonic Balance period';...
'OMEGA_HB','(0,1.0,-1.0)','Time','Harmonic Balance angular frequencies';...
'GRID_MOVEMENT','NONE','Moving mesh','Motion switch (special setup required)';...
'MOTION_ORIGIN','(0,0,0)','Moving mesh','Origin of dynamic mesh motion';...
'PITCHING_OMEGA','(0,0,0)','Moving mesh','Pitching angular frequency';...
'PITCHING_AMPL','(0,0,0)','Moving mesh','Pitching amplitude';...
'INLET_TYPE','TOTAL_CONDITIONS','Boundaries','Subsonic compressible inlet type';...
'INC_INLET_TYPE','VELOCITY_INLET','Boundaries','Incompressible inlet type';...
'INC_OUTLET_TYPE','PRESSURE_OUTLET','Boundaries','Incompressible outlet type';...
'CONV_WINDOW_FIELD','(TAVG_DRAG, TAVG_LIFT)','Convergence','Windowed convergence variables';...
'WINDOW_CAUCHY_CRIT','NO','Convergence','Enable windowed convergence';...
'CONV_WINDOW_CAUCHY_EPS','1e-3','Convergence','Windowed Cauchy tolerance';...
'WINDOW_START_ITER','500','Convergence','Begin windowed time averaging';...
'WINDOW_FUNCTION','SQUARE','Convergence','SQUARE, HANN, HANN_SQUARE or BUMP';...
'LIMITER_ITER','999999','Numerics','Number of steps with active limiter';...
'VENKAT_LIMITER_COEFF','0.05','Numerics','Venkatakrishnan limiter control';...
'JST_SENSOR_COEFF','(0.5,0.02)','Numerics','JST dissipation sensor coefficients';...
'MGCYCLE','V_CYCLE','Multigrid','V_CYCLE, W_CYCLE, FULLMG_CYCLE';...
'MG_PRE_SMOOTH','(2,2,2,2)','Multigrid','Multigrid presmoothing passes';...
'MG_POST_SMOOTH','(2,2,2,2)','Multigrid','Multigrid postsmoothing passes';...
'SCREEN_WRT_FREQ_TIME','1','Output','Screen frequency in physical time';...
'HISTORY_WRT_FREQ_TIME','1','Output','History frequency in physical time';...
'VOLUME_OUTPUT','(COORDINATES, SOLUTION, PRIMITIVE)','Output','Solution groups written to files';...
'HISTORY_OUTPUT','(ITER, RMS_RES)','Output','History output groups';...
'SCREEN_OUTPUT','(INNER_ITER, RMS_DENSITY)','Output','Screen output fields';...
'SURFACE_CSV_FILENAME','surface_flow','Output','Surface CSV basename';...
'SOLUTION_FILENAME','restart_flow.dat','Restart','Input restart file';...
'RESTART_ITER','0','Restart','Unsteady restart time iteration';...
'WRT_RESTART_COMPACT','YES','Restart','Save compact restart variables';...
'AXISYMMETRIC','NO','Physics','Axisymmetric 2D simulation';...
'GRAVITY_FORCE','NO','Physics','Enable gravitational force';...
'FIXED_CL_MODE','NO','Optimization','Fixed lift driver';...
'TARGET_CL','0.8','Optimization','Target CL for fixed lift';...
'TARGET_MACH','0.8','Optimization','Target Mach (specific applications)';...
'INC_DENSITY_MODEL','CONSTANT','Incompressible','CONSTANT, BOUSSINESQ, VARIABLE';...
'INC_ENERGY_EQUATION','NO','Incompressible','Solve incompressible energy equation';...
'INC_TEMPERATURE_INIT','288.15','Incompressible','Initial incompressible temperature';...
'INC_NONDIM','INITIAL_VALUES','Incompressible','Incompressible nondimensionalization';...
'CONDUCTIVITY_MODEL','CONSTANT_PRANDTL','Fluid','Heat conductivity model';...
'INC_INLET_DAMPING','0.1','Incompressible','Incompressible inlet damping';...
'INC_OUTLET_DAMPING','0.1','Incompressible','Incompressible outlet damping'};
entries=struct('key',{},'value',{},'section',{},'description',{},'enabled',{});
for k=1:size(raw,1)
    entries(end+1)=makeEntry(raw{k,1},raw{k,2},raw{k,3},raw{k,4},false); %#ok<AGROW>
end
end

% ==================== CFG GENERATOR ====================
function [txt,warnings]=renderCFG(ui,bc,adv)
% Guided parameters are collected into structured sections.
% Active advanced options override same-key guided values, once.
warnings={};
solver=char(ui.solver.Value);
inc=isIncompressible(solver);
visc=isViscous(solver);
if any(strcmp(solver,{'FEM_EULER','FEM_NAVIER_STOKES','FEM_RANS', ...
        'FEM_LES','NEMO_EULER','NEMO_NAVIER_STOKES', ...
        'HEAT_EQUATION_FVM','ELASTICITY'}))
    warnings{end+1}='Specialized solver selected: additional mandatory physics/mesh options may be required.';
end
if ~inc && ui.mach.Value==0
    warnings{end+1}='Compressible Mach=0: use an incompressible model or specify a nonzero Mach.';
end
if ui.aoa.Value~=0
    warnings{end+1}='Nonzero SU2 AOA: check for double incidence if the geometry is already rotated.';
end
if inc && strcmp(ui.fluid.Value,'STANDARD_AIR')
    warnings{end+1}='Incompressible solver with STANDARD_AIR: consider CONSTANT_DENSITY/INC_IDEAL_GAS.';
end
if ~inc && strcmp(ui.fluid.Value,'CONSTANT_DENSITY')
    warnings{end+1}='Compressible solver with CONSTANT_DENSITY: choose an appropriate compressible fluid model.';
end
if visc && strcmp(ui.init.Value,'REYNOLDS') && ui.reynolds.Value<=0
    error('Reynolds number must be >0 for Reynolds-based viscous initialization.');
end
if strcmp(ui.time.Value,'HARMONIC_BALANCE')
    warnings{end+1}='Harmonic Balance requires HB_PERIOD/TIME_INSTANCES and a compatible SU2 setup.';
end
if ui.muscl.Value && strcmp(ui.limiter.Value,'NONE')
    warnings{end+1}='Second-order MUSCL without limiter may oscillate near shocks.';
end
if ui.cflAdapt.Value && ui.cflMax.Value>1000
    warnings{end+1}='High adaptive CFL limit: validate stability across transonic shocks.';
end
if ~ui.copyMesh.Value && ~isempty(regexp(ui.meshName.Value,'^/Users/','once'))
    warnings{end+1}='Mac absolute mesh path will not exist inside Docker unless explicitly mounted.';
end
requiredPositive={'pressure','temp','refLength','refArea','linearTol','linearIter', ...
    'innerIter','outputFreq','screenFreq','historyFreq'};
for k=1:numel(requiredPositive)
    v=ui.(requiredPositive{k}).Value;
    if ~(isfinite(v)&&v>0),error('%s must be positive and finite.',requiredPositive{k});end
end
if ui.cfl.Value<=0 || ui.cflMin.Value<=0 || ui.cflMax.Value<ui.cflMin.Value
    error('CFL values must be positive with max >= min.');
end
if ui.cflUp.Value<=0 || ui.cflDown.Value<=0
    error('Adaptive CFL factors must be positive.');
end
if ui.cflAdapt.Value && ui.cflUp.Value<=1
    warnings{end+1}='Adaptive CFL increase factor <=1: CFL cannot increase normally.';
end
if ui.refLength.Value<=0 || ui.refArea.Value<=0
    error('Reference length and area must be positive.');
end
if isempty(strtrim(char(ui.meshName.Value)))
    error('Provide MESH_FILENAME (the path as seen by SU2).');
end
p=cell(0,3);
p=pair(p,'CASE','SOLVER',solver);
p=pair(p,'CASE','MATH_PROBLEM','DIRECT');
p=pair(p,'CASE','RESTART_SOL',yn(ui.restart.Value));
if ui.restart.Value
    p=pair(p,'CASE','SOLUTION_FILENAME',char(ui.solutionName.Value));
end
p=pair(p,'CASE','SYSTEM_MEASUREMENTS','SI');
if any(strcmp(solver,{'RANS','INC_RANS','FEM_RANS'}))
    p=pair(p,'MODELS','KIND_TURB_MODEL',ui.turb.Value);
    if strcmp(ui.turb.Value,'NONE')
        warnings{end+1}='RANS selected with turbulence model NONE.';
    end
    p=pair(p,'MODELS','KIND_TRANS_MODEL',ui.trans.Value);
else
    if ~strcmp(ui.turb.Value,'NONE')
        warnings{end+1}='Turbulence model selection is not written outside RANS.';
    end
end
if strcmp(solver,'FEM_LES')
    p=pair(p,'MODELS','KIND_SGS_MODEL',ui.sgs.Value);
end
if inc
    p=pair(p,'INITIAL CONDITIONS','INC_DENSITY_MODEL','CONSTANT');
    p=pair(p,'INITIAL CONDITIONS','INC_DENSITY_INIT',fmt(ui.incDensity.Value));
    p=pair(p,'INITIAL CONDITIONS','INC_VELOCITY_INIT', ...
        sprintf('( %s, %s, 0.0 )',fmt(ui.incU.Value),fmt(ui.incV.Value)));
    p=pair(p,'INITIAL CONDITIONS','INC_NONDIM','INITIAL_VALUES');
else
    p=pair(p,'INITIAL CONDITIONS','MACH_NUMBER',fmt(ui.mach.Value));
    p=pair(p,'INITIAL CONDITIONS','AOA',fmt(ui.aoa.Value));
    p=pair(p,'INITIAL CONDITIONS','FREESTREAM_PRESSURE',fmt(ui.pressure.Value));
    p=pair(p,'INITIAL CONDITIONS','FREESTREAM_TEMPERATURE',fmt(ui.temp.Value));
    p=pair(p,'INITIAL CONDITIONS','FREESTREAM_OPTION','TEMPERATURE_FS');
end
p=pair(p,'FLUID','FLUID_MODEL',ui.fluid.Value);
if strcmp(ui.fluid.Value,'IDEAL_GAS')
    p=pair(p,'FLUID','GAMMA_VALUE',fmt(ui.gamma.Value));
    p=pair(p,'FLUID','GAS_CONSTANT',fmt(ui.gasConstant.Value));
end
if visc
    if ~inc
        p=pair(p,'INITIAL CONDITIONS','INIT_OPTION',ui.init.Value);
        if strcmp(ui.init.Value,'REYNOLDS')
            p=pair(p,'INITIAL CONDITIONS','REYNOLDS_NUMBER',fmt(ui.reynolds.Value));
            p=pair(p,'INITIAL CONDITIONS','REYNOLDS_LENGTH',fmt(ui.reLength.Value));
        end
    end
    p=pair(p,'FLUID','VISCOSITY_MODEL',ui.viscosity.Value);
    if strcmp(ui.viscosity.Value,'CONSTANT_VISCOSITY')
        p=pair(p,'FLUID','MU_CONSTANT',fmt(ui.muConstant.Value));
    end
end
p=pair(p,'REFERENCES','REF_LENGTH',fmt(ui.refLength.Value));
p=pair(p,'REFERENCES','REF_AREA',fmt(ui.refArea.Value));
p=pair(p,'REFERENCES','REF_ORIGIN_MOMENT_X',fmt(ui.momentX.Value));
p=pair(p,'REFERENCES','REF_ORIGIN_MOMENT_Y',fmt(ui.momentY.Value));
p=pair(p,'REFERENCES','REF_ORIGIN_MOMENT_Z','0.0');

% Markers: group by SU2 BC type and check scalar/tuple payload lengths.
markers={'MARKER_FAR','MARKER_EULER','MARKER_HEATFLUX', ...
    'MARKER_ISOTHERMAL','MARKER_SYM','MARKER_INLET','MARKER_OUTLET', ...
    'MARKER_SUPERSONIC_INLET','MARKER_SUPERSONIC_OUTLET'};
for i=1:numel(markers)
    chunks={};
    for j=1:numel(bc)
        [key,payload,nargs]=boundarySpec(bc(j));
        if ~strcmp(key,markers{i}),continue;end
        if ~isempty(regexp(bc(j).name,'[(),\s]','once'))
            error('Marker name "%s" contains invalid characters.',bc(j).name);
        end
        tok=splitNumericPayload(payload);
        if numel(tok)~=nargs
            error('Marker %s (%s): requires %d numeric parameters; received %d.', ...
                bc(j).name,bc(j).type,nargs,numel(tok));
        end
        if ~isempty(tok) && any(~isfinite(str2double(tok)))
            error('Marker %s: boundary parameters must be finite numbers.',bc(j).name);
        end
        if nargs==0
            chunks{end+1}=bc(j).name; %#ok<AGROW>
        else
            chunks{end+1}=strjoin([{bc(j).name},tok],', '); %#ok<AGROW>
        end
    end
    if ~isempty(chunks)
        p=pair(p,'BOUNDARIES',markers{i},['( ' strjoin(chunks,', ') ' )']);
    end
end
if isempty(bc)
    warnings{end+1}='No boundary markers selected: load a SU2 mesh before running.';
end
allNames={bc.name};
if numel(unique(allNames))~=numel(allNames)
    error('Duplicate boundary marker names.');
end
if any(strcmp({bc.type},'Inlet total'))
    if inc,error('Inlet total is a compressible BC; use Inlet velocity (INC).');end
    p=pair(p,'BOUNDARIES','INLET_TYPE','TOTAL_CONDITIONS');
end
if any(strcmp({bc.type},'Inlet velocity (INC)'))
    if ~inc,error('Inlet velocity (INC) requires an incompressible solver.');end
    p=pair(p,'BOUNDARIES','INC_INLET_TYPE','VELOCITY_INLET');
end
if any(strcmp({bc.type},'Outlet pressure')) && inc
    p=pair(p,'BOUNDARIES','INC_OUTLET_TYPE','PRESSURE_OUTLET');
end
if inc && any(ismember({bc.type},{'Supersonic inlet','Supersonic outlet'}))
    error('Supersonic inlet/outlet is incompatible with INC_* solvers.');
end
if ~visc && any(ismember({bc.type},{'Adiabatic no-slip','Isothermal no-slip'}))
    error('No-slip wall boundary requires a viscous solver.');
end
if visc && any(strcmp({bc.type},'Euler wall'))
    warnings{end+1}='Euler wall with viscous solver: this is a slip wall, not a viscous no-slip wall.';
end
watch={};
for j=1:numel(bc)
    if bc(j).monitor,watch{end+1}=bc(j).name;end %#ok<AGROW>
end
if ~isempty(watch)
    p=pair(p,'MONITORING','MARKER_MONITORING',['( ' strjoin(watch,', ') ' )']);
    if ui.plotMarkers.Value
        p=pair(p,'MONITORING','MARKER_PLOTTING',['( ' strjoin(watch,', ') ' )']);
    end
end

% Time integration and numerics.
steady=strcmp(ui.time.Value,'NO');
p=pair(p,'TIME','TIME_DOMAIN',yn(~steady));
p=pair(p,'TIME','TIME_MARCHING',ui.time.Value);
if steady
    p=pair(p,'TIME','INNER_ITER',fmt(round(ui.innerIter.Value)));
else
    if ui.dt.Value<=0,error('Physical TIME_STEP must be >0 for unsteady runs.');end
    p=pair(p,'TIME','TIME_STEP',fmt(ui.dt.Value));
    p=pair(p,'TIME','TIME_ITER',fmt(round(ui.timeIter.Value)));
    p=pair(p,'TIME','INNER_ITER',fmt(round(ui.innerIter.Value)));
    p=pair(p,'TIME','MAX_TIME',fmt(ui.maxTime.Value));
    p=pair(p,'TIME','UNST_CFL_NUMBER',fmt(ui.unstCFL.Value));
end
p=pair(p,'NUMERICS','CONV_NUM_METHOD_FLOW',ui.flux.Value);
p=pair(p,'NUMERICS','MUSCL_FLOW',yn(ui.muscl.Value));
p=pair(p,'NUMERICS','SLOPE_LIMITER_FLOW',ui.limiter.Value);
p=pair(p,'NUMERICS','NUM_METHOD_GRAD_RECON',ui.grad.Value);
p=pair(p,'NUMERICS','TIME_DISCRE_FLOW',ui.implicit.Value);
if any(strcmp(solver,{'RANS','INC_RANS'}))
    p=pair(p,'NUMERICS','TIME_DISCRE_TURB','EULER_IMPLICIT');
end
p=pair(p,'NUMERICS','CFL_NUMBER',fmt(ui.cfl.Value));
p=pair(p,'NUMERICS','CFL_ADAPT',yn(ui.cflAdapt.Value));
if ui.cflAdapt.Value
    terms=[ui.cflDown.Value,ui.cflUp.Value,ui.cflMin.Value, ...
        ui.cflMax.Value,ui.cflLinear.Value,ui.cflStart.Value];
    p=pair(p,'NUMERICS','CFL_ADAPT_PARAM', ...
        ['( ' strjoin(arrayfun(@fmt,terms,'UniformOutput',false),', ') ' )']);
end
p=pair(p,'NUMERICS','LINEAR_SOLVER',ui.linear.Value);
p=pair(p,'NUMERICS','LINEAR_SOLVER_PREC',ui.preconditioner.Value);
p=pair(p,'NUMERICS','LINEAR_SOLVER_ERROR',fmt(ui.linearTol.Value));
p=pair(p,'NUMERICS','LINEAR_SOLVER_ITER',fmt(round(ui.linearIter.Value)));
p=pair(p,'NUMERICS','MGLEVEL',fmt(round(ui.mg.Value)));

% Convergence / output.
p=pair(p,'CONVERGENCE','CONV_FIELD',ui.convField.Value);
p=pair(p,'CONVERGENCE','CONV_RESIDUAL_MINVAL',fmt(ui.convMin.Value));
p=pair(p,'CONVERGENCE','CONV_STARTITER',fmt(round(ui.convStart.Value)));
p=pair(p,'CONVERGENCE','CONV_CAUCHY_ELEMS',fmt(round(ui.convCauchy.Value)));
p=pair(p,'CONVERGENCE','CONV_CAUCHY_EPS',fmt(ui.convCauchyEps.Value));
p=pair(p,'FILES','MESH_FILENAME',char(ui.meshName.Value));
p=pair(p,'FILES','MESH_FORMAT','SU2');
outputs={};
if ui.writeRestart.Value,outputs{end+1}='RESTART';end
if ui.writeVolume.Value,outputs{end+1}='PARAVIEW';end
if ui.writeSurface.Value,outputs{end+1}='SURFACE_PARAVIEW';end
if ui.writeCSV.Value,outputs{end+1}='SURFACE_CSV';end
if isempty(outputs),outputs={'NONE'};end
p=pair(p,'FILES','OUTPUT_FILES',['( ' strjoin(outputs,', ') ' )']);
if ~strcmp(outputs{1},'NONE')
    freq=repmat(round(ui.outputFreq.Value),1,numel(outputs));
    p=pair(p,'FILES','OUTPUT_WRT_FREQ', ...
        ['( ' strjoin(arrayfun(@fmt,freq,'UniformOutput',false),', ') ' )']);
end
p=pair(p,'FILES','CONV_FILENAME',char(ui.historyName.Value));
p=pair(p,'FILES','VOLUME_FILENAME',char(ui.volumeName.Value));
p=pair(p,'FILES','SURFACE_FILENAME',char(ui.surfaceName.Value));
p=pair(p,'FILES','RESTART_FILENAME',char(ui.restartName.Value));
p=pair(p,'FILES','HISTORY_OUTPUT',char(ui.historyVars.Value));
p=pair(p,'FILES','SCREEN_OUTPUT',char(ui.screenVars.Value));
p=pair(p,'FILES','VOLUME_OUTPUT',char(ui.volumeVars.Value));
p=pair(p,'FILES','SCREEN_WRT_FREQ_INNER',fmt(round(ui.screenFreq.Value)));
p=pair(p,'FILES','HISTORY_WRT_FREQ_INNER',fmt(round(ui.historyFreq.Value)));

% Apply explicit advanced overrides, preserving only one entry per key.
for k=1:numel(adv)
    if ~adv(k).enabled,continue;end
    key=adv(k).key; val=adv(k).value;
    if isempty(strtrim(val)),error('Advanced option %s has an empty value.',key);end
    pos=find(strcmp(p(:,2),key),1);
    if isempty(pos)
        p=pair(p,'ADVANCED',key,val);
    else
        p{pos,3}=val;
        warnings{end+1}=sprintf('Advanced %s overrides the guided value.',key); %#ok<AGROW>
    end
end

% Compose ASCII .cfg with sections. No duplicate parameter keys.
lines={'% SU2 configuration generated by SU2_Config_Launcher.m', ...
       '% SU2 reference: v8.6.0; validate with the installed solver.', ...
       '% For a mesh rotated geometrically, keep AOA = 0.', ...
       ''};
last='';
for k=1:size(p,1)
    sec=p{k,1};
    if ~strcmp(sec,last)
        lines{end+1}=['% --- ' sec ' ---']; %#ok<AGROW>
        last=sec;
    end
    lines{end+1}=sprintf('%-31s= %s',p{k,2},p{k,3}); %#ok<AGROW>
end
lines{end+1}='';
txt=strjoin(lines,newline);
end
function p=pair(p,section,key,value)
p(end+1,:)={char(section),char(key),char(value)};
end
function text=fmt(x)
text=sprintf('%.15g',x);
end
function out=yn(value)
if value,out='YES';else,out='NO';end
end
function tok=splitNumericPayload(payload)
payload=strtrim(char(payload));
if isempty(payload),tok={};return;end
tok=strtrim(strsplit(payload,','));
end
function [key,payload,nargs]=boundarySpec(b)
payload=b.params;
switch b.type
    case 'Farfield',key='MARKER_FAR';nargs=0;
    case 'Euler wall',key='MARKER_EULER';nargs=0;
    case 'Adiabatic no-slip',key='MARKER_HEATFLUX';nargs=1;
    case 'Isothermal no-slip',key='MARKER_ISOTHERMAL';nargs=1;
    case 'Symmetry',key='MARKER_SYM';nargs=0;
    case 'Inlet total',key='MARKER_INLET';nargs=5;
    case 'Inlet velocity (INC)',key='MARKER_INLET';nargs=5;
    case 'Outlet pressure',key='MARKER_OUTLET';nargs=1;
    case 'Supersonic inlet',key='MARKER_SUPERSONIC_INLET';nargs=5;
    case 'Supersonic outlet',key='MARKER_SUPERSONIC_OUTLET';nargs=0;
    otherwise,error('Unsupported boundary type %s',b.type);
end
end
function keys=boundaryKeys()
keys={'MARKER_FAR','MARKER_EULER','MARKER_HEATFLUX', ...
    'MARKER_ISOTHERMAL','MARKER_SYM','MARKER_INLET','MARKER_OUTLET', ...
    'MARKER_SUPERSONIC_INLET','MARKER_SUPERSONIC_OUTLET', ...
    'MARKER_MONITORING','MARKER_PLOTTING'};
end
function b=readBoundaryFromConfig(vals)
% Basic parser for imported MARKER_* tuples. Preserves common BCs;
% check complex inlet types and imported advanced options manually.
b=emptyBC();
keys=boundaryKeys();
keys=keys(1:9);
types={'Farfield','Euler wall','Adiabatic no-slip','Isothermal no-slip', ...
    'Symmetry','Inlet total','Outlet pressure','Supersonic inlet','Supersonic outlet'};
widths=[1,1,2,2,1,6,2,6,1];
for i=1:numel(keys)
    j=find(strcmp({vals.key},keys{i}),1,'last');
    if isempty(j),continue;end
    tokens=splitNumericPayload(strrep(strrep(vals(j).value,'(',''),')',''));
    w=widths(i);
    if isempty(tokens)||strcmpi(strtrim(tokens{1}),'NONE'),continue;end
    if mod(numel(tokens),w)~=0,continue;end
    for n=1:w:numel(tokens)
        name=strtrim(tokens{n});
        if isempty(name),continue;end
        x=defaultBoundary(name,'EULER');
        x.type=types{i};
        x.params=strjoin(tokens(n+1:n+w-1),', ');
        x.monitor=strcmpi(name,'airfoil');
        b(end+1)=x; %#ok<AGROW>
    end
end
j=find(strcmp({vals.key},'MARKER_MONITORING'),1,'last');
if ~isempty(j)
    tags=splitNumericPayload(strrep(strrep(vals(j).value,'(',''),')',''));
    for i=1:numel(b),b(i).monitor=any(strcmp(tags,b(i).name));end
end
end
function mapping=mappingGuided()
% Keys imported directly into visible controls; everything else is kept
% as an advanced override, to preserve specialized case information.
mapping={...
'SOLVER','solver';'KIND_TURB_MODEL','turb';'KIND_TRANS_MODEL','trans';
'KIND_SGS_MODEL','sgs';'FLUID_MODEL','fluid';'INIT_OPTION','init';
'RESTART_SOL','restart';'MACH_NUMBER','mach';'AOA','aoa';
'FREESTREAM_PRESSURE','pressure';'FREESTREAM_TEMPERATURE','temp';
'REYNOLDS_NUMBER','reynolds';'REYNOLDS_LENGTH','reLength';
'GAMMA_VALUE','gamma';'GAS_CONSTANT','gasConstant';
'VISCOSITY_MODEL','viscosity';'MU_CONSTANT','muConstant';
'INC_DENSITY_INIT','incDensity';'REF_LENGTH','refLength';
'REF_AREA','refArea';'REF_ORIGIN_MOMENT_X','momentX';
'REF_ORIGIN_MOMENT_Y','momentY';'MESH_FILENAME','meshName';
'CONV_NUM_METHOD_FLOW','flux';'MUSCL_FLOW','muscl';
'SLOPE_LIMITER_FLOW','limiter';'NUM_METHOD_GRAD_RECON','grad';
'TIME_DISCRE_FLOW','implicit';'LINEAR_SOLVER','linear';
'LINEAR_SOLVER_PREC','preconditioner';'LINEAR_SOLVER_ERROR','linearTol';
'LINEAR_SOLVER_ITER','linearIter';'MGLEVEL','mg';
'CFL_NUMBER','cfl';'CFL_ADAPT','cflAdapt';
'TIME_MARCHING','time';'TIME_STEP','dt';'MAX_TIME','maxTime';
'TIME_ITER','timeIter';'INNER_ITER','innerIter';
'UNST_CFL_NUMBER','unstCFL';'CONV_FIELD','convField';
'CONV_RESIDUAL_MINVAL','convMin';'CONV_STARTITER','convStart';
'CONV_CAUCHY_ELEMS','convCauchy';'CONV_CAUCHY_EPS','convCauchyEps';
'SCREEN_WRT_FREQ_INNER','screenFreq';
'HISTORY_WRT_FREQ_INNER','historyFreq';'CONV_FILENAME','historyName';
'VOLUME_FILENAME','volumeName';'SURFACE_FILENAME','surfaceName';
'RESTART_FILENAME','restartName';'SOLUTION_FILENAME','solutionName';'VOLUME_OUTPUT','volumeVars';
'HISTORY_OUTPUT','historyVars';'SCREEN_OUTPUT','screenVars'};
end
