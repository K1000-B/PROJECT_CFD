"""Generate a self-contained Gmsh .geo file with a triangular C topology.

Keep this script beside naca0012_supersonique.py. All lengths below are
fractions of the chord, except CHORD itself. Zero angle of attack only.
"""

from pathlib import Path
import numpy as np
import naca0012_supersonique as aero


# User parameters
M_INF = aero.M_inf
CHORD = 1.0
OUTPUT_FILE = "NACA0012_C_grid.geo"
POINTS_PER_SURFACE = 121
SPLIT_X = 0.30           # Airfoil station joining the nose and side blocks
DOMAIN_RADIUS = 5.0      # Upstream semicircle radius and domain half-height
OUTLET_X = 8.0           # Outlet location, measured from the leading edge
H_FAR = 0.2
MESH_ON_OPEN = False      # Mesh 2 in the .geo; no .msh file is saved

BOUNDARY_LAYER = True
BL_FIRST_HEIGHT = 0.0001 # Geometric first-layer height, not a prescribed y+
BL_THICKNESS = 0.010
BL_GROWTH = 1.20

# name: (enabled, fine size, constant-size band, end of size transition)
# Distances are measured from each refinement support, in chord units.
REFINEMENTS = {
    "airfoil":       (True,  0.0060, 0.010, 0.70),
    "leading_edge":  (True,  0.0010, 0.012, 0.08),
    "trailing_edge": (True,  0.0015, 0.012, 0.10),
    "bow_core":      (True,  0.0020, 0.015, 0.10),
    "bow_extension": (True,  0.0080, 0.040, 0.25),
    "sonic_region":  (True,  0.0050, 0.015, 0.10),
    "expansion":     (True,  0.0080, 0.050, 0.22),
    "rear_shocks":   (True,  0.0080, 0.040, 0.25),
    "wake":          (True,  0.0150, 0.050, 0.30),
}


def add_point(geo, x, y):
    """Append a geometric point and return its tag."""
    tag = geo["point"]
    geo["point"] += 1

    geo["text"].append(
        f"Point({tag}) = {{{CHORD*x:.12g}, {CHORD*y:.12g}, 0}};"
    )
    return tag


def add_curve(geo, points, kind="Spline"):
    """Append a Line, Circle, or interpolating Spline."""
    tag = geo["curve"]
    geo["curve"] += 1

    tags = ", ".join(map(str, points))
    geo["text"].append(f"{kind}({tag}) = {{{tags}}};")
    return tag


def add_surface(geo, curves):
    """Append one C-topology block from its signed boundary curves."""
    tag = geo["surface"]
    geo["surface"] += 1

    tags = ", ".join(map(str, curves))
    geo["text"].extend([
        f"Curve Loop({tag}) = {{{tags}}};",
        f"Plane Surface({tag}) = {{{tag}}};"
    ])
    return tag


