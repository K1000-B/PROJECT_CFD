# -*- coding: utf-8 -*-
"""Profil symétrique NACA : estimation des ondes et création d'un .geo Gmsh.

Exécution : python naca_supersonique_geo.py
Dépendance Python : python -m pip install numpy

Les paramètres se modifient directement dans ce fichier. Aucun ancien script
n'est appelé. Le seul fichier produit est le .geo ; le maillage sera lancé
manuellement dans Gmsh. Les fonctions servent aux opérations répétées.
"""

import numpy as np


# ============================================================================
# 1. DONNÉES THERMOPHYSIQUES ET GÉOMÉTRIQUES
# ============================================================================

T_inf = 290.0               # Température statique amont [K]
rho_inf = 1.225             # Masse volumique amont [kg/m³]
gamma = 1.4                # Rapport des capacités thermiques, supposé constant
R = 287.0                  # Constante massique de l'air [J/(kg.K)]
M_inf = 1.2                # Mach amont : strictement supérieur à 1

corde = 1.0                # Corde physique [m]
epaisseur = 0.12           # Épaisseur relative : 0.12 donne le NACA 0012
# Le modèle analytique ci-dessous suppose un profil symétrique à incidence nulle.
# Changer l'épaisseur est possible ; ajouter de la cambrure exige un autre modèle.

if M_inf <= 1 or corde <= 0 or not 0 < epaisseur < 1:
    raise ValueError("Il faut M_inf > 1, corde > 0 et 0 < epaisseur < 1.")
if T_inf <= 0 or rho_inf <= 0 or R <= 0 or gamma <= 1:
    raise ValueError("Les données thermophysiques ne sont pas admissibles.")

cp = gamma * R / (gamma - 1)
p_inf = rho_inf * R * T_inf
a_inf = np.sqrt(gamma * R * T_inf)
U_inf = M_inf * a_inf

# Viscosité dynamique selon Sutherland pour l'air [Pa.s].
mu_inf = 1.716e-5 * (T_inf / 273.15)**1.5 * (273.15 + 110.4) / (T_inf + 110.4)
Re_corde = rho_inf * U_inf * corde / mu_inf


# ============================================================================
# 2. PARTIE ANALYTIQUE
# ============================================================================

# Hypothèses : écoulement 2D stationnaire, gaz parfait calorifiquement parfait,
# incidence nulle et symétrie. Les relations de choc sont non visqueuses.
# La couche limite du maillage ne constitue pas un calcul de couche limite.
#
# Le choc détaché suit la fermeture approchée de Moeckel du script initial :
# hyperbole centrale, ligne sonique droite et bilan de débit simplifié.
# Référence : W. E. Moeckel, NACA TN 1921 (1949).
# https://ntrs.nasa.gov/citations/19930082597
#
# L'expansion pariétale et les chocs arrière restent des modèles locaux.
# Leurs interactions ne sont pas résolues. Ils guident les raffinements ;
# ils ne remplacent pas une solution globale des équations d'Euler/RANS.
# Toutes les longueurs analytiques sont ADIMENSIONNÉES par la corde.
# Tous les angles de calcul sont en RADIANS.


def dichotomie(fonction, a, b, precision=1e-11):
    """Résoudre fonction(x)=0 si la fonction continue change de signe sur [a,b]."""
    fa = fonction(a)
    fb = fonction(b)

    if not np.isfinite(fa) or not np.isfinite(fb):
        raise ValueError("Dichotomie : valeur non finie à une borne.")
    if fa == 0:
        return a
    if fb == 0:
        return b
    if fa * fb > 0:
        raise ValueError("Dichotomie : les bornes n'encadrent pas une racine.")

    # On conserve à chaque étape la moitié qui contient le changement de signe.
    for iteration in range(200):
        milieu = (a + b) / 2
        fm = fonction(milieu)

        if not np.isfinite(fm):
            raise ValueError("Dichotomie : valeur non finie dans l'intervalle.")
        if fm == 0 or b - a < precision:
            return milieu

        if fa * fm <= 0:
            b = milieu
        else:
            a = milieu
            fa = fm

    raise ValueError("La dichotomie n'a pas convergé.")


