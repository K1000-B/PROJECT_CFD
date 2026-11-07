
function NACA_Mesh_Editor
% NACA_MESH_EDITOR - Interactive 2D mesh setup for Gmsh -> SU2.
% One file. Run: NACA_Mesh_Editor
% Requires MATLAB with uifigure/uiaxes (recent MATLAB desktop version).
% Mesh modes: pure triangles, hybrid (tri + quad BL), full-quad. Polygons are NOT
% supported by the native SU2 2D mesh format and are intentionally blocked.

cfg = defaultConfig();
zones = defaultZones();
selected = 1;
cfgValid = true;
zoneValid = true;
types = {'Rectangle','Ellipse','Couloir','Eventail','Arc'};
anchors = {'Global','Leading edge','Trailing edge'};

fig = uifigure('Name','NACA | CFD Mesh Editor | Gmsh / SU2', ...
    'Position',[80 80 1590 880],'Color',[0.965 0.974 0.987]);

% --- Left: global geometry, mesher, near-wall controls -----------------
left = uipanel(fig,'Title','Geometry / Mesh / Boundary Layer', ...
    'Position',[10 55 285 815]);
y = 744;
header('GEOMETRY');
nacaEdit  = fieldText('NACA 4 digits',cfg.naca);
cEdit     = fieldNum('Chord c [m]',cfg.c);
nEdit     = fieldNum('Points / side',cfg.N);
aEdit     = fieldNum('AoA alpha [deg]',cfg.alpha);
pEdit     = fieldNum('Pivot x/c',cfg.pivotFrac);
header('FARFIELD [multiples of c]');
xminEdit  = fieldNum('X min / c',cfg.xmin);
xmaxEdit  = fieldNum('X max / c',cfg.xmax);
yminEdit  = fieldNum('Y min / c',cfg.ymin);
ymaxEdit  = fieldNum('Y max / c',cfg.ymax);
header('MESHER & SIZES');
mesherDrop = uidropdown(left,'Items', ...
    {'Triangles','Hybride','Quadrilateres','Polygones (non supportes)'}, ...
    'Value',cfg.mesher,'Position',[128 y 146 23], ...
    'ValueChangedFcn',@onMesherChanged);
uilabel(left,'Text','Cell type','Position',[10 y 115 22]); y=y-31;
baseEdit = fieldNum('Base size / c',cfg.baseFrac);
surfEdit = fieldNum('Surface / base [%]',cfg.surfacePct);
dminEdit = fieldNum('Surface min d/c',cfg.distMin);
dmaxEdit = fieldNum('Surface max d/c',cfg.distMax);
header('BOUNDARY LAYER (independent)');
blCheck = uicheckbox(left,'Text','Enable boundary layer', ...
    'Value',cfg.blEnabled,'Position',[12 y 260 23], ...
    'ValueChangedFcn',@onCfgChanged); y=y-31;
blFirstEdit = fieldNum('First height / c',cfg.blFirst);
blThickEdit = fieldNum('Total thickness / c',cfg.blThickness);
blGrowthEdit= fieldNum('Growth ratio',cfg.blGrowth);
blFanEdit   = fieldNum('TE fan count',cfg.blFan);

% --- Center: CAD & field-region preview --------------------------------
center = uipanel(fig,'Title','2D CAD and refinement preview', ...
    'Position',[305 55 820 815]);
ax = uiaxes(center,'Position',[18 110 782 655]);
ax.Color = [1 1 1]; ax.XGrid='on'; ax.YGrid='on';
xlabel(ax,'x [m]'); ylabel(ax,'y [m]');
viewDrop = uidropdown(center,'Items',{'Near airfoil','Full farfield'}, ...
    'Value','Near airfoil','Position',[14 67 160 29], ...
    'ValueChangedFcn',@(~,~) updatePreview());
uibutton(center,'Text','Refresh view','Position',[183 67 110 29], ...
    'ButtonPushedFcn',@(~,~) updatePreview());
uibutton(center,'Text','Export .geo','Position',[342 67 127 29], ...
    'ButtonPushedFcn',@(~,~) exportMesh(false));
uibutton(center,'Text','Generate SU2','Position',[480 67 133 29], ...
    'ButtonPushedFcn',@(~,~) exportMesh(true));
uilabel(center,'Text','Gmsh path','Position',[14 30 75 24]);
gmshEdit = uieditfield(center,'text','Value','gmsh', ...
    'Position',[92 30 282 25]);
status = uilabel(fig,'Text','Ready. Select a region to edit its parameters.', ...
    'Position',[16 10 1550 30],'FontColor',[0.20 0.32 0.46]);

% --- Right: region list and editing form --------------------------------
right = uipanel(fig,'Title','Refinement Controls (2D volumetric controls)', ...
    'Position',[1135 55 445 815]);
regionTable = uitable(right,'Position',[12 477 417 292], ...
    'ColumnName',{'On','Name','Geometry','Anchor','% Base'}, ...
    'ColumnEditable',[true false false false false], ...
    'ColumnWidth',{35 124 86 100 62}, ...
    'CellSelectionCallback',@onRowSelect, ...
    'CellEditCallback',@onTableEdit);
uibutton(right,'Text','+ Add','Position',[12 441 77 28], ...
    'ButtonPushedFcn',@onAdd);
