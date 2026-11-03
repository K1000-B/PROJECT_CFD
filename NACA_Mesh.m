clear; close all; clc;

%% Parameters
NACA = '0012';       % Four-digit NACA code (keep leading zeros)
c = 1;               % Chord [m]
N = 161;             % Points on each surface, including both edges

R = 20*c;            % Farfield radius [m], centred at (0.5*c, 0)

hNear = 0.008*c;     % Mesh size near the airfoil [m]
hFar = 1.0*c;        % Mesh size far from the airfoil [m]
dMin = 0.1*c;        % Start of size transition from the airfoil [m]
dMax = 3.0*c;        % End of size transition [m]

gmshExecutable = 'gmsh';  % Command on PATH, or full path to Gmsh

%% NACA geometry
if length(NACA) ~= 4 || any(~ismember(NACA, '0123456789'))
    error('NACA must be a four-character code such as ''0012'' or ''2412''.');
end
if c <= 0 || N < 11 || N ~= round(N) || R <= 0
    error('Use c > 0, an integer N >= 11, and R > 0.');
end
if hNear <= 0 || hFar <= hNear || dMin < 0 || dMax <= dMin
    error('Use 0 < hNear < hFar and 0 <= dMin < dMax.');
end

m = str2double(NACA(1))/100;      % Maximum camber / chord
p = str2double(NACA(2))/10;       % Camber position / chord
t = str2double(NACA(3:4))/100;    % Maximum thickness / chord
if t == 0 || (m > 0 && p == 0)
    error('Thickness must be positive; a cambered profile needs p > 0.');
end

x = c/2 * (1 - cos(linspace(0, pi, N))).';
xi = x/c;
yt = 5*t*c * (0.2969*sqrt(xi) - 0.1260*xi - 0.3516*xi.^2 ...
    + 0.2843*xi.^3 - 0.1036*xi.^4);  % Closed trailing edge

yc = zeros(N, 1);
dyc = zeros(N, 1);
if m > 0
    front = xi < p;
    back = ~front;
    yc(front) = m*c/p^2 * (2*p*xi(front) - xi(front).^2);
    yc(back) = m*c/(1-p)^2 * (1 - 2*p + 2*p*xi(back) - xi(back).^2);
    dyc(front) = 2*m/p^2 * (p - xi(front));
    dyc(back) = 2*m/(1-p)^2 * (p - xi(back));
end

%% Airfoil coordinates
theta = atan(dyc);
upper = [x - yt.*sin(theta), yc + yt.*cos(theta)];
lower = [x + yt.*sin(theta), yc - yt.*cos(theta)];
upper([1 end], :) = [0 0; c 0];
lower([1 end], :) = [0 0; c 0];

% One trailing-edge and one leading-edge point in the closed contour.
% Order: trailing edge -> upper surface -> leading edge -> lower surface.
airfoil = [flipud(upper); lower(2:end-1, :)];
M = size(airfoil, 1);
if any(hypot(airfoil(:,1) - c/2, airfoil(:,2)) >= R)
    error('Increase R: the airfoil must lie inside the farfield circle.');
end

%% Plot geometry
phi = linspace(0, 2*pi, 361);
circleX = c/2 + R*cos(phi);
circleY = R*sin(phi);

figure('Name', ['NACA ' NACA], 'Color', 'w');
subplot(1, 2, 1);
plot(upper(:,1), upper(:,2), 'b.-', lower(:,1), lower(:,2), 'r.-');
axis equal; grid on;
xlabel('x [m]'); ylabel('y [m]');
title(['NACA ' NACA ' points']);
legend('Upper surface', 'Lower surface', 'Location', 'best');

subplot(1, 2, 2);
plot(circleX, circleY, 'k-', 'LineWidth', 1.2);
hold on;
plot([airfoil(:,1); airfoil(1,1)], [airfoil(:,2); airfoil(1,2)], ...
    'b-', 'LineWidth', 1.2);
axis equal; grid on;
xlabel('x [m]'); ylabel('y [m]');
title('Circular fluid domain');
legend('Farfield', 'Airfoil', 'Location', 'best');

%% Write Gmsh geometry
projectDir = fileparts(mfilename('fullpath'));
outputDir = fullfile(projectDir, 'output');
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end
geoFile = fullfile(outputDir, ['NACA_' NACA '.geo']);
su2File = fullfile(outputDir, ['NACA_' NACA '.su2']);

