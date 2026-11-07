"""Supersonic NACA 0012 at zero angle of attack: approximate report model.

Geometry uses a unit chord. All angles are in radians during calculations.
Moeckel's model describes the central bow shock; the simple expansion and
trailing-edge shocks are conditional models, not a global Euler solution.
"""

import numpy as np
import matplotlib.pyplot as plt
from scipy.optimize import brentq, minimize_scalar


# User parameters
T = 290.0                # K
cp = 1004.0              # J/(kg K), unused for normalized wave locations
gamma = 1.4
R = 287.0                # J/(kg K)
rho = 1.225              # kg/m3, unused for normalized wave locations
M_inf = 2            # Freestream Mach number, greater than 1
num_points = 200


# 1. Symmetric NACA 0012 geometry with a closed trailing edge
def f(x):
    """Upper-surface ordinate y/c as a function of x/c."""
    x = np.asarray(x)
    return 0.6 * (0.2969 * np.sqrt(x) - 0.1260 * x
                  - 0.3516 * x**2 + 0.2843 * x**3 - 0.1036 * x**4)


def f_prime(x):
    """Upper-surface slope; defined only for x > 0."""
    x = np.asarray(x)
    return 0.6 * (0.14845 / np.sqrt(x) - 0.1260
                  - 0.7032 * x + 0.8529 * x**2 - 0.4144 * x**3)


def f_double_prime(x):
    """Derivative of the upper-surface slope; defined for x > 0."""
    x = np.asarray(x)
    return 0.6 * (-0.074225 / x**1.5 - 0.7032
                  + 1.7058 * x - 1.2432 * x**2)


def theta(x):
    """Angle between the upper-surface tangent and the x-axis."""
    return np.arctan(f_prime(x))


def curvature(x):
    """Signed upper-surface curvature for a unit chord."""
    return f_double_prime(x) / (1 + f_prime(x)**2)**1.5


def NACA0012(num_points):
    """Upper- and lower-surface coordinates at zero angle of attack."""
    x = np.linspace(0, 1, num_points)
    return x, f(x), x, -f(x)


# Analytical limit: the slope diverges exactly at the leading edge.
r_LE = (0.6 * 0.2969)**2 / 2


# 2. Local shock relations for a known shock angle
def n(M1, beta):
    """Upstream Mach component normal to the shock."""
    return M1 * np.sin(beta)


def p_shock_ratio(n1, gamma):
    """p2/p1."""
    return 1 + 2 * gamma / (gamma + 1) * (n1**2 - 1)


def rho_shock_ratio(n1, gamma):
    """rho2/rho1."""
    return (gamma + 1) * n1**2 / ((gamma - 1) * n1**2 + 2)


def M2_normal_sq(n1, gamma):
    """Square of the downstream normal Mach number."""
    return (1 + (gamma - 1) * n1**2 / 2) / (
        gamma * n1**2 - (gamma - 1) / 2
    )


def M2(n1, beta, delta, gamma):
    """Full Mach number immediately downstream of an oblique shock."""
    return np.sqrt(M2_normal_sq(n1, gamma)) / np.sin(beta - delta)


def totalPressure_shock_ratio(n1, gamma):
    """Stagnation-pressure ratio p02/p01 across a shock."""
    a = (gamma + 1) * n1**2 / ((gamma - 1) * n1**2 + 2)
    b = (gamma + 1) / (2 * gamma * n1**2 - (gamma - 1))
    return a**(gamma / (gamma - 1)) * b**(1 / (gamma - 1))


def shock_delta(M1, beta):
    """Positive flow deflection from the theta-beta-Mach relation."""
    numerator = 2 * (M1**2 * np.sin(beta)**2 - 1)
    denominator = np.tan(beta) * (
        M1**2 * (gamma + np.cos(2 * beta)) + 2
    )
    return np.arctan(numerator / denominator)


def delta_max(M1):
    """Maximum flow deflection and its corresponding shock angle."""
    mu = np.arcsin(1 / M1)
    optimum = minimize_scalar(
        lambda beta: -shock_delta(M1, beta),
        bounds=(mu, np.pi / 2),
        method="bounded",
        options={"xatol": 1e-13}
    )
    return -optimum.fun, optimum.x


def beta_sonic(M1, beta_at_max):
    """Shock angle for which the downstream Mach number equals one."""
    return brentq(
        lambda beta: M2(
            n(M1, beta), beta, shock_delta(M1, beta), gamma
        ) - 1,
        np.arcsin(1 / M1),
        beta_at_max
    )


def beta_weak(M1, target_delta):
    """Weak-branch oblique-shock angle, if a solution exists."""
    maximum, beta_at_max = delta_max(M1)

    if target_delta > maximum:
        return None
    if np.isclose(target_delta, maximum, atol=1e-12):
        return beta_at_max

    return brentq(
        lambda beta: shock_delta(M1, beta) - target_delta,
        np.arcsin(1 / M1),
        beta_at_max
    )