def maximum_intervalle(fonction, a, b):
    """Chercher un maximum pour une fonction à un seul sommet sur [a,b]."""

    # Recherche par tiers : on retire le tiers opposé aux plus grandes valeurs.
    # Cette méthode simple suppose une fonction unimodale sur cet intervalle.
    for iteration in range(80):
        x1 = a + (b - a) / 3
        x2 = b - (b - a) / 3

        if fonction(x1) < fonction(x2):
            a = x1
        else:
            b = x2

    x_max = (a + b) / 2
    return x_max, fonction(x_max)


def demi_epaisseur(x, t):
    """Ordonnée y/c d'un NACA symétrique, avec bord de fuite fermé ; 0<=x<=1."""
    return 5 * t * (
        0.2969 * np.sqrt(x)
        - 0.1260 * x
        - 0.3516 * x**2
        + 0.2843 * x**3
        - 0.1036 * x**4
    )


def pente_profil(x, t):
    """Dérivée de y/c par rapport à x/c ; ne pas évaluer exactement en x=0."""
    return 5 * t * (
        0.14845 / np.sqrt(x)
        - 0.1260
        - 0.7032 * x
        + 0.8529 * x**2
        - 0.4144 * x**3
    )


def angle_paroi(x, t):
    return np.arctan(pente_profil(x, t))


def deviation_choc(M, beta, g):
    """Déviation positive delta donnée par la relation theta-beta-M."""
    numerateur = 2 * (M**2 * np.sin(beta)**2 - 1)
    denominateur = np.tan(beta) * (M**2 * (g + np.cos(2 * beta)) + 2)
    return np.arctan(numerateur / denominateur)


def mach_apres_choc(M, beta, g):
    """Mach total immédiatement après un choc oblique d'angle beta."""
    Mn1 = M * np.sin(beta)
    Mn2_carre = (
        (1 + (g - 1) * Mn1**2 / 2)
        / (g * Mn1**2 - (g - 1) / 2)
    )
    delta = deviation_choc(M, beta, g)

    return np.sqrt(Mn2_carre) / np.sin(beta - delta)


def rapport_pression_totale(Mn1, g):
    """Rapport p02/p01 à travers un choc, à partir du Mach normal amont."""
    A = (g + 1) * Mn1**2 / ((g - 1) * Mn1**2 + 2)
    B = (g + 1) / (2 * g * Mn1**2 - (g - 1))

    return A**(g / (g - 1)) * B**(1 / (g - 1))


def fonction_section_mach(M, g):
    """Rapport A/A* isentropique ; utilisé dans le bilan de débit approché."""
    return (
        2 / (g + 1) * (1 + (g - 1) * M**2 / 2)
    )**((g + 1) / (2 * (g - 1))) / M


def prandtl_meyer(M, g):
    """Angle nu(M) d'une détente isentropique, pour M>=1."""
    A = np.sqrt(M**2 - 1)

    return (
        np.sqrt((g + 1) / (g - 1))
        * np.arctan(np.sqrt((g - 1) / (g + 1)) * A)
        - np.arctan(A)
    )


def mach_depuis_nu(nu, g):
    """Inverser nu(M) par dichotomie, sans imposer une borne M=100."""
    limite = (np.sqrt((g + 1) / (g - 1)) - 1) * np.pi / 2

    if nu < -1e-12 or nu >= limite:
        raise ValueError("Angle de Prandtl-Meyer hors du domaine physique.")
    if nu <= 0:
        return 1.0

    borne = 2.0
    while prandtl_meyer(borne, g) < nu:
        borne = 2 * borne

    # lambda signifie ici simplement : la fonction de M écrite sur une ligne.
    return dichotomie(lambda M: prandtl_meyer(M, g) - nu, 1.0, borne)