fid = fopen(geoFile, 'w');
if fid == -1
    error('Cannot open %s for writing.', geoFile);
end
fprintf(fid, '// NACA %s, closed trailing edge\n', NACA);
fprintf(fid, 'SetFactory("Built-in");\n');

for i = 1:M
    fprintf(fid, 'Point(%d) = {%.16g, %.16g, 0, %.16g};\n', ...
        i, airfoil(i,1), airfoil(i,2), hNear);
end

% Both splines reuse the same leading-edge and trailing-edge points.
fprintf(fid, 'Spline(1) = {');
fprintf(fid, '%d, ', 1:N-1);
fprintf(fid, '%d};\n', N);
fprintf(fid, 'Spline(2) = {%d, ', N);
fprintf(fid, '%d, ', N+1:M);
fprintf(fid, '1};\n');

% Four counterclockwise quarter-circle arcs around (c/2, 0).
fprintf(fid, 'Point(%d) = {%.16g, 0, 0, %.16g};\n', M+1, c/2, hFar);
fprintf(fid, 'Point(%d) = {%.16g, 0, 0, %.16g};\n', M+2, c/2+R, hFar);
fprintf(fid, 'Point(%d) = {%.16g, %.16g, 0, %.16g};\n', M+3, c/2, R, hFar);
fprintf(fid, 'Point(%d) = {%.16g, 0, 0, %.16g};\n', M+4, c/2-R, hFar);
fprintf(fid, 'Point(%d) = {%.16g, %.16g, 0, %.16g};\n', M+5, c/2, -R, hFar);
fprintf(fid, 'Circle(3) = {%d, %d, %d};\n', M+2, M+1, M+3);
fprintf(fid, 'Circle(4) = {%d, %d, %d};\n', M+3, M+1, M+4);
fprintf(fid, 'Circle(5) = {%d, %d, %d};\n', M+4, M+1, M+5);
fprintf(fid, 'Circle(6) = {%d, %d, %d};\n', M+5, M+1, M+2);

% The airfoil loop is reversed to make a clockwise hole in the fluid.
fprintf(fid, 'Curve Loop(1) = {3, 4, 5, 6};\n');
fprintf(fid, 'Curve Loop(2) = {-2, -1};\n');
fprintf(fid, 'Plane Surface(1) = {1, 2};\n');
fprintf(fid, 'Physical Curve("airfoil") = {1, 2};\n');
fprintf(fid, 'Physical Curve("farfield") = {3, 4, 5, 6};\n');
fprintf(fid, 'Physical Surface("fluid") = {1};\n');

% Target size grows smoothly with distance from the airfoil curves.
fprintf(fid, 'Field[1] = Distance;\n');
fprintf(fid, 'Field[1].CurvesList = {1, 2};\n');
fprintf(fid, 'Field[1].Sampling = 200;\n');
fprintf(fid, 'Field[2] = Threshold;\n');
fprintf(fid, 'Field[2].InField = 1;\n');
fprintf(fid, 'Field[2].SizeMin = %.16g;\n', hNear);
fprintf(fid, 'Field[2].SizeMax = %.16g;\n', hFar);
fprintf(fid, 'Field[2].DistMin = %.16g;\n', dMin);
fprintf(fid, 'Field[2].DistMax = %.16g;\n', dMax);
fprintf(fid, 'Background Field = 2;\n');
fprintf(fid, 'Mesh.MeshSizeFromPoints = 0;\n');
fprintf(fid, 'Mesh.MeshSizeFromCurvature = 0;\n');
fprintf(fid, 'Mesh.MeshSizeExtendFromBoundary = 0;\n');
fprintf(fid, 'Mesh.Algorithm = 6;\n');  % Frontal-Delaunay triangles
fprintf(fid, 'Mesh.ElementOrder = 1;\n');
fclose(fid);
fprintf('Gmsh geometry written: %s\n', geoFile);

%% Generate mesh with Gmsh
command = sprintf('"%s" -2 "%s" -format su2 -o "%s"', ...
    gmshExecutable, geoFile, su2File);
[status, gmshOutput] = system(command);
if status ~= 0 || ~exist(su2File, 'file')
    error('Gmsh did not create the SU2 mesh. Check its path and output:\n%s', gmshOutput);
end
fprintf('SU2 mesh written: %s\n', su2File);