# 3. Central bow shock: Moeckel's approximate closure
def area_mach(M):
    """Area-Mach function F(M), report equation (5.13)."""
    return (1 / M) * (
        2 / (gamma + 1) * (1 + (gamma - 1) * M**2 / 2)
    )**((gamma + 1) / (2 * (gamma - 1)))


def nose_shock(M):
    """Compute B, S, standoff d, and shock radius, equations (5.6)-(5.17)."""
    if M <= 1:
        raise ValueError("The model requires M_inf > 1.")

    k = M**2 - 1
    delta_d, beta_d = delta_max(M)

    x_max_thickness = brentq(f_prime, 0.1, 0.5)
    xB = brentq(
        lambda x: theta(x) - delta_d,
        1e-10,
        x_max_thickness
    )
    yB = float(f(xB))

    beta_s = beta_sonic(M, beta_d)
    delta_s = shock_delta(M, beta_s)
    H = np.sqrt(k**2 * np.tan(beta_s)**2 - k)

    # Representative flow state at half the upstream capture height YS.
    beta_c = np.arctan2(np.sqrt(H**2 + k / 4), k / 2)
    Pi0 = totalPressure_shock_ratio(n(M, beta_c), gamma)
    B_flux = 1 / (area_mach(M) * Pi0)

    denominator = 1 - B_flux * np.cos(delta_s)
    if denominator <= 0:
        raise ValueError(
            "The mass-flow closure is invalid at this Mach number."
        )

    yS = yB / denominator
    lam = H * yS
    d = (
        np.sqrt(lam**2 + k * yS**2) - lam
        + (yS - yB) * np.tan(delta_s) - xB
    )
    xS = xB - (yS - yB) * np.tan(delta_s)

    if d <= 0:
        raise ValueError(
            "The model predicts a nonpositive shock standoff."
        )

    return {
        "M": M,
        "k": k,
        "delta_d": delta_d,
        "beta_s": beta_s,
        "delta_s": delta_s,
        "xB": xB,
        "yB": yB,
        "xS": xS,
        "yS": yS,
        "lambda": lam,
        "d": d,
        "Rc": lam / k,
        "B_flux": B_flux
    }


def shock_x(y, result):
    """Rationalized hyperbola, avoiding cancellation near y = 0."""
    lam, k = result["lambda"], result["k"]
    y = np.asarray(y)
    return -result["d"] + k * y**2 / (
        np.sqrt(lam**2 + k * y**2) + lam
    )


# 4. Surface potential-flow simple expansion: conditional model
def prandtl_meyer(M):
    """Prandtl-Meyer function nu(M) in radians, defined for M >= 1."""
    a = np.sqrt(M**2 - 1)
    return (
        np.sqrt((gamma + 1) / (gamma - 1))
        * np.arctan(np.sqrt((gamma - 1) / (gamma + 1)) * a)
        - np.arctan(a)
    )


def inverse_prandtl_meyer(nu_target):
    """Find the supersonic Mach number corresponding to nu."""
    if nu_target < -1e-12:
        raise ValueError("A simple expansion requires nu >= 0.")
    if nu_target <= 0:
        return 1.0

    nu_limit = (
        np.sqrt((gamma + 1) / (gamma - 1)) - 1
    ) * np.pi / 2
    if nu_target >= nu_limit:
        raise ValueError(
            "Flow turn exceeds the ideal-gas expansion limit."
        )

    return brentq(
        lambda M: prandtl_meyer(M) - nu_target,
        1.0,
        100.0
    )


def wall_mach_simple(x, result):
    """Wall Mach number, assuming M(B)=1 and nu(M)=delta_d-theta(x)."""
    return inverse_prandtl_meyer(result["delta_d"] - theta(x))


def characteristic_angle(x, result):
    """Initial C+ direction of an upper-surface expansion wave."""
    M = wall_mach_simple(x, result)
    return theta(x) + np.arcsin(1 / M)


# 5. Local trailing-edge recompression: conditional model
def trailing_edge_shock(result):
    """Incident Mach number, weak shock angle, and global shock direction."""
    M_e = wall_mach_simple(1.0, result)
    delta_e = abs(float(theta(1.0)))
    beta_e = beta_weak(M_e, delta_e)

    if beta_e is None:
        return M_e, None, None

    return M_e, beta_e, beta_e - delta_e


