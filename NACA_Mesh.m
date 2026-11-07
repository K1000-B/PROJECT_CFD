%% NACA 4-digit -> Gmsh 2D -> SU2 (one simple MATLAB script)
% Edit parameters below, then run this file in MATLAB.
clear; close all; clc;

%% 1) Geometry - angles are in degrees
NACA  = '0012';
c     = 1.0;                   % Chord [m]
N     = 161;                   % Points per side (endpoints included)
alpha = 5.0;                   % AoA [deg], +alpha means nose UP for flow left -> right
pivot = [0.25*c, 0];           % Rotation centre (quarter chord)

%% 2) Rectangular farfield [m] (fixed in laboratory frame)
xMin = -10*c;   xMax = 20*c;
yMin = -10*c;   yMax = 10*c;

%% 3) Mesh settings - STAR-CCM+ style
baseSize    = 0.50*c;          % Global/base size [m]
surfaceSize = 0.01*baseSize;   % 1%% of Base Size near airfoil [m]
nearSize    = 0.10*baseSize;   % 10%% of Base Size in near-body box [m]
wakeSize    = 0.10*baseSize;   % 10%% of Base Size in wake box [m]

% Proximity refinement (distance to airfoil)
distMin = 0.02*c;             % Surface size until this distance [m]
distMax = 0.80*c;             % Gradual recovery of baseSize until here [m]

% Rectangular volumetric controls: [xMin xMax yMin yMax] [m]
nearBox = [-0.5*c, 1.8*c, -0.6*c, 0.6*c];
nearTransition = 0.30*c;      % Smooth transition outside nearBox [m]

% Wake control relative to the *rotated trailing-edge location*
wakeLength = 8*c;              % Extent downstream from trailing edge [m]
wakeHalfHeight = 0.40*c;       % Half-height of the wake refinement [m]
wakeTransition = 0.50*c;       % Smooth transition outside wake box [m]

%% 4) Boundary layer: quad strips normal to the airfoil
useBoundaryLayer = true;
blFirstHeight = 1e-5*c;        % Normal first-cell height [m] -- must be set from y+
blThickness   = 0.01*c;        % Total layer thickness (approx.) [m]
blGrowth      = 1.20;          % Growth ratio between neighboring layers
blFanElements = 8;             % Fan triangles/quads at sharp trailing edge

%% 5) Export
runGmsh = false;               % Set true when gmsh is available on PATH
gmshExecutable = 'gmsh';        % Or absolute path to gmsh.exe

%% Validate parameters
assert(numel(NACA)==4 && all(ismember(NACA,'0123456789')), 'Invalid NACA code');
assert(c>0 && N>=11 && N==round(N), 'Invalid chord or point count');
assert(baseSize>0 && surfaceSize>0 && surfaceSize<baseSize, 'Invalid mesh sizes');
assert(nearSize>0 && wakeSize>0 && distMax>distMin && distMin>=0, 'Invalid sizes');
assert(xMax>xMin && yMax>yMin, 'Invalid rectangle');
assert(all(nearBox([2,4])>nearBox([1,3])), 'Invalid nearBox');
assert(~useBoundaryLayer || (blFirstHeight>0 && blThickness>blFirstHeight && blGrowth>1), 'Invalid boundary layer');

%% NACA airfoil coordinates before incidence rotation
m = str2double(NACA(1))/100;
p = str2double(NACA(2))/10;
t = str2double(NACA(3:4))/100;
assert(t>0 && (m==0 || (p>0 && p<1)), 'Invalid NACA camber/thickness');

xi = (1 - cos(linspace(0,pi,N))).'/2;
x = c*xi;
yt = 5*t*c*(0.2969*sqrt(xi) - 0.1260*xi - 0.3516*xi.^2 ...
             + 0.2843*xi.^3 - 0.1036*xi.^4);  % Closed trailing edge
yc = zeros(N,1);
dyc = zeros(N,1);
if m>0
    front = xi<p;
    back  = ~front;
    yc(front)  = (m*c/p^2)*(2*p*xi(front) - xi(front).^2);
    yc(back)   = (m*c/(1-p)^2)*(1 - 2*p + 2*p*xi(back) - xi(back).^2);
    dyc(front) = (2*m/p^2)*(p - xi(front));
    dyc(back)  = (2*m/(1-p)^2)*(p - xi(back));
end