uibutton(right,'Text','Duplicate','Position',[96 441 77 28], ...
    'ButtonPushedFcn',@onDuplicate);
uibutton(right,'Text','Delete','Position',[180 441 77 28], ...
    'ButtonPushedFcn',@onDelete);
uibutton(right,'Text','Examples','Position',[264 441 77 28], ...
    'ButtonPushedFcn',@onExamples);

% Region editor: all dimensions x,y,L,H,transition use multiples of c.
formY=402;
uilabel(right,'Text','SELECTED REFINEMENT','FontWeight','bold', ...
    'Position',[14 formY 300 20]); formY=formY-31;
regName = makeText('Name','',@onZoneChanged);
regType = makeDrop('Shape',types,@onZoneChanged);
regAnchor = makeDrop('Anchor',anchors,@onZoneChanged);
regX = makeNum('X offset / c',0,@onZoneChanged);
regY = makeNum('Y offset / c',0,@onZoneChanged);
regL = makeNum('Length or radius / c',1,@onZoneChanged);
regH = makeNum('Height or thickness / c',0.4,@onZoneChanged);
regAngle = makeNum('Direction [deg]',0,@onZoneChanged);
regOpening = makeNum('Opening [deg]',70,@onZoneChanged);
regPct = makeNum('Target [% Base]',10,@onZoneChanged);
regTransition = makeNum('Transition / c',0.25,@onZoneChanged);
regHint = uilabel(right,'Text','', 'Position',[16 23 410 30], ...
    'FontSize',10,'FontColor',[0.30 0.40 0.56]);

uibutton(right,'Text','Save setup (.json)','Position',[12 63 155 30], ...
    'ButtonPushedFcn',@onSave);
uibutton(right,'Text','Load setup (.json)','Position',[180 63 155 30], ...
    'ButtonPushedFcn',@onLoad);

refreshTable(); loadEditor(); updatePreview();

% ==================== UI element factories =============================
    function header(label)
        uilabel(left,'Text',label,'FontWeight','bold', ...
            'FontColor',[0.25 0.38 0.58], ...
            'Position',[10 y 264 22]);
        y=y-27;
    end
    function h=fieldText(label,value)
        uilabel(left,'Text',label,'Position',[10 y 117 23]);
        h=uieditfield(left,'text','Value',value,'Position',[128 y 146 23], ...
            'ValueChangedFcn',@onCfgChanged);
        y=y-29;
    end
    function h=fieldNum(label,value)
        uilabel(left,'Text',label,'Position',[10 y 117 23]);
        h=uieditfield(left,'numeric','Value',value,'Position',[128 y 146 23], ...
            'ValueChangedFcn',@onCfgChanged);
        y=y-29;
    end
    function h=makeText(label,value,cb)
        uilabel(right,'Text',label,'Position',[14 formY 192 22]);
        h=uieditfield(right,'text','Value',value,'Position',[205 formY 221 23], ...
            'ValueChangedFcn',cb); formY=formY-27;
    end
    function h=makeNum(label,value,cb)
        uilabel(right,'Text',label,'Position',[14 formY 192 22]);
        h=uieditfield(right,'numeric','Value',value,'Position',[205 formY 221 23], ...
            'ValueChangedFcn',cb); formY=formY-27;
    end
    function h=makeDrop(label,items,cb)
        uilabel(right,'Text',label,'Position',[14 formY 192 22]);
        h=uidropdown(right,'Items',items,'Value',items{1}, ...
            'Position',[205 formY 221 23],'ValueChangedFcn',cb);
        formY=formY-27;
    end