def estimation_choc_detache(M, g, t):
    """Position et forme centrales approchées, pour un NACA symétrique à alpha=0."""
    if M <= 1:
        raise ValueError("Le modèle de choc détaché exige M > 1.")

    mu = np.arcsin(1 / M)

    beta_max, delta_max = maximum_intervalle(
        lambda beta: deviation_choc(M, beta, g),
        mu,
        np.pi / 2
    )

    # B : point de paroi où l'angle tangent égale la déviation maximale.
    x_epais = dichotomie(lambda x: pente_profil(x, t), 0.1, 0.5)

    xB = dichotomie(
        lambda x: angle_paroi(x, t) - delta_max,
        1e-12,
        x_epais
    )
    yB = demi_epaisseur(xB, t)

    # S : point du choc derrière lequel le Mach vaut 1.
    beta_s = dichotomie(
        lambda beta: mach_apres_choc(M, beta, g) - 1,
        mu,
        beta_max
    )

    delta_s = deviation_choc(M, beta_s, g)
    k = M**2 - 1
    H = np.sqrt(k**2 * np.tan(beta_s)**2 - k)

    # État représentatif à mi-hauteur de la zone de captation amont.
    beta_c = np.arctan2(np.sqrt(H**2 + k / 4), k / 2)

    perte_p0 = rapport_pression_totale(M * np.sin(beta_c), g)
    flux = 1 / (fonction_section_mach(M, g) * perte_p0)

    denominateur = 1 - flux * np.cos(delta_s)
    if denominateur <= 0:
        raise ValueError("Fermeture de Moeckel non admissible pour ce Mach.")

    yS = yB / denominateur
    L = H * yS

    d = (
        np.sqrt(L**2 + k * yS**2)
        - L
        + (yS - yB) * np.tan(delta_s)
        - xB
    )
    xS = xB - (yS - yB) * np.tan(delta_s)

    if d <= 0:
        raise ValueError("Distance de détachement non positive : modèle invalide.")

    # Un dictionnaire permet de conserver des noms lisibles pour les résultats.
    return {
        "xB": xB,
        "yB": yB,
        "xS": xS,
        "yS": yS,
        "d": d,
        "L": L,
        "k": k,
        "Rc": L / k,
        "delta_max": delta_max,
        "beta_s": beta_s
    }


def abscisse_choc(y, resultat):
    """Hyperbole x(y) : forme rationalisée pour éviter une soustraction imprécise."""
    L = resultat["L"]
    k = resultat["k"]

    return -resultat["d"] + k * y**2 / (
        np.sqrt(L**2 + k * y**2) + L
    )


# Calcul principal 
choc = estimation_choc_detache(M_inf, gamma, epaisseur)

rayon_nez = (5 * epaisseur * 0.2969)**2 / 2

# Hypothèse locale supplémentaire : M(B)=1, puis détente simple à la paroi.
nu_fuite = choc["delta_max"] - angle_paroi(1.0, epaisseur)
M_fuite = mach_depuis_nu(nu_fuite, gamma)
delta_fuite = abs(angle_paroi(1.0, epaisseur))

beta_limite, delta_limite = maximum_intervalle(
    lambda beta: deviation_choc(M_fuite, beta, gamma),
    np.arcsin(1 / M_fuite),
    np.pi / 2
)

# La branche faible existe seulement si la déviation demandée est admissible.
angle_choc_arriere = None

if delta_fuite <= delta_limite:
    beta_fuite = dichotomie(
        lambda beta: deviation_choc(M_fuite, beta, gamma) - delta_fuite,
        np.arcsin(1 / M_fuite),
        beta_limite
    )
    angle_choc_arriere = beta_fuite - delta_fuite

print(f"M_inf = {M_inf:g} ; U_inf = {U_inf:.2f} m/s ; Re_c = {Re_corde:.3e}")
print(f"Rayon du nez / c = {rayon_nez:.7f}")
print(f"B = ({choc['xB']:.6f}, {choc['yB']:.6f})")
print(f"S = ({choc['xS']:.6f}, {choc['yS']:.6f})")
print(
    f"Distance choc-nez / c = {choc['d']:.6f} ; "
    f"Rc/c = {choc['Rc']:.6f}"
)

if angle_choc_arriere is not None:
    print(
        f"Modèle arrière : M = {M_fuite:.4f} ; "
        f"direction du choc = {np.degrees(angle_choc_arriere):.3f} degrés"
    )
else:
    print("Le modèle local ne donne pas de choc arrière attaché.")


# ============================================================================
# 3. CRÉATION DU .GEO ET RÉGLAGES DU FUTUR MAILLAGE
# ============================================================================

# Toutes les valeurs de longueur ci-dessous sont des FRACTIONS DE CORDE.
# Elles ne sont converties en mètres qu'à l'écriture du fichier .geo.

x_amont = -5.0
x_aval = 8.0
demi_hauteur = 5.0

taille_lointaine = 0.1
nb_points_par_face = 161       # Points de géométrie, pas nombre de nœuds du mesh

couche_limite = True
premiere_hauteur = 0.0001       # Hauteur géométrique / c ; aucun y+ n'est imposé
epaisseur_couche = 0.010       # Épaisseur maximale des couches / c
croissance_couche = 1.20       # h_suivante / h_précédente

