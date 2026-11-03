function geom = naca4(code, chord, nPoints)
%NACA4 Construct a closed trailing-edge NACA four-digit airfoil analytically.
%   GEOM = NACA4(CODE, CHORD, NPOINTS) returns upper and lower Nx2 arrays
%   ordered leading edge to trailing edge, plus a single CCW contour ordered
%   trailing edge -> upper surface -> leading edge -> lower surface -> trailing
%   edge. The first contour vertex is the only trailing-edge vertex and the
%   leading edge occurs only once. CHORD is a positive length; coordinates
%   have the same unit. NPOINTS counts each surface's endpoints.
%
%   The closed-edge thickness coefficient is -0.1036. No external airfoil
%   coordinate file is read. Camber is exactly zero when the first digit is
%   zero, including NACA 0012 where p = 0.

if isstring(code) && isscalar(code)
    code = char(code);
end
if ~ischar(code) || ~isrow(code) || ...
        isempty(regexp(code, '^[0-9]{4}$', 'once'))
    error('PROJECT_CFD:InvalidNacaCode', ...
        'code must contain exactly four decimal digits, e.g. ''0012''.');
end
validateattributes(chord, {'numeric'}, ...
    {'scalar','real','finite','positive'}, mfilename, 'chord');
validateattributes(nPoints, {'numeric'}, ...
    {'scalar','real','finite','integer','>=',21}, mfilename, 'nPoints');

digits = double(code) - double('0');
m = digits(1) / 100;
p = digits(2) / 10;
t = (10 * digits(3) + digits(4)) / 100;
if t <= 0
    error('PROJECT_CFD:ZeroThickness', 'Airfoil thickness must be positive.');
end
if m > 0 && p == 0
    error('PROJECT_CFD:InvalidCamberPosition', ...
        'A cambered NACA four-digit profile requires a nonzero second digit.');
end

beta = linspace(0, pi, nPoints).';
xi = 0.5 * (1 - cos(beta));
x = chord * xi;
yt = 5 * t * chord * (0.2969 * sqrt(xi) - 0.1260 * xi ...
    - 0.3516 * xi.^2 + 0.2843 * xi.^3 - 0.1036 * xi.^4);

yc = zeros(nPoints, 1);
dycDx = zeros(nPoints, 1);
if m > 0
    front = xi < p;
    back = ~front;
    yc(front) = m * chord / p^2 * (2 * p * xi(front) - xi(front).^2);
    yc(back) = m * chord / (1 - p)^2 * ...
        ((1 - 2 * p) + 2 * p * xi(back) - xi(back).^2);
    dycDx(front) = 2 * m / p^2 * (p - xi(front));
    dycDx(back) = 2 * m / (1 - p)^2 * (p - xi(back));
end

theta = atan(dycDx);
upper = [x - yt .* sin(theta), yc + yt .* cos(theta)];
lower = [x + yt .* sin(theta), yc - yt .* cos(theta)];
upper(1,:) = [0, 0];
lower(1,:) = [0, 0];
upper(end,:) = [chord, 0];
lower(end,:) = [chord, 0];

% One copy of each edge: this sequence is also the Gmsh point sequence.
contour = [flipud(upper); lower(2:end-1,:)];
signedArea = 0.5 * sum(contour(:,1) .* ...
    contour([2:end 1],2) - contour([2:end 1],1) .* contour(:,2));
if signedArea <= 0 || hasSelfIntersection(contour, chord)
    error('PROJECT_CFD:InvalidAirfoilGeometry', ...
        'This parameter combination produces a degenerate or intersecting contour.');
end

geom = struct('code', code, 'chord', chord, 'nPoints', nPoints, ...
    'm', m, 'p', p, 't', t, 'x', x, 'camber', yc, ...
    'camberSlope', dycDx, 'thicknessHalf', yt, ...
    'upper', upper, 'lower', lower, 'contour', contour, ...
    'leadingEdgeId', nPoints, 'trailingEdgeId', 1);
end

function tf = hasSelfIntersection(vertices, chord)
% Exclude pairs of neighbouring edges, which share their intended endpoint.
n = size(vertices, 1);
tol = 1e-12 * chord^2;
tf = false;
for i = 1:n
    a = vertices(i,:);
    b = vertices(mod(i,n)+1,:);
    if norm(b-a) <= 1e-12 * chord
        tf = true;
        return;
    end
    for j = i+2:n
        if i == 1 && j == n
            continue;
        end
        c = vertices(j,:);
        d = vertices(mod(j,n)+1,:);
        if segmentsIntersect(a, b, c, d, tol)
            tf = true;
            return;
        end
    end
end
end

function tf = segmentsIntersect(a, b, c, d, tol)
if max(min(a(1),b(1)),min(c(1),d(1))) > ...
        min(max(a(1),b(1)),max(c(1),d(1))) || ...
        max(min(a(2),b(2)),min(c(2),d(2))) > ...
        min(max(a(2),b(2)),max(c(2),d(2)))
    tf = false;
    return;
end
o1 = cross2(b-a, c-a);
o2 = cross2(b-a, d-a);
o3 = cross2(d-c, a-c);
o4 = cross2(d-c, b-c);
tf = ((o1 > tol && o2 < -tol) || (o1 < -tol && o2 > tol)) && ...
     ((o3 > tol && o4 < -tol) || (o3 < -tol && o4 > tol));
% A nonadjacent edge touching another edge is invalid as well.
if ~tf
    tf = (abs(o1) <= tol && onSegment(a,b,c)) || ...
         (abs(o2) <= tol && onSegment(a,b,d)) || ...
         (abs(o3) <= tol && onSegment(c,d,a)) || ...
         (abs(o4) <= tol && onSegment(c,d,b));
end
end

function z = cross2(u, v)
z = u(1) * v(2) - u(2) * v(1);
end

function tf = onSegment(a, b, p)
tf = all(p >= min(a,b)) && all(p <= max(a,b));
end