% ==================== UI callbacks ====================================
    function onMesherChanged(~,~)
        if startsWith(mesherDrop.Value,'Polygones')
            uialert(fig,['SU2 2D accepts triangles and quadrilaterals, not ' ...
                'arbitrary polygonal cells. Polygon mode is not implemented.'], ...
                'Unsupported mesh type');
            mesherDrop.Value=cfg.mesher;
            return
        end
        onCfgChanged([],[]);
    end
    function onCfgChanged(~,~)
        try
            candidate=cfg;
            candidate.naca=char(nacaEdit.Value);
            candidate.c=cEdit.Value; candidate.N=nEdit.Value;
            candidate.alpha=aEdit.Value; candidate.pivotFrac=pEdit.Value;
            candidate.xmin=xminEdit.Value; candidate.xmax=xmaxEdit.Value;
            candidate.ymin=yminEdit.Value; candidate.ymax=ymaxEdit.Value;
            candidate.mesher=mesherDrop.Value;
            candidate.baseFrac=baseEdit.Value;
            candidate.surfacePct=surfEdit.Value;
            candidate.distMin=dminEdit.Value;
            candidate.distMax=dmaxEdit.Value;
            candidate.blEnabled=logical(blCheck.Value);
            candidate.blFirst=blFirstEdit.Value;
            candidate.blThickness=blThickEdit.Value;
            candidate.blGrowth=blGrowthEdit.Value;
            candidate.blFan=blFanEdit.Value;
            validateConfig(candidate);
            cfg=candidate;
            cfgValid=true;
            updatePreview();
        catch ME
            cfgValid=false;
            status.Text=['Invalid settings: ' ME.message];
        end
    end
    function refreshTable()
        data=cell(numel(zones),5);
        for ii=1:numel(zones)
            data(ii,:)={zones(ii).enabled, zones(ii).name, zones(ii).type, ...
                zones(ii).anchor, zones(ii).pct};
        end
        regionTable.Data=data;
    end
    function onRowSelect(~,event)
        if isempty(event.Indices), return; end
        selected=event.Indices(1,1);
        loadEditor(); updatePreview();
    end
    function onTableEdit(~,event)
        if isempty(event.Indices), return; end
        row=event.Indices(1);
        if row>=1 && row<=numel(zones) && event.Indices(2)==1
            zones(row).enabled=logical(event.NewData);
            refreshTable(); updatePreview();
        end
    end
    function loadEditor()
        if isempty(zones) || selected>numel(zones), selected=0; end
        controls={regName, regType, regAnchor, regX, regY, regL, ...
            regH, regAngle, regOpening, regPct, regTransition};
        if selected==0
            for q=1:numel(controls), controls{q}.Enable='off'; end
            regHint.Text='Use + Add to create a refinement region.';
            return
        end
        for q=1:numel(controls), controls{q}.Enable='on'; end
        z=zones(selected);
        regName.Value=z.name; regType.Value=z.type;
        regAnchor.Value=z.anchor;
        regX.Value=z.x; regY.Value=z.y; regL.Value=z.L;
        regH.Value=z.H; regAngle.Value=z.angle;
        regOpening.Value=z.opening; regPct.Value=z.pct;
        regTransition.Value=z.transition;
        switch z.type
            case 'Rectangle', regHint.Text='L = box length; H = box height (rotatable).';
            case 'Ellipse', regHint.Text='L/H = principal diameters; direction rotates axes.';
            case 'Couloir', regHint.Text='L = centreline length; H = full capsule width.';
            case 'Eventail', regHint.Text='L = outer radius; H = inner radius; opening = angle.';
            case 'Arc', regHint.Text='L = centreline radius; H = full band width.';
        end
    end
    function onZoneChanged(~,~)
        if selected<1 || selected>numel(zones), return; end
        z=zones(selected);
        z.name=char(regName.Value); z.type=regType.Value;
        z.anchor=regAnchor.Value;
        z.x=regX.Value; z.y=regY.Value;
        z.L=regL.Value; z.H=regH.Value; z.angle=regAngle.Value;
        z.opening=regOpening.Value; z.pct=regPct.Value;
        z.transition=regTransition.Value;
        try
            validateZone(z);
            zones(selected)=z;
            zoneValid=true;
            refreshTable(); loadEditor(); updatePreview();
        catch ME
            zoneValid=false;
            status.Text=['Region not updated: ' ME.message];
        end
    end
    function onAdd(~,~)
        z=newZone('New refinement','Rectangle','Global',0.5,0,1,0.5,0,70,10,0.2,true);
        zones=[zones;z]; selected=numel(zones);
        refreshTable(); loadEditor(); updatePreview();
    end
    function onDuplicate(~,~)
        if selected==0, return; end
        z=zones(selected); z.name=[z.name ' copy'];
        zones=[zones;z]; selected=numel(zones);
        refreshTable(); loadEditor(); updatePreview();
    end
    function onDelete(~,~)
        if selected==0, return; end
        choice=uiconfirm(fig,['Delete ' zones(selected).name '?'], ...
            'Delete refinement','Options',{'Delete','Cancel'}, ...
            'DefaultOption',2,'CancelOption',2);
        if strcmp(choice,'Delete')
            zones(selected)=[];
            selected=min(selected,numel(zones));
            refreshTable(); loadEditor(); updatePreview();
        end
    end
    function onExamples(~,~)
        choice=uiconfirm(fig,'Replace all regions with example controls?', ...
            'Restore example regions','Options',{'Replace','Cancel'}, ...
            'DefaultOption',2,'CancelOption',2);
        if strcmp(choice,'Replace')
            zones=defaultZones(); selected=1; zoneValid=true;
            refreshTable(); loadEditor(); updatePreview();
        end
    end
    function onSave(~,~)
        if ~cfgValid || ~zoneValid
            uialert(fig,'Resolve invalid settings before saving.','Invalid input');return
        end
        [file,folder]=uiputfile('*.json','Save mesh setup','mesh_setup.json');
        if isequal(file,0), return; end
        payload=struct('config',cfg,'refinements',zones);
        fid=fopen(fullfile(folder,file),'w');
        if fid==-1, uialert(fig,'Unable to write JSON','I/O'); return; end
        guard=onCleanup(@() fclose(fid));
        fprintf(fid,'%s',jsonencode(payload,'PrettyPrint',true));
        clear guard
        status.Text=['Saved: ' fullfile(folder,file)];
    end
    function onLoad(~,~)
        [file,folder]=uigetfile('*.json','Load mesh setup');
        if isequal(file,0), return; end
        try
            payload=jsondecode(fileread(fullfile(folder,file)));
            validateConfig(payload.config);
            for k=1:numel(payload.refinements)
                validateZone(payload.refinements(k));
            end
            cfg=payload.config;
            if isempty(payload.refinements)
                zones=defaultZones(); zones=zones([]);
            else
                zones=payload.refinements(:);
            end
            cfgValid=true;zoneValid=true;
            selected=min(1,numel(zones));
            syncCfgFields();
            refreshTable(); loadEditor(); updatePreview();
            status.Text=['Loaded: ' fullfile(folder,file)];
        catch ME
            uialert(fig,['Unable to load setup: ' ME.message],'Load failed');
        end
    end
    function syncCfgFields()
        nacaEdit.Value=cfg.naca; cEdit.Value=cfg.c;
        nEdit.Value=cfg.N; aEdit.Value=cfg.alpha;
        pEdit.Value=cfg.pivotFrac; xminEdit.Value=cfg.xmin;
        xmaxEdit.Value=cfg.xmax; yminEdit.Value=cfg.ymin;
        ymaxEdit.Value=cfg.ymax; mesherDrop.Value=cfg.mesher;
        baseEdit.Value=cfg.baseFrac; surfEdit.Value=cfg.surfacePct;
        dminEdit.Value=cfg.distMin; dmaxEdit.Value=cfg.distMax;
        blCheck.Value=cfg.blEnabled; blFirstEdit.Value=cfg.blFirst;
        blThickEdit.Value=cfg.blThickness;
        blGrowthEdit.Value=cfg.blGrowth; blFanEdit.Value=cfg.blFan;
    end
    function updatePreview()
        try
            [profile,LE,TE]=makeAirfoil(cfg);
            cla(ax); hold(ax,'on');
            % Farfield boundaries, zones, rotated airfoil
            cc=cfg.c;
            rectangle(ax,'Position',[cfg.xmin*cc,cfg.ymin*cc, ...
                (cfg.xmax-cfg.xmin)*cc,(cfg.ymax-cfg.ymin)*cc], ...
                'EdgeColor',[0.40 0.48 0.58],'LineWidth',1.2);
            cmap=lines(max(1,numel(zones)));
            for k=1:numel(zones)
                if ~zones(k).enabled, continue; end
                [px,py]=zoneOutline(zones(k),LE,TE,cc);
                patch(ax,px,py,cmap(k,:),'FaceAlpha',0.13, ...
                    'EdgeColor',cmap(k,:),'LineStyle','--','LineWidth',1.3);
                text(ax,mean(px),mean(py),zones(k).name,'Color',cmap(k,:), ...
                    'FontSize',10,'HorizontalAlignment','center', ...
                    'Interpreter','none');
            end
            plot(ax,profile(:,1),profile(:,2),'k-','LineWidth',2);
            plot(ax,[TE(1),LE(1)],[TE(2),LE(2)],'k:');
            plot(ax,LE(1),LE(2),'.','MarkerSize',14,'Color',[0.12 0.52 0.85]);
            plot(ax,TE(1),TE(2),'.','MarkerSize',14,'Color',[0.9 0.3 0.2]);
            axis(ax,'equal');
            if strcmp(viewDrop.Value,'Near airfoil')
                xlim(ax,[-1.5 5]*cc); ylim(ax,[-2 2]*cc);
            else
                xlim(ax,[cfg.xmin cfg.xmax]*cc);
                ylim(ax,[cfg.ymin cfg.ymax]*cc);
            end
            title(ax,sprintf('NACA %s | AoA %+g deg | %s | %d active refinements', ...
                cfg.naca,cfg.alpha,cfg.mesher,sum([zones.enabled])));
            hold(ax,'off');
            status.Text='Preview ready. Colored regions are mesh-size controls, not fluid boundaries.';
        catch ME
            status.Text=['Preview: ' ME.message];
        end
    end
    function exportMesh(runGmsh)
        try
            assert(cfgValid && zoneValid,'Correct invalid fields before exporting');
            validateConfig(cfg);
            for k=1:numel(zones), validateZone(zones(k)); end
            [geoPath,su2Path]=writeGeo(cfg,zones);
            status.Text=['Gmsh geometry created: ' geoPath];
            if runGmsh
                % Prevent a stale SU2 from a previous successful run from
                % being mistaken for the result of the current attempt.
                if exist(su2Path,'file')==2, delete(su2Path); end
                command=sprintf('"%s" "%s" -2 -format su2 -o "%s" 2>&1', ...
                    gmshEdit.Value,geoPath,su2Path);
                [exitCode,output]=system(command);
                if exitCode~=0 || ~isempty(regexp(output,'(?m)^\s*Error\s*:', 'once'))
                    error('Gmsh reported an error (exit %d):\n%s',exitCode,output);
                end
                % Gmsh can write a mesh even when recombination created
                % inverted/invalid quadrilaterals. Do not report success.
                badTokens=regexp(output,'(\d+)\s+invalid quads','tokens');
                nBad=0;
                for ib=1:numel(badTokens)
                    nBad=max(nBad,str2double(badTokens{ib}{1}));
                end
                qTokens=regexp(output,'min Q\s*=\s*([+-]?[0-9.]+(?:[eE][+-]?[0-9]+)?)','tokens');
                minQ=inf;
                for iq=1:numel(qTokens)
                    minQ=min(minQ,str2double(qTokens{iq}{1}));
                end
                if nBad>0 || minQ<0
                    % Never leave an invalid solver mesh in the output folder.
                    if exist(su2Path,'file')==2, delete(su2Path); end
                    error(['Unsafe quad mesh: Gmsh reports %d invalid quads, ' ...
                        'minimum Q = %.5g. Try Triangles, or disable the ' ...
                        'boundary layer / reduce aggressive refinements.'],nBad,minQ);
                end
                if exist(su2Path,'file')~=2, error('Gmsh did not create .su2'); end
                [ntri,nquad,nother]=countSU2Elements(su2Path);
                summary=sprintf('SU2: %d triangles, %d quads, %d other.',ntri,nquad,nother);
                % Enforce what the user selected; do not silently export mixed
                % meshes when pure triangles were explicitly requested.
                if strcmp(cfg.mesher,'Triangles') && (nquad>0 || nother>0)
                    if exist(su2Path,'file')==2, delete(su2Path); end
                    error(['Pure triangles requested, but Gmsh generated ' ...
                        '%d quads and %d other cells. Export aborted.'],nquad,nother);
                end
                status.Text=[summary ' File: ' su2Path];
                if strcmp(cfg.mesher,'Quadrilateres') && ntri>0
                    uialert(fig,[summary ' Full-quad recombination left residual ' ...
                        'triangles. Inspect the mesh and adjust your controls.'], ...
                        'Mixed-element mesh','Icon','warning');
                else
                    uialert(fig,[summary ' Inspect mesh quality in Gmsh or ParaView.'], ...
                        'Mesh generated','Icon','success');
                end
            end
        catch ME
            status.Text=['Export: ' ME.message];
            uialert(fig,ME.message,'Export / meshing error');
        end
    end