theta = atan(dyc);
upper = [x - yt.*sin(theta), yc + yt.*cos(theta)];
lower = [x + yt.*sin(theta), yc - yt.*cos(theta)];
upper([1 end],:) = [0 0; c 0];
lower([1 end],:) = [0 0; c 0];

% Point 1 = trailing edge; point N = leading edge.
% Profile loop: TE -> upper -> LE -> lower -> TE.
airfoil = [flipud(upper); lower(2:end-1,:)];
M = size(airfoil,1);

%% Apply geometrical incidence - the freestream remains (U,0)
% Positive AoA is NOSE UP, i.e. clockwise rotation of the chord line in XY.
% Standard mathematical positive angle is counterclockwise, hence -alpha.
phi = -alpha;
Q = [cosd(phi), -sind(phi); sind(phi), cosd(phi)];
airfoil = (airfoil - pivot)*Q.' + pivot;

TE = airfoil(1,:);                         % Trailing edge after rotation
wakeBox = [TE(1), TE(1)+wakeLength, ...  % Align wake control with laboratory X
           TE(2)-wakeHalfHeight, TE(2)+wakeHalfHeight];

assert(all(airfoil(:,1)>xMin) && all(airfoil(:,1)<xMax) && ...
       all(airfoil(:,2)>yMin) && all(airfoil(:,2)<yMax), ...
       'Rotated airfoil must stay within farfield rectangle');

%% Output paths
projectDir = fileparts(mfilename('fullpath'));
outputDir = fullfile(projectDir,'output');
if ~exist(outputDir,'dir'), mkdir(outputDir); end

alphaTag = sprintf('%+g',alpha);
alphaTag = strrep(alphaTag,'+','p');
alphaTag = strrep(alphaTag,'-','m');
alphaTag = strrep(alphaTag,'.','_');
name = ['NACA_' NACA '_a' alphaTag];
geoFile = fullfile(outputDir,[name '.geo']);
su2File = fullfile(outputDir,[name '.su2']);

fid = fopen(geoFile,'w');
assert(fid~=-1,'Cannot open output .geo file');

%% Geometry in Gmsh
fprintf(fid,'// NACA %s, geometric AoA = %.6g deg, chord = %.6g m\n',NACA,alpha,c);
fprintf(fid,'SetFactory("Built-in");\n');
for k=1:M
    fprintf(fid,'Point(%d) = {%.16g, %.16g, 0, %.16g};\n', ...
        k,airfoil(k,1),airfoil(k,2),surfaceSize);
end

fprintf(fid,'Spline(1) = {');
fprintf(fid,'%d, ',1:N-1);
fprintf(fid,'%d};\n',N);
fprintf(fid,'Spline(2) = {%d, ',N);
fprintf(fid,'%d, ',N+1:M);
fprintf(fid,'1};\n');

corners=[xMin,yMin; xMax,yMin; xMax,yMax; xMin,yMax];
for k=1:4
    fprintf(fid,'Point(%d) = {%.16g, %.16g, 0, %.16g};\n',...
        M+k,corners(k,1),corners(k,2),baseSize);
end
fprintf(fid,'Line(3) = {%d, %d};\n',M+1,M+2);   % Bottom
fprintf(fid,'Line(4) = {%d, %d};\n',M+2,M+3);   % Outlet/right
fprintf(fid,'Line(5) = {%d, %d};\n',M+3,M+4);   % Top
fprintf(fid,'Line(6) = {%d, %d};\n',M+4,M+1);   % Inlet/left
fprintf(fid,'Curve Loop(1) = {3,4,5,6};\n');
fprintf(fid,'Curve Loop(2) = {-2,-1};\n');
fprintf(fid,'Plane Surface(1) = {1,2};\n');

% Physical markers preserved in SU2 output
fprintf(fid,'Physical Curve("airfoil") = {1,2};\n');
fprintf(fid,'Physical Curve("inlet") = {6};\n');
fprintf(fid,'Physical Curve("outlet") = {4};\n');
fprintf(fid,'Physical Curve("top") = {5};\n');
fprintf(fid,'Physical Curve("bottom") = {3};\n');
fprintf(fid,'Physical Surface("fluid") = {1};\n');

%% Meshing fields: distance to airfoil, nearBox, wakeBox, baseSize
fprintf(fid,'Field[1] = Distance;\n');
fprintf(fid,'Field[1].CurvesList = {1,2};\n');
fprintf(fid,'Field[1].Sampling = 350;\n');

