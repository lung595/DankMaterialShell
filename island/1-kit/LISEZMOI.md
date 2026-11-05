# Médias de la PR 1 « island: kit (motion rules, frame cadence, widgets) »

Pointe `36a043958` (branche `island/1-kit`), base `origin/master` `88f168c54`. Tout est fait au banc (instance
`pr123-media-kit`, mutter sans écran, niri imbriqué, HOME, XDG et bus isolés), avec le Theme réel de DMS, sur une scène
de banc : un second quickshell lancé dans le banc, qui lit par liens symboliques le `quickshell/` de l'arbre testé (base
ou tête). Rien n'est écrit dans les worktrees. Fond uni : `Theme.surface`, aucun fond d'écran, aucun chemin, aucun
appareil ; textes et données fictifs.

## Ce que la PR rend visible

Peu de choses : le kit n'a aucun appelant dans cette PR (ses consommateurs sont dans les PR 2 et 3). Visible :

1. le ton d'avertissement du mode clair (`Theme.warning`) : `#FF9800` sur master, `#904A00` sur la tête (le mode sombre
   ne change pas) ;
2. les composants du dossier `Modules/DIsland/Kit/`, qui n'existent pas sur master (`git ls-tree` de la base : dossier
   absent), donc pas de capture « avant » pour eux : seulement « après », sur une scène de banc ;
3. la cadence des ressorts de surface (`FrameCadence`, pas de GC d'1 ms) : aucun effet à l'écran, donc aucun média ; ses
   mesures sont dans la perf du contrôleur, pas ici.

## Les fichiers

| Fichier | Ce qu'il montre | Taille |
|---|---|---|
| `avant-ton-avertissement-clair.png` | Base, mode clair : une note d'avertissement réelle de DMS (`SettingsNoteRow`) sur les trois fonds d'une page de réglages, ton `#FF9800`, contraste du texte 2,05 / 1,86 / 1,66 : 1 (sous AA), 680x400 | 40,6 Ko |
| `apres-ton-avertissement-clair.png` | Tête, mode clair, même scène : ton `#904A00`, contraste 6,31 / 5,71 / 5,12 : 1 (AA), 680x400 | 41,9 Ko |
| `avant-ton-avertissement-sombre.png` | Base, mode sombre, même scène : `#FF9800`, 8,63 / 7,58 / 5,70 : 1, 680x400 | 41,5 Ko |
| `apres-ton-avertissement-sombre.png` | Tête, mode sombre : identique à l'avant (même octets), le sombre ne change pas, 680x400 | 41,5 Ko |
| `apres-widgets-clair.png` | Tête, mode clair : les widgets du kit sur une scène (rangée de boutons, boutons icône seule et désactivé, progression en vague, deux liquides, icônes d'appli et de notification, onde d'alerte), prise à 350 ms de la boucle (un bouton enfoncé, le liquide qui monte, un anneau sorti), 800x440 | 40,5 Ko |
| `apres-widgets-sombre.png` | Idem en mode sombre, 800x440 | 43,4 Ko |
| `kit-ressort-sombre.gif` | La scène entière en mouvement, mode sombre : trois boutons enfoncés l'un après l'autre sur le ressort CELL, liquide qui monte et retombe sur le ressort FILL (avec la vague vive du second), progression en vague, icône d'appli qui change de forme puis revient, anneaux de l'onde d'alerte (deux tours). 800x440, 88 images, 25 i/s, 3,5 s | 228,5 Ko |
| `kit-ressort-clair.gif` | Idem en mode clair, 800x440 | 193,4 Ko |
| `kit-boutons-ressort.gif` | Gros plan (x2) des boutons : l'enfoncement au ressort (translation et échelle) et la teinte d'état, 960x272 | 193,3 Ko |
| `kit-liquide.gif` | Gros plan (x2) des deux liquides : la montée avec dépassement et clapotis, puis la retombée, et la vague vive qui ne s'aplatit jamais, 636x360 | 211,8 Ko |
| `kit-icones-alerte.gif` | Gros plan des icônes d'appli et de notification (changement de forme avec impulsion) et de l'onde d'alerte (anneaux de l'alerte critique, deux tours), 800x190 | 84,5 Ko |
| `kit-vague-progression.gif` | Gros plan (x2) de `IslandWaveProgress` : la vague qui dérive et la valeur qui monte et descend, 940x120 | 171,3 Ko |