end

% ====================== Data model ======================================
function cfg=defaultConfig()
cfg=struct('naca','0012','c',1,'N',161,'alpha',5,'pivotFrac',0.25, ...
    'xmin',-10,'xmax',20,'ymin',-10,'ymax',10, ...
    'mesher','Triangles','baseFrac',0.5,'surfacePct',1, ...
    'distMin',0.02,'distMax',0.8, ...
    'blEnabled',true,'blFirst',1e-5,'blThickness',0.01, ...
    'blGrowth',1.2,'blFan',8);
end
function z=newZone(name,type,anchor,x,y,L,H,angle,opening,pct,transition,enabled)
z=struct('name',name,'type',type,'anchor',anchor,'x',x,'y',y, ...
    'L',L,'H',H,'angle',angle,'opening',opening,'pct',pct, ...
    'transition',transition,'enabled',enabled);
end
function zones=defaultZones()
zones=[...
    newZone('Near body','Rectangle','Global',0.5,0,2.3,1.2,0,70,10,0.3,true); ...
    newZone('Leading edge','Ellipse','Leading edge',-0.08,0,0.7,0.55,0,70,2,0.12,true); ...
    newZone('Wake','Couloir','Trailing edge',3,0,6,0.55,0,70,10,0.4,true); ...
    newZone('Detached shock (example)','Arc','Leading edge',0,0,0.45,0.12,180,125,4,0.15,false); ...
    newZone('Expansion fan (example)','Eventail','Trailing edge',0,0,2.0,0,25,60,6,0.3,false)];