def create_c_grid(geo):
    """Build five connected blocks: nose, two airfoil sides, and two wakes."""
    # Cosine spacing resolves the rounded leading edge and sharp trailing edge.
    angles = np.linspace(0, np.pi, POINTS_PER_SURFACE)
    x_front = SPLIT_X * (1 - np.cos(angles)) / 2
    x_back = SPLIT_X + (1 - SPLIT_X) * (1 - np.cos(angles)) / 2

    le = add_point(geo, 0, 0)
    te = add_point(geo, 1, 0)
    upper = add_point(geo, SPLIT_X, float(aero.f(SPLIT_X)))
    lower = add_point(geo, SPLIT_X, -float(aero.f(SPLIT_X)))

    # One smooth spline wraps around the nose, from upper to lower surface.
    nose_points = [upper]
    nose_points += [
        add_point(geo, x, float(aero.f(x)))
        for x in x_front[-2:0:-1]
    ]
    nose_points += [le]
    nose_points += [
        add_point(geo, x, -float(aero.f(x)))
        for x in x_front[1:-1]
    ]
    nose_points += [lower]
    nose = add_curve(geo, nose_points)

    top = add_curve(geo, [upper] + [
        add_point(geo, x, float(aero.f(x)))
        for x in x_back[1:-1]
    ] + [te])

    bottom = add_curve(geo, [te] + [
        add_point(geo, x, -float(aero.f(x)))
        for x in x_back[-2:0:-1]
    ] + [lower])

    # Outer C-shaped boundary.
    center = add_point(geo, SPLIT_X, 0)
    outer_top = add_point(geo, SPLIT_X, DOMAIN_RADIUS)
    outer_left = add_point(geo, SPLIT_X - DOMAIN_RADIUS, 0)
    outer_bottom = add_point(geo, SPLIT_X, -DOMAIN_RADIUS)

    top_te = add_point(geo, 1, DOMAIN_RADIUS)
    bottom_te = add_point(geo, 1, -DOMAIN_RADIUS)
    outlet_top = add_point(geo, OUTLET_X, DOMAIN_RADIUS)
    outlet_center = add_point(geo, OUTLET_X, 0)
    outlet_bottom = add_point(geo, OUTLET_X, -DOMAIN_RADIUS)

    arc_top = add_curve(
        geo, [outer_top, center, outer_left], "Circle"
    )
    arc_bottom = add_curve(
        geo, [outer_left, center, outer_bottom], "Circle"
    )

    radial_top = add_curve(geo, [upper, outer_top], "Line")
    radial_bottom = add_curve(geo, [lower, outer_bottom], "Line")

    top_front = add_curve(geo, [outer_top, top_te], "Line")
    bottom_front = add_curve(geo, [outer_bottom, bottom_te], "Line")
    top_rear = add_curve(geo, [top_te, outlet_top], "Line")
    bottom_rear = add_curve(geo, [bottom_te, outlet_bottom], "Line")

    te_top = add_curve(geo, [te, top_te], "Line")
    te_bottom = add_curve(geo, [te, bottom_te], "Line")

    # Shared wake interface between the two downstream blocks.
    wake = add_curve(geo, [te, outlet_center], "Line")
    outlet_up = add_curve(geo, [outlet_center, outlet_top], "Line")
    outlet_down = add_curve(geo, [outlet_bottom, outlet_center], "Line")

    surfaces = [
        add_surface(
            geo,
            [radial_top, arc_top, arc_bottom, -radial_bottom, -nose]
        ),
        add_surface(
            geo,
            [top, te_top, -top_front, -radial_top]
        ),
        add_surface(
            geo,
            [bottom, radial_bottom, bottom_front, -te_bottom]
        ),
        add_surface(
            geo,
            [wake, outlet_up, -top_rear, -te_top]
        ),
        add_surface(
            geo,
            [te_bottom, bottom_rear, outlet_down, -wake]
        ),
    ]

    # Internal block interfaces are not physical boundary conditions.
    groups = {
        "AIRFOIL": [nose, top, bottom],
        "INLET": [arc_top, arc_bottom],
        "FARFIELD": [top_front, bottom_front, top_rear, bottom_rear],
        "OUTLET": [outlet_up, outlet_down],
    }

    for name, curves in groups.items():
        tags = ", ".join(map(str, curves))
        geo["text"].append(
            f'Physical Curve("{name}") = {{{tags}}};'
        )

    tags = ", ".join(map(str, surfaces))
    geo["text"].append(
        f'Physical Surface("FLUID") = {{{tags}}};'
    )

    return groups["AIRFOIL"], le, te, wake


def sampled_points(xy, spacing):
    """Resample a polyline by arc length before building a Distance field."""
    xy = np.asarray(xy, dtype=float)
    s = np.r_[
        0,
        np.cumsum(np.linalg.norm(np.diff(xy, axis=0), axis=1))
    ]

    count = max(2, int(np.ceil(s[-1] / spacing)) + 1)
    targets = np.linspace(0, s[-1], count)

    return np.column_stack([
        np.interp(targets, s, xy[:, i]) for i in (0, 1)
    ])