nom_geo = "NACA_supersonique.geo"  # Écrit dans le dossier de lancement

# RÉGLAGES DES RAFFINEMENTS
#
# Chaque ligne contient quatre paramètres, dans cet ordre :
#
# [activation, taille_fine, distance_fine, distance_lointaine]
#
# 1. activation : True pour utiliser ce raffinement, False pour le désactiver.
#
# 2. taille_fine : taille caractéristique visée pour les éléments dans la zone
#    raffinée. C'est une longueur, pas un nombre de cellules.
#    Une valeur plus petite donne un maillage plus fin.
#
# 3. distance_fine : distance jusqu'à laquelle on conserve la taille_fine
#    autour du support du raffinement : point, profil ou ligne estimée du choc.
#
# 4. distance_lointaine : distance à laquelle la taille demandée rejoint
#    taille_lointaine. Elle est mesurée DEPUIS LE SUPPORT, et non depuis
#    la fin de la bande fine.
#
# Toutes les longueurs sont divisées par la corde :
# une valeur de 0.01 correspond à une longueur physique de 0.01 * corde.
#
# Pour une distance d au support :
#
#   d <= distance_fine :
#       taille demandée = taille_fine
#
#   distance_fine < d < distance_lointaine :
#       augmentation linéaire de taille_fine vers taille_lointaine
#
#   d >= distance_lointaine :
#       taille demandée = taille_lointaine
#
# Exemple pour "profil", avec une corde de 1 m et taille_lointaine = 0.20 :
#   - jusqu'à 0.010 m du profil : taille visée de 0.006 m ;
#   - entre 0.010 et 0.70 m : augmentation progressive vers 0.20 m ;
#   - au-delà de 0.70 m : ce raffinement demande une taille de 0.20 m.
#
# Si plusieurs raffinements se superposent, la PLUS PETITE taille demandée
# est retenue. Un autre raffinement peut donc maintenir un maillage plus fin.
#
# La hauteur NORMALE des cellules de couche limite se règle séparément avec
# premiere_hauteur, epaisseur_couche et croissance_couche. La taille_fine
# ne remplace pas ces paramètres.
#
# Conditions à respecter :
#   0 < taille_fine <= taille_lointaine
#   0 < distance_fine < distance_lointaine

reglages = {
    # Autour de toute la paroi : extrados, nez et intrados.
    "profil":        [True, 0.0060, 0.010, 0.70],

    # Autour du point du bord d'attaque, situé en (x/c, y/c) = (0, 0).
    # Renforce la résolution de la géométrie et de la forte courbure du nez.
    "nez":           [True, 0.0010, 0.012, 0.08],

    # Autour du point du bord de fuite, situé en (1, 0).
    "fuite":         [True, 0.0015, 0.012, 0.10],

    # Autour de la partie centrale du choc détaché estimé :
    # portion de l'hyperbole comprise entre y/c = -yS et y/c = +yS.
    "choc_central":  [True, 0.0020, 0.015, 0.10],

    # Autour du prolongement de l'hyperbole au-delà des points soniques S.
    # Cette position étant moins fiable, la bande fine est plus large.
    "choc_prolonge": [True, 0.0080, 0.040, 0.25],

    # Autour des segments reliant les points B de la paroi aux points S du choc.
    # Ces segments représentent les lignes soniques APPROCHÉES du modèle.
    "zone_sonique":  [True, 0.0050, 0.015, 0.10],

    # Autour des portions de paroi allant de B au bord de fuite.
    # La détente étant distribuée sur les flancs courbes, on raffine ces flancs.
    "detente":       [True, 0.0080, 0.050, 0.22],

    # Autour des deux directions estimées des chocs issus du bord de fuite.
    # Utilisé seulement si le modèle local fournit un choc arrière attaché.
    "chocs_arriere": [True, 0.0080, 0.040, 0.25],

    # Autour de la ligne y = 0, entre le bord de fuite et la sortie du domaine.
    # Raffine le sillage sans créer de frontière interne dans le fluide.
    "sillage":       [True, 0.0150, 0.050, 0.30],
}

# Raffinements libres : ajouter autant de lignes que nécessaire.
#
# Chaque ligne contient :
# [liste de points (x/c,y/c), taille/c, bande/c, transition/c]
#
# Un point seul crée un raffinement local ; plusieurs points décrivent une ligne
# brisée. Ils contrôlent la taille sans créer de frontière interne au maillage.