end
function validateConfig(c)
assert(ischar(c.naca)||isstring(c.naca),'NACA should be a text code');
s=char(c.naca);
assert(numel(s)==4 && all(ismember(s,'0123456789')),'NACA needs exactly 4 digits');
assert(c.c>0 && c.N>=11 && c.N==round(c.N),'c > 0 and integer N >= 11 required');
assert(c.pivotFrac>=0 && c.pivotFrac<=1,'Pivot fraction must lie in [0,1]');
assert(c.xmin<c.xmax && c.ymin<c.ymax,'Invalid farfield bounds');
assert(c.baseFrac>0 && c.surfacePct>0 && c.surfacePct<=100,'Invalid base / surface sizes');
assert(c.distMin>=0 && c.distMax>c.distMin,'Invalid surface-distance limits');
assert(c.blFirst>0 && c.blThickness>c.blFirst && c.blGrowth>1, ...
    'Invalid boundary layer parameters');
assert(c.blFan>=1 && c.blFan==round(c.blFan),'TE fan count must be a positive integer');
assert(ismember(char(c.mesher),{'Triangles','Hybride','Quadrilateres'}), ...
    'Mesh type must be Triangles, Hybride or Quadrilateres');
end
function validateZone(z)
assert(~isempty(strtrim(char(z.name))),'Region name must not be empty');
assert(ismember(z.type,{'Rectangle','Ellipse','Couloir','Eventail','Arc'}), ...
    'Unknown region geometry');
assert(ismember(z.anchor,{'Global','Leading edge','Trailing edge'}), ...
    'Invalid region anchor');
assert(isfinite(z.x)&&isfinite(z.y)&&isfinite(z.angle),'Invalid coordinates/angle');
assert(z.L>0 && z.H>=0,'L > 0, H >= 0 required');
assert(z.pct>0 && z.pct<=100,'Target must be 0 < percentage <= 100');
assert(z.transition>0,'Transition distance must be > 0');
assert(z.opening>0 && z.opening<=170,'Opening must lie in (0,170] deg');
assert(~ismember(z.type,{'Rectangle','Ellipse','Couloir','Arc'}) || z.H>0, ...
    'This shape needs H > 0');