def plot_results(result):
    """Plot geometry, indicative waves, and shock trends versus Mach."""
    xu, yu, xl, yl = NACA0012(num_points)
    fig, (ax, ax_trend) = plt.subplots(1, 2, figsize=(15, 5.4))

    ax.plot(xu, yu, "k", lw=2, label="NACA 0012")
    ax.plot(xl, yl, "k", lw=2)

    # Solid line ends at S; the dashed hyperbola is only an extrapolation.
    y_center = np.linspace(-result["yS"], result["yS"], 400)
    ax.plot(
        shock_x(y_center, result),
        y_center,
        "C0",
        lw=2.3,
        label="Central bow shock (Moeckel)"
    )

    y_extension = np.linspace(result["yS"], 0.28, 140)
    for sign in (-1, 1):
        ax.plot(
            shock_x(y_extension, result),
            sign * y_extension,
            "C0--",
            lw=1,
            alpha=0.65
        )

    ax.plot(
        [result["xB"], result["xS"]],
        [result["yB"], result["yS"]],
        "C2:",
        lw=1.5,
        label="Assumed sonic line"
    )
    ax.plot(
        [result["xB"], result["xS"]],
        [-result["yB"], -result["yS"]],
        "C2:",
        lw=1.5
    )

    ax.plot(result["xB"], result["yB"], "o", color="C2")
    ax.plot(result["xS"], result["yS"], "o", color="C2")
    ax.annotate(
        "B",
        (result["xB"], result["yB"]),
        xytext=(7, -14),
        textcoords="offset points"
    )
    ax.annotate(
        "S",
        (result["xS"], result["yS"]),
        xytext=(7, 4),
        textcoords="offset points"
    )

    # Short rays show initial directions; wave interactions are not computed.
    for i, x in enumerate(
        np.linspace(result["xB"] + 0.035, 0.85, 12)
    ):
        angle = characteristic_angle(x, result)
        length = 0.10
        x_end = x + length * np.cos(angle)
        y_end = float(f(x)) + length * np.sin(angle)

        ax.plot(
            [x, x_end],
            [f(x), y_end],
            "C1-",
            alpha=0.6,
            label="Simple expansion (indicative)" if i == 0 else None
        )
        ax.plot(
            [x, x_end],
            [-f(x), -y_end],
            "C1-",
            alpha=0.6
        )

    M_e, beta_e, psi = trailing_edge_shock(result)
    if beta_e is not None:
        length = 0.25
        for sign in (-1, 1):
            ax.plot(
                [1, 1 + length * np.cos(psi)],
                [0, sign * length * np.sin(psi)],
                "C3",
                lw=1.6,
                label=(
                    "Trailing-edge shock (conditional)"
                    if sign == 1 else None
                )
            )

    ax.set(
        xlabel="x/c",
        ylabel="y/c",
        title=f"Estimated waves, M∞ = {result['M']:g}",
        xlim=(-max(0.3, result["d"] + 0.08), 1.3),
        ylim=(-0.29, 0.29)
    )
    ax.set_aspect("equal", adjustable="box")
    ax.grid(alpha=0.25)
    ax.legend(loc="upper right", fontsize=8)

    machs = np.linspace(1.3, 3.0, 70)
    predictions = [nose_shock(M) for M in machs]

    ax_trend.plot(
        machs,
        [p["d"] for p in predictions],
        "C0",
        label="Standoff d/c"
    )
    ax_trend.plot(
        machs,
        [p["Rc"] for p in predictions],
        "C2",
        label="Shock radius Rc/c"
    )
    ax_trend.plot(result["M"], result["d"], "o", color="C0")
    ax_trend.set(
        xlabel="M∞",
        ylabel="Length / chord",
        title="Moeckel predictions (1.3 ≤ M∞ ≤ 3)"
    )
    ax_trend.grid(alpha=0.25)
    ax_trend.legend()

    fig.tight_layout()
    plt.show()


if __name__ == "__main__":
    result = nose_shock(M_inf)
    M_e, beta_e, psi = trailing_edge_shock(result)

    print(f"M∞ = {M_inf:g}; leading-edge radius/c = {r_LE:.7f}")
    print(
        f"B = ({result['xB']:.6f}, {result['yB']:.6f}) ; "
        f"S = ({result['xS']:.6f}, {result['yS']:.6f})"
    )
    print(
        f"Shock standoff d/c = {result['d']:.6f}; "
        f"shock radius Rc/c = {result['Rc']:.6f}"
    )
    print(
        f"β_s = {np.degrees(result['beta_s']):.3f}° ; "
        f"δ_max = {np.degrees(result['delta_d']):.3f}°"
    )

    if beta_e is None:
        print(
            "No attached trailing-edge shock in this local model "
            f"(Me = {M_e:.4f})."
        )
    else:
        print(
            f"Conditional trailing-edge model: Me = {M_e:.4f}, "
            f"β_e = {np.degrees(beta_e):.3f}°, "
            f"ψ = {np.degrees(psi):.3f}°"
        )

    plot_results(result)