raffinements_libres = [
    # [[(0.50, 0.20)], 0.003, 0.02, 0.10],
    # [[(0.20, 0.15), (0.80, 0.30), (1.50, 0.60)], 0.005, 0.03, 0.15],
]

if not (
    x_amont < -choc["d"]
    and x_aval > 1
    and demi_hauteur > epaisseur
):
    raise ValueError("Le domaine doit contenir le profil et le choc devant le nez.")

if nb_points_par_face < 30 or taille_lointaine <= 0:
    raise ValueError("Il faut au moins 30 points par face et une taille positive.")

if couche_limite and not (
    0 < premiere_hauteur < epaisseur_couche
    and croissance_couche > 1
):
    raise ValueError("Paramètres de couche limite incorrects.")


# Quelques fonctions d'écriture, identiques pour toute géométrie plane.
# Les listes comptent les objets et donnent des numéros sans compteur global
# à incrémenter.

texte_geo = [
    'SetFactory("Built-in");',
    '// Une surface fluide ; profil intérieur évidé.'
]

points_geo = []
courbes_geo = []
champs_fins = []
points_a_cacher = []


def liste_geo(numeros):
    """Transformer [1,2,3] en '1, 2, 3' pour la syntaxe Gmsh."""
    return ", ".join(str(numero) for numero in numeros)


def ajouter_point(x, y):
    points_geo.append((x, y))
    numero = len(points_geo)

    texte_geo.append(
        f"Point({numero}) = {{{corde*x:.14g}, {corde*y:.14g}, 0}};"
    )
    return numero


def ajouter_courbe(points, type_courbe="Spline"):
    courbes_geo.append(points)
    numero = len(courbes_geo)

    texte_geo.append(
        f"{type_courbe}({numero}) = {{{liste_geo(points)}}};"
    )
    return numero


def ajouter_raffinement(nom, chemins, taille, bande, transition):
    """Champ de taille générique autour de points ou de lignes brisées."""
    if not (
        0 < taille <= taille_lointaine
        and 0 < bande < transition
    ):
        raise ValueError(f"Raffinement incorrect : {nom}")

    numeros = []

    # On échantillonne les segments assez finement pour éviter des 'taches'
    # isolées de raffinement. Ces points ne sont PAS insérés dans le mesh.
    for chemin in chemins:
        positions = []

        if len(chemin) == 1:
            positions.append(chemin[0])

        for i in range(len(chemin) - 1):
            x1, y1 = chemin[i]
            x2, y2 = chemin[i + 1]

            longueur = np.hypot(x2 - x1, y2 - y1)
            n = max(2, int(np.ceil(longueur / (bande / 3))) + 1)

            for fraction in np.linspace(0, 1, n):
                positions.append((
                    x1 + fraction * (x2 - x1),
                    y1 + fraction * (y2 - y1)
                ))

        for x, y in positions:
            # Les points hors du rectangle sont ignorés.
            # Un support placé dans le solide reste permis : c'est une référence
            # de distance, pas un nœud imposé au maillage.
            if x_amont <= x <= x_aval and abs(y) <= demi_hauteur:
                p = ajouter_point(x, y)
                numeros.append(p)
                points_a_cacher.append(p)

    if len(numeros) == 0:
        print(f"Raffinement {nom} : aucun support dans le fluide.")
        return

    # Deux champs par raffinement :
    # 1. Distance aux supports.
    # 2. Taille demandée en fonction de cette distance.
    distance = 2 * len(champs_fins) + 1
    seuil = distance + 1

    texte_geo.extend([
        f"// Raffinement : {nom}",
        f"Field[{distance}] = Distance;",
        f"Field[{distance}].PointsList = {{{liste_geo(numeros)}}};",

        f"Field[{seuil}] = Threshold;",
        f"Field[{seuil}].InField = {distance};",
        f"Field[{seuil}].SizeMin = {taille*corde:.14g};",
        f"Field[{seuil}].SizeMax = {taille_lointaine*corde:.14g};",
        f"Field[{seuil}].DistMin = {bande*corde:.14g};",
        f"Field[{seuil}].DistMax = {transition*corde:.14g};",
    ])

    champs_fins.append(seuil)