assert(~strcmp(z.type,'Eventail') || z.H<z.L,'Fan inner radius must be < outer radius');
end

% ====================== NACA airfoil ===================================
function [airfoil,LE,TE]=makeAirfoil(c)
code=char(c.naca); m=str2double(code(1))/100;
p=str2double(code(2))/10; t=str2double(code(3:4))/100;
assert(t>0 && (m==0 || (p>0 && p<1)),'Invalid NACA camber/thickness');
xi=(1-cos(linspace(0,pi,c.N))).'/2;
x=c.c*xi;
yt=5*t*c.c*(0.2969*sqrt(xi)-0.1260*xi-0.3516*xi.^2 ...
    +0.2843*xi.^3-0.1036*xi.^4);
yc=zeros(c.N,1); dyc=zeros(c.N,1);
if m>0
    a=xi<p; b=~a;
    yc(a)=m*c.c/p^2*(2*p*xi(a)-xi(a).^2);
    yc(b)=m*c.c/(1-p)^2*(1-2*p+2*p*xi(b)-xi(b).^2);
    dyc(a)=2*m/p^2*(p-xi(a));
    dyc(b)=2*m/(1-p)^2*(p-xi(b));
end
th=atan(dyc);
upper=[x-yt.*sin(th), yc+yt.*cos(th)];
lower=[x+yt.*sin(th), yc-yt.*cos(th)];
upper([1 end],:)=[0 0;c.c 0];
lower([1 end],:)=[0 0;c.c 0];
airfoil=[flipud(upper);lower(2:end-1,:)];
pivot=[c.pivotFrac*c.c,0];
Q=[cosd(-c.alpha),-sind(-c.alpha);sind(-c.alpha),cosd(-c.alpha)];
airfoil=(airfoil-pivot)*Q.'+pivot;
TE=airfoil(1,:); LE=airfoil(c.N,:);
assert(all(airfoil(:,1)>c.xmin*c.c) && all(airfoil(:,1)<c.xmax*c.c) && ...
    all(airfoil(:,2)>c.ymin*c.c) && all(airfoil(:,2)<c.ymax*c.c), ...
    'Rotated NACA intersects the farfield boundary');
end

% ====================== Primitive geometry =============================
function [X,Y]=zoneOrigin(z,LE,TE,c)
switch z.anchor
    case 'Global', point=[0 0];
    case 'Leading edge', point=LE;
    case 'Trailing edge', point=TE;
end
X=point(1)+z.x*c; Y=point(2)+z.y*c;
end
function [px,py]=zoneOutline(z,LE,TE,c)
[X,Y]=zoneOrigin(z,LE,TE,c);
L=z.L*c; H=z.H*c;
switch z.type
    case 'Rectangle'
        u=[-L/2 L/2 L/2 -L/2];v=[-H/2 -H/2 H/2 H/2];
    case 'Ellipse'
        t=linspace(0,2*pi,100);u=L/2*cos(t);v=H/2*sin(t);
    case 'Couloir'
        t1=linspace(pi/2,3*pi/2,50);
        t2=linspace(-pi/2,pi/2,50);
        u=[-L/2+H/2*cos(t1), L/2+H/2*cos(t2)];
        v=[H/2*sin(t1), H/2*sin(t2)];
    case 'Eventail'
        t=linspace(-z.opening/2,z.opening/2,100)*pi/180;
        u=[L*cos(t),H*cos(fliplr(t))];
        v=[L*sin(t),H*sin(fliplr(t))];
    case 'Arc'
        t=linspace(-z.opening/2,z.opening/2,100)*pi/180;
        u=[(L+H/2)*cos(t), max(L-H/2,0)*cos(fliplr(t))];
        v=[(L+H/2)*sin(t), max(L-H/2,0)*sin(fliplr(t))];
end
ca=cosd(z.angle);sa=sind(z.angle);
px=X+ca*u-sa*v; py=Y+sa*u+ca*v;
end