fprintf(fid,'Field[2] = Threshold;\n');
fprintf(fid,'Field[2].InField = 1;\n');
fprintf(fid,'Field[2].SizeMin = %.16g;\n',surfaceSize);
fprintf(fid,'Field[2].SizeMax = %.16g;\n',baseSize);
fprintf(fid,'Field[2].DistMin = %.16g;\n',distMin);
fprintf(fid,'Field[2].DistMax = %.16g;\n',distMax);

% Near-body box
fprintf(fid,'Field[3] = Box;\n');
fprintf(fid,'Field[3].XMin = %.16g;\n',nearBox(1));
fprintf(fid,'Field[3].XMax = %.16g;\n',nearBox(2));
fprintf(fid,'Field[3].YMin = %.16g;\n',nearBox(3));
fprintf(fid,'Field[3].YMax = %.16g;\n',nearBox(4));
fprintf(fid,'Field[3].VIn = %.16g;\n',nearSize);
fprintf(fid,'Field[3].VOut = %.16g;\n',baseSize);
fprintf(fid,'Field[3].Thickness = %.16g;\n',nearTransition);

% Wake box (fixed in the freestream x direction, but starts at rotated TE)
fprintf(fid,'Field[4] = Box;\n');
fprintf(fid,'Field[4].XMin = %.16g;\n',wakeBox(1));
fprintf(fid,'Field[4].XMax = %.16g;\n',wakeBox(2));
fprintf(fid,'Field[4].YMin = %.16g;\n',wakeBox(3));
fprintf(fid,'Field[4].YMax = %.16g;\n',wakeBox(4));
fprintf(fid,'Field[4].VIn = %.16g;\n',wakeSize);
fprintf(fid,'Field[4].VOut = %.16g;\n',baseSize);
fprintf(fid,'Field[4].Thickness = %.16g;\n',wakeTransition);

% Explicit global Base Size
fprintf(fid,'Field[5] = MathEval;\n');
fprintf(fid,'Field[5].F = "%.16g";\n',baseSize);

% Combine the most restrictive controls
fprintf(fid,'Field[6] = Min;\n');
fprintf(fid,'Field[6].FieldsList = {2,3,4,5};\n');
fprintf(fid,'Background Field = 6;\n');

%% Independent boundary layer field (NOT part of Min)
if useBoundaryLayer
    fprintf(fid,'Field[7] = BoundaryLayer;\n');
    fprintf(fid,'Field[7].CurvesList = {1,2};\n');
    fprintf(fid,'Field[7].Size = %.16g;\n',blFirstHeight);
    fprintf(fid,'Field[7].Ratio = %.16g;\n',blGrowth);
    fprintf(fid,'Field[7].Thickness = %.16g;\n',blThickness);
    fprintf(fid,'Field[7].Quads = 1;\n');
    fprintf(fid,'Field[7].FanPointsList = {1};\n');
    fprintf(fid,'Field[7].FanPointsSizesList = {%d};\n',blFanElements);
    fprintf(fid,'BoundaryLayer Field = 7;\n');
end

fprintf(fid,'Mesh.MeshSizeFromPoints = 0;\n');
fprintf(fid,'Mesh.MeshSizeFromCurvature = 0;\n');
fprintf(fid,'Mesh.MeshSizeExtendFromBoundary = 0;\n');
fprintf(fid,'Mesh.MeshSizeMax = %.16g;\n',baseSize);
fprintf(fid,'Mesh.Algorithm = 6;\n');          % Frontal-Delaunay 2D
fprintf(fid,'Mesh.ElementOrder = 1;\n');
fclose(fid);

fprintf('Geometry written: %s\n',geoFile);
fprintf('AoA: %+g deg, rotated about (%.4g, %.4g) m\n',alpha,pivot(1),pivot(2));
fprintf('Trailing edge: x=%.6g, y=%.6g m\n',TE(1),TE(2));

if runGmsh
    command = sprintf('"%s" "%s" -2 -format su2 -o "%s"', gmshExecutable,geoFile,su2File);
    [status,msg] = system(command);
    if status~=0
        error('Gmsh failed (exit %d):\n%s',status,msg);
    end
    fprintf('Mesh written: %s\n',su2File);
else
    fprintf('To mesh: gmsh "%s" -2 -format su2 -o "%s"\n',geoFile,su2File);
end