# 3.1 Géométrie : rectangle extérieur et trou représentant le profil.
#
# Il n'y a qu'UNE Plane Surface. Les trois splines du profil sont ses bords,
# pas trois blocs. La spline du nez traverse le bord d'attaque sans angle ajouté.

angles = np.linspace(0, np.pi, nb_points_par_face)
x_profil = (1 - np.cos(angles)) / 2
y_profil = demi_epaisseur(x_profil, epaisseur)

# Fermeture exacte malgré les arrondis numériques.
y_profil[-1] = 0.0

points_haut = []
points_bas = []

for x, y in zip(x_profil, y_profil):
    points_haut.append(ajouter_point(x, y))

for i in range(nb_points_par_face):
    if i == 0 or i == nb_points_par_face - 1:
        # Même point au nez et à la fuite pour les deux faces.
        points_bas.append(points_haut[i])
    else:
        points_bas.append(
            ajouter_point(x_profil[i], -y_profil[i])
        )

# Les jonctions de splines sont placées vers 30 % de corde, sur les flancs.
j = int(np.argmin(abs(x_profil - 0.30)))

nez = ajouter_courbe(points_haut[j::-1] + points_bas[1:j+1])
intrados = ajouter_courbe(points_bas[j:])
extrados = ajouter_courbe(points_haut[j:][::-1])

courbes_profil = [nez, intrados, extrados]
point_fuite = points_haut[-1]

# Rectangle extérieur, parcouru dans le sens trigonométrique.
A = ajouter_point(x_amont, -demi_hauteur)
B = ajouter_point(x_aval, -demi_hauteur)
C = ajouter_point(x_aval, demi_hauteur)
D = ajouter_point(x_amont, demi_hauteur)

bas = ajouter_courbe([A, B], "Line")
sortie = ajouter_courbe([B, C], "Line")
haut = ajouter_courbe([C, D], "Line")
entree = ajouter_courbe([D, A], "Line")

texte_geo.extend([
    f"Curve Loop(1) = {{{bas}, {sortie}, {haut}, {entree}}};",
    f"Curve Loop(2) = {{{liste_geo(courbes_profil)}}};",

    # Première boucle : contour extérieur. Deuxième boucle : trou.
    "Plane Surface(1) = {1, 2};",

    f'Physical Curve("AIRFOIL") = {{{liste_geo(courbes_profil)}}};',
    f'Physical Curve("INLET") = {{{entree}}};',
    f'Physical Curve("OUTLET") = {{{sortie}}};',
    f'Physical Curve("FARFIELD") = {{{bas}, {haut}}};',
    'Physical Surface("FLUID") = {1};',
])


# 3.2 Supports des raffinements liés à la physique.
#
# Ce sont des listes de chemins :
# un même raffinement peut avoir plusieurs branches.

supports = {}

supports["profil"] = [
    list(zip(x_profil, y_profil)),
    list(zip(x_profil, -y_profil))
]
supports["nez"] = [[(0.0, 0.0)]]
supports["fuite"] = [[(1.0, 0.0)]]
supports["sillage"] = [[(1.0, 0.0), (x_aval, 0.0)]]

# Partie centrale du choc détaché.
y = np.linspace(-choc["yS"], choc["yS"], 101)

supports["choc_central"] = [
    list(zip(abscisse_choc(y, choc), y))
]

# Prolongement de l'hyperbole : estimation moins fiable que la partie centrale.
supports["choc_prolonge"] = []

if choc["yS"] < demi_hauteur:
    y = np.linspace(choc["yS"], demi_hauteur, 201)

    supports["choc_prolonge"] = [
        list(zip(abscisse_choc(y, choc), y)),
        list(zip(abscisse_choc(y, choc), -y))
    ]

supports["zone_sonique"] = []
supports["detente"] = []
supports["chocs_arriere"] = []

x_detente = np.linspace(choc["xB"], 1, 301)

for signe in [-1, 1]:
    supports["zone_sonique"].append([
        (choc["xB"], signe * choc["yB"]),
        (choc["xS"], signe * choc["yS"])
    ])

    # Une détente sur paroi courbe est distribuée :
    # on raffine le flanc entier.
    supports["detente"].append(
        list(zip(
            x_detente,
            signe * demi_epaisseur(x_detente, epaisseur)
        ))
    )

    if angle_choc_arriere is not None:
        supports["chocs_arriere"].append([
            (1.0, 0.0),
            (
                x_aval,
                signe * (x_aval - 1) * np.tan(angle_choc_arriere)
            )
        ])