% ====================== Gmsh MathEval ----------------------------------
function expr=zoneDistanceExpression(z,LE,TE,c)
% Approximate distance from a point (x,y) to the selected finite 2D region.
% Output = 0 inside the region; >0 outside. The Threshold field interpolates
% mesh size as a function of this distance.
[X,Y]=zoneOrigin(z,LE,TE,c);
ca=cosd(z.angle); sa=sind(z.angle);
u=sprintf('((x-(%.16g))*(%.16g)+(y-(%.16g))*(%.16g))',X,ca,Y,sa);
v=sprintf('(-(x-(%.16g))*(%.16g)+(y-(%.16g))*(%.16g))',X,sa,Y,ca);
L=z.L*c; H=z.H*c;
switch z.type
    case 'Rectangle'
        dx=sprintf('max(abs(%s)-%.16g,0)',u,L/2);
        dy=sprintf('max(abs(%s)-%.16g,0)',v,H/2);
        expr=sprintf('sqrt((%s)^2+(%s)^2)',dx,dy);
    case 'Ellipse'
        % Elliptical normalized radial distance: exact zero region, approx.
        % exterior distance. Appropriate for target-sized refinement fields.
        expr=sprintf('max(sqrt((%s/%.16g)^2+(%s/%.16g)^2)-1,0)*%.16g', ...
            u,L/2,v,H/2,min(L,H)/2);
    case 'Couloir'
        dx=sprintf('max(abs(%s)-%.16g,0)',u,L/2);
        expr=sprintf('max(sqrt((%s)^2+(%s)^2)-%.16g,0)',dx,v,H/2);
    case 'Eventail'
        % Finite angular sector (wedge). Its angular boundary distance is
        % approximated by the signed distance to the two radial lines.
        radial=sprintf('sqrt((%s)^2+(%s)^2)',u,v);
        lim=sprintf('max(abs(%s)-max(%s,0)*%.16g,0)*%.16g', ...
            v,u,tand(z.opening/2),cosd(z.opening/2));
        expr=sprintf('max(max(max(-(%s),0),max(%s-%.16g,0)),max(%s,max(%.16g-%s,0)))', ...
            u,radial,L,lim,H,radial);
    case 'Arc'
        % Curved shock-control band: short concentric annular arc.
        radial=sprintf('sqrt((%s)^2+(%s)^2)',u,v);
        dRad=sprintf('max(abs(%s-%.16g)-%.16g,0)',radial,L,H/2);
        % Avoid atan2(): unsupported by Gmsh MathEval's math parser.
        % Signed distance to the two radial half-planes of the angular wedge.
        % This is zero inside the angle and positive outside. The distance
        % combined with dRad is an approximate distance to the finite arc.
        beta=z.opening/2;
        dAng=sprintf('max(abs(%s)*%.16g-(%s)*%.16g,0)', ...
            v,cosd(beta),u,sind(beta));
        expr=sprintf('sqrt((%s)^2+(%s)^2)',dRad,dAng);
end
end

% ====================== Write .geo =====================================
function [geoFile,su2File]=writeGeo(c,zones)
[airfoil,LE,TE]=makeAirfoil(c);
proj=fileparts(mfilename('fullpath'));
out=fullfile(proj,'output');if ~exist(out,'dir'),mkdir(out);end
angleTag=strrep(strrep(strrep(sprintf('%+g',c.alpha),'+','p'),'-','m'),'.','_');
baseName=sprintf('NACA_%s_a%s',c.naca,angleTag);
geoFile=fullfile(out,[baseName '.geo']);
su2File=fullfile(out,[baseName '.su2']);
file=fopen(geoFile,'w');assert(file~=-1,'Cannot write .geo');
closer=onCleanup(@() fclose(file));
M=size(airfoil,1);N=c.N;hBase=c.baseFrac*c.c;
hSurf=hBase*c.surfacePct/100;
fprintf(file,'// Generated by NACA_Mesh_Editor, alpha = %.9g deg (geometric rotation)\n',c.alpha);
fprintf(file,'SetFactory("Built-in");\n');
for j=1:M
    fprintf(file,'Point(%d) = {%.16g,%.16g,0,%.16g};\n', ...
        j,airfoil(j,1),airfoil(j,2),hSurf);
end
fprintf(file,'Spline(1) = {');fprintf(file,'%d,',1:N-1);fprintf(file,'%d};\n',N);
fprintf(file,'Spline(2) = {%d,',N);fprintf(file,'%d,',N+1:M);fprintf(file,'1};\n');
cor=[c.xmin c.ymin; c.xmax c.ymin; c.xmax c.ymax; c.xmin c.ymax]*c.c;
for j=1:4
    fprintf(file,'Point(%d) = {%.16g,%.16g,0,%.16g};\n', ...
        M+j,cor(j,1),cor(j,2),hBase);
end
fprintf(file,'Line(3) = {%d,%d};\n',M+1,M+2);
fprintf(file,'Line(4) = {%d,%d};\n',M+2,M+3);
fprintf(file,'Line(5) = {%d,%d};\n',M+3,M+4);
fprintf(file,'Line(6) = {%d,%d};\n',M+4,M+1);
fprintf(file,'Curve Loop(1) = {3,4,5,6};\n');
fprintf(file,'Curve Loop(2) = {-2,-1};\n');
fprintf(file,'Plane Surface(1) = {1,2};\n');
fprintf(file,'Physical Curve("airfoil") = {1,2};\n');
fprintf(file,'Physical Curve("inlet") = {6};\n');
fprintf(file,'Physical Curve("outlet") = {4};\n');
fprintf(file,'Physical Curve("top") = {5};\n');
fprintf(file,'Physical Curve("bottom") = {3};\n');
fprintf(file,'Physical Surface("fluid") = {1};\n');