def inside_fluid(x, y):
    """Check the C-shaped outer domain and exclude the airfoil interior."""
    inside = x <= OUTLET_X and abs(y) <= DOMAIN_RADIUS

    if x < SPLIT_X:
        inside = (
            inside
            and (x - SPLIT_X)**2 + y**2 <= DOMAIN_RADIUS**2
        )

    if 0 <= x <= 1:
        inside = (
            inside
            and abs(y) >= float(aero.f(x)) - 1e-10
        )

    return inside


def add_refinement(geo, name, curves=None, points=None, paths=None):
    """Use Distance + Threshold to prescribe a fine band with gradual growth."""
    enabled, size, width, transition = REFINEMENTS[name]
    if not enabled:
        return

    support = list(points or [])

    # These points control mesh sizes; they are not embedded mesh constraints.
    for path in paths or []:
        for x, y in sampled_points(path, width / 3):
            if inside_fluid(x, y):
                p = add_point(geo, x, y)
                support.append(p)
                geo["helpers"].append(p)

    if not support and not curves:
        return

    distance = geo["field"]
    threshold = distance + 1
    geo["field"] += 2

    geo["text"].extend([
        f"// Refinement: {name}",
        f"Field[{distance}] = Distance;"
    ])

    if curves:
        tags = ", ".join(map(str, curves))
        geo["text"].extend([
            f"Field[{distance}].CurvesList = {{{tags}}};",
            f"Field[{distance}].Sampling = 1000;"
        ])

    if support:
        tags = ", ".join(map(str, support))
        geo["text"].append(
            f"Field[{distance}].PointsList = {{{tags}}};"
        )

    geo["text"].extend([
        f"Field[{threshold}] = Threshold;",
        f"Field[{threshold}].InField = {distance};",
        f"Field[{threshold}].SizeMin = {size * CHORD:.12g};",
        f"Field[{threshold}].SizeMax = {H_FAR * CHORD:.12g};",
        f"Field[{threshold}].DistMin = {width * CHORD:.12g};",
        f"Field[{threshold}].DistMax = {transition * CHORD:.12g};"
    ])

    geo["background"].append(threshold)


def add_physics_refinements(geo, result):
    """Translate approximate wave positions into refinement supports."""
    # Central part of the bow shock.
    y = np.linspace(-result["yS"], result["yS"], 301)
    add_refinement(
        geo,
        "bow_core",
        paths=[np.c_[aero.shock_x(y, result), y]]
    )

    # Lower-confidence extrapolation of the bow shock.
    y = np.linspace(result["yS"], DOMAIN_RADIUS, 801)
    add_refinement(
        geo,
        "bow_extension",
        paths=[
            np.c_[aero.shock_x(y, result), sign * y]
            for sign in (-1, 1)
        ]
    )

    # Approximate sonic transition.
    add_refinement(
        geo,
        "sonic_region",
        paths=[
            [
                (result["xB"], sign * result["yB"]),
                (result["xS"], sign * result["yS"])
            ]
            for sign in (-1, 1)
        ]
    )

    # A collar around the supersonic flanks resolves a distributed expansion.
    # Straight characteristic rays are not treated as exact interior wave paths.
    x = np.linspace(result["xB"], 1, 401)
    add_refinement(
        geo,
        "expansion",
        paths=[
            np.c_[x, sign * aero.f(x)]
            for sign in (-1, 1)
        ]
    )

    # Conditional trailing-edge shock directions.
    _, beta_e, psi = aero.trailing_edge_shock(result)

    if beta_e is not None:
        x = np.linspace(1, OUTLET_X, 401)
        add_refinement(
            geo,
            "rear_shocks",
            paths=[
                np.c_[x, sign * (x - 1) * np.tan(psi)]
                for sign in (-1, 1)
            ]
        )