# Application des raffinements prédéfinis.
for nom in reglages:
    actif, taille, bande, transition = reglages[nom]

    if actif:
        ajouter_raffinement(
            nom, supports[nom], taille, bande, transition
        )

# Application des raffinements ajoutés librement par l'utilisateur.
for i, reglage in enumerate(raffinements_libres):
    chemin, taille, bande, transition = reglage

    ajouter_raffinement(
        f"libre_{i+1}", [chemin], taille, bande, transition
    )

# On prend la plus petite taille demandée par tous les raffinements actifs.
numero_champ = 2 * len(champs_fins) + 1

if len(champs_fins) > 0:
    texte_geo.extend([
        f"Field[{numero_champ}] = Min;",
        f"Field[{numero_champ}].FieldsList = {{{liste_geo(champs_fins)}}};",
        f"Background Field = {numero_champ};",
    ])

    numero_champ += 1


# 3.3 Couches de QUADRILATÈRES proches de la paroi.
#
# Le champ BoundaryLayer fonctionne dans la même surface fluide.
# Le reste du domaine est triangulaire, avec des nœuds partagés à la transition.
#
# Un rectangle parfait ne suit pas une paroi courbe :
# les quadrilatères s'adaptent à la courbure.
#
# La valeur spéciale -1 demande un raccord quadrangulaire au bord de fuite,
# au lieu d'un éventail radial qui ajoute des triangles au contact de la pointe.
# Ce raccord a été vérifié avec Gmsh 4.15.2.
#
# Documentation :
# https://gmsh.info/doc/texinfo/gmsh.html#Mesh-size-fields

if couche_limite:
    texte_geo.extend([
        f"Field[{numero_champ}] = BoundaryLayer;",
        f"Field[{numero_champ}].CurvesList = {{{liste_geo(courbes_profil)}}};",
        f"Field[{numero_champ}].Size = {premiere_hauteur*corde:.14g};",
        f"Field[{numero_champ}].SizeFar = {taille_lointaine*corde:.14g};",
        f"Field[{numero_champ}].Thickness = {epaisseur_couche*corde:.14g};",
        f"Field[{numero_champ}].Ratio = {croissance_couche};",
        f"Field[{numero_champ}].Quads = 1;",
        f"Field[{numero_champ}].FanPointsList = {{{point_fuite}}};",
        f"Field[{numero_champ}].FanPointsSizesList = {{-1}};",
        f"BoundaryLayer Field = {numero_champ};",
    ])


# Les champs commandent les tailles :
# on désactive les autres sources automatiques de taille.
#
# MeshSizeMin=0 permet de conserver la très petite hauteur normale des couches.

texte_geo.extend([
    "// 1: MeshAdapt, 2: Automatic, 3: Initial mesh only, 5: Delaunay, 6: Frontal-Delaunay, 7: BAMG, 8: Frontal-Delaunay for Quads, 9: Packing of Parallelograms",
    "Mesh.Algorithm = 5;",             # Frontal-Delaunay pour le domaine extérieur
    "Mesh.ElementOrder = 1;",
    "Mesh.RecombineAll = 0;",          # Quads seulement dans la couche limite
    "Mesh.MeshSizeFromPoints = 0;",
    "Mesh.MeshSizeFromCurvature = 0;",
    "Mesh.MeshSizeExtendFromBoundary = 0;",
    "Mesh.MeshSizeMin = 0;",
    f"Mesh.MeshSizeMax = {taille_lointaine*corde:.14g};",
    "Mesh.MshFileVersion = 2.2;",
    "Mesh.SaveAll = 0;",               # Exporter seulement les groupes physiques
    "Geometry.Points = 0;",
    "Mesh.SurfaceEdges = 1;",
])

if len(points_a_cacher) > 0:
    texte_geo.append(
        f"Hide {{ Point{{{liste_geo(points_a_cacher)}}}; }}"
    )


# 3.4 Écriture du seul fichier produit : le .geo autonome.
#
# Le .geo ne contient pas 'Mesh 2;' :
# son ouverture seule ne lance pas le calcul du maillage.

with open(nom_geo, "w", encoding="utf-8") as fichier:
    fichier.write("\n".join(texte_geo) + "\n")

print("Géométrie créée : " + nom_geo)
print("Dans Gmsh : ouvrir ce fichier, puis Mesh > 2D pour générer le maillage.")