% Surface sizing: Distance -> Threshold (first field in Min).
fprintf(file,'Field[1] = Distance;\nField[1].CurvesList = {1,2};\n');
fprintf(file,'Field[1].Sampling = 350;\n');
fprintf(file,'Field[2] = Threshold;\nField[2].InField = 1;\n');
fprintf(file,'Field[2].SizeMin = %.16g;\n',hSurf);
fprintf(file,'Field[2].SizeMax = %.16g;\n',hBase);
fprintf(file,'Field[2].DistMin = %.16g;\n',c.distMin*c.c);
fprintf(file,'Field[2].DistMax = %.16g;\n',c.distMax*c.c);
ids=2;
nextField=3;
for j=1:numel(zones)
    z=zones(j);
    if ~z.enabled,continue;end
    % Mathematical size field for the actual finite region, followed by a
    % Threshold that makes transition width explicitly controllable.
    expr=zoneDistanceExpression(z,LE,TE,c.c);
    dField=nextField;szField=nextField+1;nextField=nextField+2;
    fprintf(file,'// Refinement: %s (%s)\n',strrep(z.name,newline,' '),z.type);
    fprintf(file,'Field[%d] = MathEval;\n',dField);
    fprintf(file,'Field[%d].F = "%s";\n',dField,expr);
    fprintf(file,'Field[%d] = Threshold;\n',szField);
    fprintf(file,'Field[%d].InField = %d;\n',szField,dField);
    fprintf(file,'Field[%d].SizeMin = %.16g;\n',szField,hBase*z.pct/100);
    fprintf(file,'Field[%d].SizeMax = %.16g;\n',szField,hBase);
    fprintf(file,'Field[%d].DistMin = 0;\n',szField);
    fprintf(file,'Field[%d].DistMax = %.16g;\n',szField,z.transition*c.c);
    ids=[ids,szField]; %#ok<AGROW>
end
% Base field and combined field. No region duplicates or physical surfaces.
baseField=nextField;nextField=nextField+1;
fprintf(file,'Field[%d] = MathEval;\n',baseField);
fprintf(file,'Field[%d].F = "%.16g";\n',baseField,hBase);
ids=[ids,baseField];
combineField=nextField;nextField=nextField+1;
fprintf(file,'Field[%d] = Min;\n',combineField);
fprintf(file,'Field[%d].FieldsList = {%s};\n',combineField,joinInts(ids));
fprintf(file,'Background Field = %d;\n',combineField);

if c.blEnabled
    blField=nextField;
    fprintf(file,'Field[%d] = BoundaryLayer;\n',blField);
    fprintf(file,'Field[%d].CurvesList = {1,2};\n',blField);
    fprintf(file,'Field[%d].Size = %.16g;\n',blField,c.blFirst*c.c);
    fprintf(file,'Field[%d].Ratio = %.16g;\n',blField,c.blGrowth);
    fprintf(file,'Field[%d].Thickness = %.16g;\n',blField,c.blThickness*c.c);
    % The boundary-layer recombination is independent of the bulk mesher.
    % In pure Triangles mode, do not create quads even inside the BL.
    blQuads = ~strcmp(c.mesher,'Triangles');
    fprintf(file,'Field[%d].Quads = %d;\n',blField,blQuads);
    fprintf(file,'Field[%d].FanPointsList = {1};\n',blField);
    fprintf(file,'Field[%d].FanPointsSizesList = {%d};\n',blField,c.blFan);
    fprintf(file,'BoundaryLayer Field = %d;\n',blField);
end

fprintf(file,'Mesh.MeshSizeFromPoints = 0;\n');
fprintf(file,'Mesh.MeshSizeFromCurvature = 0;\n');
fprintf(file,'Mesh.MeshSizeExtendFromBoundary = 0;\n');
fprintf(file,'Mesh.MeshSizeMax = %.16g;\n',hBase);
fprintf(file,'Mesh.ElementOrder = 1;\n');
switch c.mesher
    case {'Triangles','Hybride'}
        fprintf(file,'Mesh.Algorithm = 6; // Frontal-Delaunay triangles\n');
        fprintf(file,'Mesh.RecombineAll = 0; // Never recombine the bulk mesh\n');
        fprintf(file,'Mesh.SubdivisionAlgorithm = 0;\n');
    case 'Quadrilateres'
        fprintf(file,'Mesh.Algorithm = 8; // Frontal-Delaunay for quads\n');
        fprintf(file,'Mesh.RecombineAll = 1;\n');
        fprintf(file,'Mesh.RecombinationAlgorithm = 3; // Blossom full-quad\n');
        fprintf(file,'Mesh.Smoothing = 20; // additional node relaxation\n');
    otherwise
        error('Unsupported mesher');
end
end

function s=joinInts(v)
s=sprintf('%d,',v);s(end)=[];
end

% ====================== SU2 connectivity report =========================
function [nTri,nQuad,nOther]=countSU2Elements(filename)
nTri=0; nQuad=0; nOther=0;
fid=fopen(filename,'r');assert(fid~=-1,'Cannot read generated SU2 file');
closer=onCleanup(@() fclose(fid));
nElements=[];
while ~feof(fid)
    line=fgetl(fid);
    if ~ischar(line),break;end
    tok=regexp(line,'^\s*NELEM\s*=\s*(\d+)','tokens','once');
    if ~isempty(tok)
        nElements=str2double(tok{1});break
    end
end
assert(~isempty(nElements),'NELEM not found in .su2 mesh');
for i=1:nElements
    line=fgetl(fid);
    assert(ischar(line),'Unexpected end of .su2 connectivity');
    kind=sscanf(line,'%d',1);
    if isempty(kind),error('Malformed SU2 element entry');end
    if kind==5
        nTri=nTri+1;
    elseif kind==9
        nQuad=nQuad+1;
    else
        nOther=nOther+1;
    end
end
end