Tous les GIF : 88 images à 25 i/s, 3,52 s, palette générée à partir des images, boucle infinie, moins de 250 Ko chacun
(limite : 8 Mo). Les six GIF sortent de deux enregistrements au banc (clair et sombre), les gros plans sont des
découpes du sombre. La boucle est faite pour fermer : les ressorts sont posés au début et à la fin, la vague dérive de
1,8 rad/s donc fait un tour en 3491 ms, la vague vive du second liquide aussi. Contrôle (RMSE entre la dernière et la
première image, contre deux images voisines) : au plus 2 fois l'écart de deux images voisines (nul ou presque pour les boutons et les icônes), sauf le liquide
(environ 4 fois, 2379 sur 65535 : la phase de la vague vive n'est poussée qu'à la cadence du kit, d'où un écart de
sous-pixel).

## À savoir pour la description

- Contraste du ton clair, mesuré par la scène (texte contre le fond nu) : 6,31 sur `surface`, 5,71 sur
  `surfaceContainer`, 5,12 sur `surfaceContainerHighest`, ce qui tient la promesse du commit (au moins 4,9 : 1).
- Avec le voile de 12 % de `Theme.warning` que `SettingsNoteRow` pose sous son texte (`warningHover`), le même texte
  tombe à 5,28 / 4,81 / **4,34** : 1 sur ces trois fonds en clair, donc sous AA sur `surfaceContainerHighest` pour ce
  consommateur. Hors de ce que promet le commit (fond nu), mais à ne pas laisser dire « AA partout » dans la
  description ; il peut aller dans « Known limits ».
- Le kit n'a pas d'appelant dans la PR : la scène de banc est la seule façon de le voir ; à dire dans la description.
- Le banc a été construit avec le `go.mod` d'un ancien master (le cache Go hors ligne n'a pas les dux-go et dux-gop
  d'aujourd'hui, comme pour les contrôles de perf) : seul le binaire `dms` est concerné, le QML des deux arbres est celui
  de la base et de la tête.

## Vérification (P7-SCHEMA-kit)

- Aucun fond d'écran (fond uni `Theme.surface`), aucun chemin, aucun nom d'utilisateur, de machine ni d'écran dans les
  octets des fichiers ni à l'image (planche-contact de chaque GIF regardée) : `pr123-media-verif.py`. Ce LISEZMOI citait
  des chemins absolus : remplacés par des chemins relatifs à `~/Dev`.
- Tous les PNG et GIF se décodent jusqu'à la dernière image ; GIF : 88 images, 3 520 ms, boucle infinie, 85 à 229 Ko
  (limite 8 Mo).
- `kit-liquide.gif` refait : l'étiquette « IslandLiquid » était coupée en haut et le cadre décentré ; recadré
  (318x180 à 468,12, x2) depuis `kit-ressort-sombre.gif`, les films du banc n'existant plus
  (`pr123-media-kit-recadre.sh`) ; `pr123-media-kit-gifs.sh` porte le nouveau cadre.
- Symétrie (norme de `symetrie.py`, encre centrée dans sa forme à 1 px) sur les deux captures des widgets : 11 formes
  sur 11 en sombre et en clair (boutons, icônes d'appli et de notification, onde d'alerte) ; les liquides et la vague
  sont hors norme (fronts en mouvement). En clair, trois tuiles pâles (Dismiss enfoncé, courrier, notification
  désactivée) sont sous le seuil de forme de `symetrie.py` : mesurées avec un seuil plus fin
  (`pr123-media-kit-symetrie.py`). Aucune bulle dans cette PR.

## Refaire

Scripts dans `page-niri/outils/ile/` (sous `~/Dev`), dans l'ordre : `pr123-media-kit-arbres.sh` (arbres base et
tête, `git archive`), `pr123-media-kit-banc.sh head|base start|stop`, `pr123-media-kit-stills.sh head|base`
(PNG), `pr123-media-kit-run.sh head widgets dark|light film <dossier>` puis `pr123-media-kit-gifs.sh` (GIF),
`pr123-media-kit-boucle.sh` et `pr123-media-kit-planche.sh` (contrôles de boucle et planche-contact). Les scènes sont
`pr123-media-kit-tone.qml` et `pr123-media-kit-widgets.qml`.
