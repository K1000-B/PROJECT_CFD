function plot_domain(geom, center, radius)
%PLOT_DOMAIN Inspect the airfoil points and circular fluid domain.
%   PLOT_DOMAIN(GEOM, CENTER, RADIUS) produces two MATLAB plots: a close-up
%   of GEOM.upper/lower and a full-domain boundary view. CENTER is [x,y]
%   and RADIUS is the outer-circle radius, in the chord length unit.
%   Both plots preserve physical aspect ratio. Axes are labelled in metres
%   when the input length unit is metres.

angles = linspace(0, 2*pi, 361);
circleX = center(1) + radius * cos(angles);
circleY = center(2) + radius * sin(angles);

figure('Name', ['NACA ' geom.code ' geometry and domain'], 'Color', 'w');
subplot(1,2,1);
plot(geom.upper(:,1), geom.upper(:,2), 'b.-', ...
     geom.lower(:,1), geom.lower(:,2), 'r.-', 'MarkerSize', 5);
hold on;
plot(0, 0, 'ko', geom.chord, 0, 'ks', 'MarkerFaceColor', 'k');
axis equal;
grid on;
xlabel('x [m]');
ylabel('y [m]');
title(['NACA ' geom.code ' surface points']);
legend('Upper surface', 'Lower surface', 'Leading edge', ...
    'Trailing edge', 'Location', 'best');

subplot(1,2,2);
plot(circleX, circleY, 'k-', 'LineWidth', 1.2);
hold on;
plot(geom.contour(:,1), geom.contour(:,2), 'b-', 'LineWidth', 1.2);
plot(center(1), center(2), 'k+', 'MarkerSize', 8);
axis equal;
grid on;
xlabel('x [m]');
ylabel('y [m]');
title('2D fluid domain boundaries');
legend('Farfield', 'Airfoil wall', 'Circle centre', 'Location', 'best');
end
