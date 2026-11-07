# Médias de la PR 1 « island: kit (motion rules, frame cadence, widgets) »

Pointe `6a58a5818` (branche `island/1-kit`), base `origin/master` `88f168c54`. Tout est fait au banc (mutter sans écran,
niri imbriqué, HOME, XDG et bus isolés), avec le Theme réel de DMS, sur une scène de banc : un second quickshell lancé
dans le banc, qui lit par liens symboliques le `quickshell/` de l'arbre testé (base ou tête). Rien n'est écrit dans les
worktrees. Fond uni : `Theme.surface`, aucun fond d'écran, aucun chemin, aucun appareil ; textes et données fictifs.

Les médias ont été pris une première fois sur `36a043958` (instance `pr123-media-kit`), puis la correction de la boucle
(5 et 6/11) a changé le rendu du kit : `IslandWaveProgress` est retiré (aucun appelant sur la pile) et `IslandLiquid` n'a
plus de vague vive (`wave`, son horloge et sa phase). Les médias qui montraient l'un ou l'autre sont refaits sur
`6a58a5818` (instance `c123-media-kit`) ; les autres sont gardés, après contrôle (voir « Ce qui a changé »).

## Ce que la PR rend visible

Peu de choses : le kit n'a aucun appelant dans cette PR (ses consommateurs sont dans les PR 2 et 3). Visible :

1. le ton d'avertissement du mode clair (`Theme.warning`) : `#FF9800` sur master, `#904A00` sur la tête (le mode sombre
   ne change pas) ;
2. les composants du dossier `Modules/DIsland/Kit/`, qui n'existent pas sur master (`git ls-tree` de la base : dossier
   absent), donc pas de capture « avant » pour eux : seulement « après », sur une scène de banc ;
