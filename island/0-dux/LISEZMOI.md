# Médias de la PR 0 : indicateur de chargement (dux-qml-common)

PR 0 « loading indicator (Material shapes) » : branche `island/common`, tête `2a60fbc`, contre `origin/master` de dux-qml-common `e4e3353`.

Ce que la PR change pour qui regarde : `DLoadingIndicator` laisse l'appelant choisir ses formes (`shapes`, noms du catalogue ou rayons polaires), et piloter lui-même le morphing (`fromShape`, `toShape`, `morph`, `angle` avec `running: false`). Le rendu par défaut ne change pas.

Revu le 6/11 (étape C4 de la boucle de correction) : la tête `island/common` est toujours `2a60fbc`, aucun commit depuis la prise des médias. Les 4 planches et les 4 GIF sont donc inchangés et valides (aucune nouvelle capture). Contrôles refaits : aucune chaîne personnelle (chemin, nom, fond d'écran) dans les images ni dans les textes ; fond uni, formes seules ; GIF de 119 à 196 Ko, bien sous 8 Mo ; `symetrie.py` sur la forme ronde de la planche ne trouve aucune icône à mesurer (la PR 0 ne dessine ni bulle, ni pastille, ni face de l'île).

## Fichiers

| Fichier | Ce qu'il montre | Taille |
|---|---|---|
| `board-before-light.png` | Avant (base), thème clair : l'indicateur par défaut à 8 instants (6 simples, 2 « contained »), puis la mention que choisir ses formes, donner ses rayons polaires et piloter le morphing est impossible | 108 504 o, 1200x700 |
| `board-after-light.png` | Après (tête), thème clair : la même ligne par défaut, puis les 8 formes du catalogue choisies par l'appelant, 4 formes à rayons polaires propres (cinq pétales, trois lobes, œuf, lentille), et le morphing piloté de `cookie4` vers `pill` à 0, 0,25, 0,5, 0,75 et 1 | 110 522 o, 1200x700 |
| `board-before-dark.png` | Idem avant, thème sombre | 109 798 o, 1200x700 |
| `board-after-dark.png` | Idem après, thème sombre | 113 111 o, 1200x700 |
| `morph-default-light.gif` | L'indicateur par défaut qui morphe entre ses 7 formes (même séquence, même ressort que le défaut), pilotée par l'appelant ; thème clair ; boucle de 4,56 s | 195 552 o, 320x320, 114 images à 25 i/s |
| `morph-default-dark.gif` | Idem, thème sombre | 195 323 o, 320x320, 114 images à 25 i/s |
| `morph-custom-light.gif` | Ce que la PR rend possible : 4 formes choisies par l'appelant (`pill`, cinq pétales en rayons polaires, `sunny`, trois lobes en rayons polaires), morphing et angle pilotés ; thème clair ; boucle de 2,6 s | 119 600 o, 320x320, 65 images à 25 i/s |
| `morph-custom-dark.gif` | Idem, thème sombre | 119 304 o, 320x320, 65 images à 25 i/s |

Tous les GIF font moins de 200 Ko (limite 8 Mo), boucle infinie, 4 centièmes de seconde par image (25 i/s), palette générée par ffmpeg (`palettegen` puis `paletteuse`, 64 couleurs, sans tramage).

Pas de GIF « avant » : le défaut de la base est le même que celui de la tête (voir les mesures), donc un seul GIF par thème pour le défaut ; le « avant » est montré par les planches.

## Comment c'est fait

- Au banc seulement : instance `pr123-media-dux` (mutter sans écran, niri imbriqué, rendu logiciel, écran de 1280x800), sur un worktree DMS jetable retiré en fin de lot. Une fenêtre QML plein écran (`qml-qt6`) y tourne comme client Wayland, fond uni neutre (couleurs Material de base, clair `#FEF7FF`, sombre `#141218`), aucune donnée personnelle. Les captures sont des captures de l'écran du niri du banc (`screenshot-screen`), recadrées par ffmpeg ou ImageMagick.
- Avant = `DCommon` de `origin/master` (`git archive`), après = le worktree `pr123-dqc` à `2a60fbc`. Les deux lisent un faux `Style` aux couleurs Material de base (les défauts du vrai `Style`), clair ou sombre.
- Animation image par image : le banc en rendu logiciel tourne très en dessous du temps réel. La scène avance donc son horloge d'animation par pas fixes (une ligne d'un fichier de commande par image) et chaque image est une capture de l'écran à cet instant exact. Aucune image doublée (0 reprise sur les 358 images), puis assemblage ffmpeg à 25 i/s.
- Boucle propre : le défaut de l'amont n'est pas périodique (la rotation de 4 666 ms n'est pas un multiple du cycle de 7 formes de 4 550 ms). Les GIF sont donc faits avec l'API pilotée par l'appelant : pour le GIF par défaut, mêmes formes, même ressort et même pas de 650 ms que le défaut, avec une rotation continue réglée à 1,25 tour par cycle pour que la boucle se referme (le défaut tourne à 351 degrés par cycle : le mouvement de rotation est un peu plus rapide ici). Pour le GIF des formes propres, 1 tour par cycle.

## Mesures

| Contrôle | Résultat |
|---|---|
| Ligne par défaut, avant contre après, clair | 4 pixels sur 133 500 diffèrent, écart maximal 3 sur 255 |
| Ligne par défaut, avant contre après, sombre | 4 pixels sur 133 500 diffèrent, écart maximal 5 sur 255 |
| Base : `shapes: ["pill"]` | `Invalid property assignment: "shapes" is a read-only property` (le composant n'a pas de forme à choisir) |
| Raccord de boucle (EQM de l'image 114 contre l'image 1, échelle 0 à 65535) | défaut clair 4 030, sombre 5 692 ; propre clair 2 150, sombre 3 037 ; dans la fourchette des pas ordinaires (défaut clair : 1 510 à 7 039, médiane 3 033) |
| Images identiques à la suivante pendant la prise | 0 sur 358 |

Les 4 pixels d'écart du rendu par défaut sont au niveau de l'arrondi flottant de la bascule du centre des formes vers le GPU (dernier commit de la PR) ; le test hors écran du lot dux donne 0 pixel d'écart sur le même cas.

## Outils (page-niri/outils/ile/)

`pr123-media-dux-bed.sh` (monte la scène : tête, base, faux `Style`), `pr123-media-dux-scene.qml` et `pr123-media-dux-scene.sh` (la scène et son lanceur dans le banc), `pr123-media-dux-run.sh boards|films` (prise des captures), `pr123-media-dux-post.sh` (recadrage, GIF, mesures), `pr123-media-dux-seam.sh` (raccord de boucle).

## Limites

Planches et GIF montrent des formes seules sur fond uni : la PR 0 ne touche aucun écran de DMS, l'indicateur n'apparaît dans l'île qu'avec la PR 3. Le rendu est logiciel (Mesa) : l'aspect est celui du shader, pas la fluidité d'un écran réel.