def finish_mesh_settings(geo, airfoil, te):
    """Combine size fields and optionally add triangular boundary-layer cells."""
    tag = geo["field"]

    if geo["background"]:
        tags = ", ".join(map(str, geo["background"]))
        geo["text"].extend([
            f"Field[{tag}] = Min;",
            f"Field[{tag}].FieldsList = {{{tags}}};",
            f"Background Field = {tag};"
        ])
        tag += 1

    if BOUNDARY_LAYER:
        tags = ", ".join(map(str, airfoil))
        geo["text"].extend([
            f"Field[{tag}] = BoundaryLayer;",
            f"Field[{tag}].CurvesList = {{{tags}}};",
            f"Field[{tag}].Size = {CHORD * BL_FIRST_HEIGHT:.12g};",
            f"Field[{tag}].SizeFar = {CHORD * H_FAR:.12g};",
            f"Field[{tag}].Thickness = {CHORD * BL_THICKNESS:.12g};",
            f"Field[{tag}].Ratio = {BL_GROWTH};",
            f"Field[{tag}].Quads = 0;",
            "// End the layers at the sharp trailing edge shared by the wake blocks.",
            f"Field[{tag}].PointsList = {{{te}}};",
            f"BoundaryLayer Field = {tag};"
        ])

    if geo["helpers"]:
        tags = ", ".join(map(str, geo["helpers"]))
        geo["text"].append(f"Hide {{ Point{{{tags}}}; }}")

    geo["text"].extend([
        "Mesh.Algorithm = 6;",
        "Mesh.ElementOrder = 1;",
        "Mesh.RecombineAll = 0;",
        "Mesh.SubdivisionAlgorithm = 0;",
        "Mesh.MeshSizeFromPoints = 0;",
        "Mesh.MeshSizeFromCurvature = 0;",
        "Mesh.MeshSizeExtendFromBoundary = 0;",
        f"Mesh.MeshSizeMax = {H_FAR * CHORD:.12g};",
        "Geometry.Points = 0;",
        "Mesh.SurfaceEdges = 1;",
        "Mesh.SaveAll = 0;",
        "Mesh.MshFileVersion = 2.2;"
    ])

    if MESH_ON_OPEN:
        geo["text"].append("Mesh 2;")


def write_geo():
    """Write only the .geo file; meshing runs later inside Gmsh."""
    if (
        CHORD <= 0
        or not (0 < SPLIT_X < 1)
        or DOMAIN_RADIUS <= 1
        or OUTLET_X <= 1
    ):
        raise ValueError(
            "Invalid chord, C-domain, or block-split parameters."
        )

    if POINTS_PER_SURFACE < 20:
        raise ValueError(
            "Use at least 20 geometry points per curve segment."
        )

    if BOUNDARY_LAYER and not (
        0 < BL_FIRST_HEIGHT < BL_THICKNESS
        and BL_GROWTH > 1
    ):
        raise ValueError(
            "Invalid boundary-layer height, thickness, or growth."
        )

    for enabled, size, width, transition in REFINEMENTS.values():
        if enabled and not (
            0 < size <= H_FAR
            and 0 < width < transition
        ):
            raise ValueError(
                "Invalid refinement size, band, or transition."
            )

    result = aero.nose_shock(M_INF)

    if result["d"] >= DOMAIN_RADIUS - SPLIT_X:
        raise ValueError(
            "Increase DOMAIN_RADIUS: the predicted shock is outside the inlet."
        )

    geo = {
        "text": [
            'SetFactory("Built-in");',
            f"// C topology, NACA 0012, M_inf = {M_INF:g}, alpha = 0",
            "// Five unstructured triangular blocks; no transfinite constraints."
        ],
        "point": 1,
        "curve": 1,
        "surface": 1,
        "field": 1,
        "background": [],
        "helpers": []
    }

    airfoil, le, te, wake = create_c_grid(geo)

    add_refinement(geo, "airfoil", curves=airfoil)
    add_refinement(geo, "leading_edge", points=[le])
    add_refinement(geo, "trailing_edge", points=[te])
    add_refinement(geo, "wake", curves=[wake])

    add_physics_refinements(geo, result)
    finish_mesh_settings(geo, airfoil, te)

    path = Path(__file__).resolve().parent / OUTPUT_FILE
    path.write_text(
        "\n".join(geo["text"]) + "\n",
        encoding="utf-8"
    )

    print(f"Created {path.name}")
    return path


if __name__ == "__main__":
    write_geo()