3. la cadence des ressorts de surface (`FrameCadence`, pas de GC d'1 ms) : aucun effet à l'écran, donc aucun média ; ses
   mesures sont dans `mesures.md`.

## Ce qui a changé depuis la première prise (36a043958 vers 6a58a5818)

| Changement du code | Effet sur le rendu | Médias |
|---|---|---|
| `IslandWaveProgress.qml` retiré | la progression en vague n'existe plus | `kit-vague-progression.gif` supprimé ; la scène de banc et les deux prises des widgets n'ont plus la rangée de progression |
| `IslandLiquid.qml` : plus de vague vive (`wave`) | le front ne bouge que pendant que le ressort de remplissage bouge, puis reste plat ; le second liquide de la scène est donc au repos | `kit-liquide.gif`, `kit-ressort-*.gif`, `apres-widgets-*.png` refaits |
| `Theme.qml` : `#FF9800` devient la constante `stockWarning` | aucun : même valeur, même test | `*-ton-avertissement-*.png` gardés ; scène rejouée sur la tête : mêmes rapports de contraste, écart de 2,2 (sombre) et 2,8 (clair) sur 65535 (RMSE) avec les prises gardées |
| `IslandButton` (infobulle d'un libellé coupé, avertissement sans nom accessible), `IslandNoticeIcon` (initiale d'un message sur une forme d'alerte, `Loader`), `IslandAlertWave` (au moins un anneau, arrêt au mouvement réduit), `IslandDecorClock` et `IslandClock` (taux borné), `IslandKit.js` | aucun sur la scène : pas de libellé coupé, pas d'initiale sur une forme d'alerte, mêmes ressorts, mêmes anneaux | `kit-boutons-ressort.gif` et `kit-icones-alerte.gif` gardés : une nouvelle prise des mêmes plans donne un écart moyen de 410 et 525 sur 65535 (RMSE, image à image), du même ordre qu'un pas de mouvement (373 et 698 entre deux images voisines) |

## Les fichiers

| Fichier | Ce qu'il montre | Taille |
|---|---|---|
| `avant-ton-avertissement-clair.png` | Base, mode clair : une note d'avertissement réelle de DMS (`SettingsNoteRow`) sur les trois fonds d'une page de réglages, ton `#FF9800`, contraste du texte 2,05 / 1,86 / 1,66 : 1 (sous AA), 680x400 | 40,6 Ko |
| `apres-ton-avertissement-clair.png` | Tête, mode clair, même scène : ton `#904A00`, contraste 6,31 / 5,71 / 5,12 : 1 (AA), 680x400 | 41,9 Ko |
| `avant-ton-avertissement-sombre.png` | Base, mode sombre, même scène : `#FF9800`, 8,63 / 7,58 / 5,70 : 1, 680x400 | 41,5 Ko |
| `apres-ton-avertissement-sombre.png` | Tête, mode sombre : identique à l'avant (même octets), le sombre ne change pas, 680x400 | 41,5 Ko |
| `apres-widgets-clair.png` | Tête, mode clair : les widgets du kit sur une scène (rangée de boutons, boutons icône seule et désactivé, deux liquides dont un au repos, icônes d'appli et de notification, onde d'alerte), prise à 350 ms de la boucle (un bouton enfoncé, le liquide qui monte, un anneau sorti), 800x440 | 37,2 Ko |
| `apres-widgets-sombre.png` | Idem en mode sombre, 800x440 | 39,3 Ko |
| `kit-ressort-sombre.gif` | La scène entière en mouvement, mode sombre : trois boutons enfoncés l'un après l'autre sur le ressort CELL, liquide qui monte et retombe sur le ressort FILL (l'autre liquide reste plat), icône d'appli qui change de forme puis revient, anneaux de l'onde d'alerte (deux tours), 800x440 | 147,4 Ko |
| `kit-ressort-clair.gif` | Idem en mode clair, 800x440 | 136,1 Ko |
| `kit-boutons-ressort.gif` | Gros plan (x2) des boutons : l'enfoncement au ressort (translation et échelle) et la teinte d'état, 960x272 (première prise, gardée) | 193,3 Ko |
| `kit-liquide.gif` | Gros plan (x2) des deux liquides : à gauche la montée avec dépassement et clapotis, puis la retombée, à droite un liquide au repos qui reste plat, 636x360 | 85,0 Ko |
| `kit-icones-alerte.gif` | Gros plan des icônes d'appli et de notification (changement de forme avec impulsion) et de l'onde d'alerte (anneaux de l'alerte critique, deux tours), 800x190 (première prise, gardée) | 84,5 Ko |

Tous les GIF : 88 images à 25 i/s, 3,52 s, palette générée à partir des images, boucle infinie, moins de 200 Ko chacun
(limite : 8 Mo). Les cinq GIF sortent de deux enregistrements au banc (clair et sombre), les gros plans sont des
découpes du sombre. La boucle dure 3 491 ms comme à la première prise (le temps d'un tour de l'ancienne vague, gardé
pour que les gros plans gardés restent calés sur la scène) et se ferme : les ressorts sont posés au début et à la fin.
Contrôle (RMSE sur 65535 entre la dernière et la première image) : `kit-ressort-sombre.gif` 21,5, `kit-ressort-clair.gif`
0,5, `kit-liquide.gif` 3,7, contre 67,3, 35,7 et 0 entre deux images voisines au milieu de la boucle (le liquide y est
plat) : un saut de boucle ne se voit pas. Pour les deux gros plans gardés, le contrôle de la première prise (au plus 2
fois l'écart de deux images voisines, nul ou presque pour les boutons et les icônes) reste le leur.

## À savoir pour la description

- Contraste du ton clair, mesuré par la scène (texte contre le fond nu), rejoué sur `6a58a5818` avec les mêmes chiffres :
  6,31 sur `surface`, 5,71 sur `surfaceContainer`, 5,12 sur `surfaceContainerHighest`, ce qui tient la promesse du commit
  (au moins 4,9 : 1).
- Avec le voile de 12 % de `Theme.warning` que `SettingsNoteRow` pose sous son texte (`warningHover`), le même texte
  tombe à 5,28 / 4,81 / **4,34** : 1 sur ces trois fonds en clair, donc sous AA sur `surfaceContainerHighest` pour ce
  consommateur. Hors de ce que promet le commit (fond nu), mais à ne pas laisser dire « AA partout » dans la
  description ; il peut aller dans « Known limits ».
- Le kit n'a pas d'appelant dans la PR : la scène de banc est la seule façon de le voir ; à dire dans la description.
- Le banc a été construit avec le `go.mod` d'un ancien master (le cache Go hors ligne n'a pas les dux-go et dux-gop
  d'aujourd'hui, comme pour les contrôles de perf) : seul le binaire `dms` est concerné, le QML des deux arbres est celui
  de la base et de la tête.

## Vérification (C4-MEDIAS-kit)

- Aucun fond d'écran (fond uni `Theme.surface`), aucun chemin, aucun nom d'utilisateur, de machine ni d'écran dans les
  octets des fichiers ni à l'image (planche-contact de chaque GIF regardée) : `pr123-media-verif.py` sur le dossier,
  « OK ». Les chemins du présent fichier sont relatifs à `~/Dev`.
- Tous les PNG et GIF se décodent jusqu'à la dernière image ; GIF : 88 images, 3 520 ms, boucle infinie, 84 à 193 Ko
  (limite 8 Mo).
- Symétrie (norme de `symetrie.py`, encre centrée dans sa forme à 1 px, `pr123-media-kit-symetrie.py`) sur les deux
  prises des widgets de la tête : 11 formes sur 11 en sombre et en clair (boutons, icônes d'appli et de notification,
  onde d'alerte) ; les liquides sont hors norme (front en mouvement). En clair, trois tuiles pâles (Dismiss enfoncé,
  courrier, notification désactivée) sont sous le seuil de forme de `symetrie.py` : mesurées avec un seuil plus fin.
  Aucune bulle dans cette PR.
- Reprise du 7/11 : la pointe est toujours `6a58a5818` (aucun commit depuis), le rendu n'a pas changé, aucune capture refaite ; `mesures.md` est remis à jour depuis `perf-final-2.md` (01:32), `testeur-final-2.md` et `relecteur-final-2.md`. Vérification et symétrie rejouées, « OK ».

## Refaire

Scripts dans `page-niri/outils/ile/` (sous `~/Dev`), dans l'ordre : `c123-media-kit-gen.sh` (écrit les `c123-media-kit-*`
à partir des `pr123-media-kit-*`, une fois), `c123-media-kit-arbres.sh` (copie de la tête par `git archive`),
`c123-media-kit-banc.sh head start|stop`, `c123-media-kit-run.sh head widgets dark|light still|film <sortie> [ms]` (les
PNG des widgets et les films), `c123-media-kit-gif.sh` ou `c123-media-kit-gifs.sh` (GIF), `c123-media-kit-boucle.sh` et
`c123-media-kit-planche.sh` (contrôles de boucle et planche-contact), `c123-media-kit-compare.sh` (deux GIF d'une même
scène, image par image). La scène des widgets est `c123-media-kit-widgets.qml` (sans progression ni vague vive) ; celle
du ton, `c123-media-kit-tone.qml`. Les `pr123-media-kit-*` refont la première prise sur `36a043958` (base et tête).
