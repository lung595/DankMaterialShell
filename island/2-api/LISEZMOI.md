# Médias de la PR 2 « island: activities API and scripts over IPC »

Tout est pris au banc (instance `pr123-media-api`, écran virtuel 1280x720, fond uni neutre, aucune donnée de la machine :
barre réduite au lanceur, aux espaces de travail et à deux boutons, aucun appareil). Cadrage : la bande de l'île, agrandie
deux fois pour les PNG.

- **Avant** : base `island/1-kit`, la PR en moins. Prise sur 36a043958 ; la base est maintenant 6a58a5818 (voir
  « Mise à jour du 6/11 » : rien n'a changé à l'image).
- **Après** : tête `island/2-api`. Prise sur b302f1df6 ; la tête est maintenant c9b7850d9 (idem, voir « Mise à jour du
  7/11 » : rendu inchangé).
- Ce que la PR rend visible : un script (ou un plugin) montre une activité sur l'île avec `dms ipc call island activity`,
  la met à jour, la termine. Avant, l'appel est refusé et l'île reste sur son horloge.

## Fichiers

| Fichier | Ce qu'il montre | Taille |
|---|---|---|
| `avant-idle-dark.png` | Avant, thème sombre : les mêmes appels IPC ne changent rien, l'île reste sur son horloge (800x140) | 6,3 Ko |
| `avant-idle-light.png` | Idem en thème clair | 6,8 Ko |
| `avant-ipc.txt` | Avant : la réponse de `dms ipc call island activity ...` (`Function not found.`) | 0,1 Ko |
| `apres-live-compact-dark.png` | Après, sombre : une activité « live », bulle compacte avec icône, anneau de progression (60 %), titre et texte (800x140) | 8,9 Ko |
| `apres-live-compact-light.png` | Idem en clair | 9,7 Ko |
| `apres-alert-sheet-dark.png` | Après, sombre : une activité « alert » s'ouvre seule en feuille, titre, texte et trois boutons (1120x460) | 18,7 Ko |
| `apres-alert-sheet-light.png` | Idem en clair | 19,5 Ko |
| `apres-live-sheet-dark.png` | Après, sombre : l'activité live ouverte en feuille (`island open activity`) avec l'anneau et deux boutons, le focus clavier sur le premier (1120x460) | 18,8 Ko |
| `apres-live-sheet-light.png` | Idem en clair | 19,5 Ko |
| `apres-accents-dark.png` | Après, sombre : la même bulle avec les accents `primary`, `success`, `warning`, `error` (quatre bulles, de haut en bas dans cet ordre) (800x560) | 31,2 Ko |
| `apres-accents-light.png` | Idem en clair ; en clair `success` et `error` se replient sur le texte de la surface et le disent en mots (choix du kit, contraste) | 34,5 Ko |
| `apres-ipc-live-dark.gif` | Animation, sombre, 25 i/s, 8 s : l'île sur l'horloge, la bulle arrive, la progression monte de 0 à 100 % par `activityUpdate`, passe en « Backup done » (accent `success`), `activityEnd` rend l'horloge ; boucle propre (première et dernière image égales) (640x104, 199 images) | 142,6 Ko |
| `apres-ipc-live-light.gif` | Idem en clair (201 images) | 169,8 Ko |
| `apres-ipc-alert-dark.gif` | Animation, sombre, 25 i/s, 5 s : une alerte s'ouvre en feuille avec trois boutons, puis `activityEnd` referme la feuille et rend l'horloge ; boucle propre (560x230, 132 images) | 63,0 Ko |
| `apres-ipc-alert-light.gif` | Idem en clair | 77,8 Ko |
| `apres-ipc.txt` | Après : transcription des appels (`activity`, `activityStatus`, `activityUpdate`, `activityEnd`) et des réponses, dont les refus `ISLAND_ACTIVITY_NO_CONTENT` et `ISLAND_ACTIVITY_BAD_DATA` | 0,7 Ko |
| `demo-ipc.sh` | Le script de démonstration des deux GIF (`demo-ipc.sh live` ou `alert`), appels `dms ipc call island ...` ; au banc, `DMS` pointe sur le `dms` du banc | 1,5 Ko |

Tous les GIF font moins de 200 Ko (limite : 8 Mo) ; le dossier entier fait environ 0,65 Mo.

## Ce qui n'est pas montré

- Le clic réel sur un bouton d'action (et la réponse de `activityStatus` après le clic) : la souris simulée n'est pas
  calée sur l'écran 1280x720 du banc ; le premier bouton est seulement montré avec son focus clavier.
- Plusieurs écrans (`activityOn`, écran `*`), la priorité alert > live > glance et le délai d'une activité « glance » :
  couverts par les tests de la PR, pas filmés.

## Mise à jour du 6/11 (C4-MEDIAS-api, boucle de correction)

Depuis les captures du 5/11, la PR a été corrigée (pointe `b302f1df6` devenue `b222553ef`, base du kit `36a043958`
devenue `6a58a5818`) : le diff touche 32 fichiers hors tests, dont les faces prêtes (`ReadyActivityCompact`,
`ReadyActivityExpanded`, `ReadyActivityRing`), le kit (`IslandAlertWave`, `IslandButton`, `IslandNoticeIcon`,
`IslandAppIcon`) et la nouvelle `IslandPluginActivity.qml`. Avant de refaire quoi que ce soit, le rendu a été comparé à la
nouvelle pointe, au banc `c123-media-api` (mêmes réglages : fond uni neutre, 1280x720, aucun appareil) :

- Les 8 PNG de l'après, refaits à neuf puis comparés pixel à pixel aux fichiers du dossier : écart de 1 à 2 sur 255 sur
  quelques pixels (lissage), rien d'autre.
- Les 4 GIF, refilmés à neuf puis comparés image à image (au début, à 10, 30, 50, 70, 90 % et à la fin) : même nombre
  d'images (199 contre 199 en sombre, 201 contre 199 en clair, 132 contre 132 pour les deux alertes), mêmes scènes. Les
  seules différences sont l'heure de l'horloge au repos (celle du banc) et l'avancement de l'anneau à un instant donné
  (minutage de la prise). Boucle propre et animés, comme avant.
- L'avant (île sur son horloge) : entre `36a043958` et `6a58a5818` le kit ne change que des fichiers de `Kit/`, des
  calculs (`IslandKit.js`, `IslandClock.js`, `FrameCadence.js`), un nom de constante dans `Theme.qml` et des
  commentaires ; aucun fichier de l'île ne se sert encore des composants du kit sans la PR 2, donc l'horloge au repos ne
  change pas. Pas refait.
- Conclusion : aucune capture ni aucun GIF remplacé, les fichiers de ce dossier restent ceux du 5/11 et valent pour la
  nouvelle pointe. Les refaits de contrôle ne sont pas gardés.

## Mise à jour du 7/11 (C4-MEDIAS-api, 2e passe)

La pointe est passée de `b222553ef` à `c9b7850d9` (deux commits réécrits ; le diff entre les deux tient en deux fichiers
et quatre lignes) : `IslandController.qml` (`outsideClickCollapses` ne lève plus la couche de clic dehors pour une
feuille de plugin ouverte sans clavier) et `IslandFreeHostWindow.qml` (l'île libre se réveille quand `holdsHost` change).
Le banc de ces médias héberge l'île dans la barre (hôte de barre), jamais en mode libre, et aucun clic n'est joué : ni
l'une ni l'autre ne touche à ce que les captures montrent. Vérifié au lieu d'être supposé : le banc `c123-media-api`
relancé sur `c9b7850d9` (mêmes réglages : fond uni neutre, 1280x720, aucun appareil), toutes les captures refaites à neuf
dans un dossier de travail puis comparées au contenu de ce dossier :

- Les 8 PNG de l'après : écart de 1 à 2 sur 255 sur quelques pixels (lissage), aucun pixel au-delà de 3 %.
- Les 4 GIF : mêmes nombres d'images qu'avant (199 contre 199 en sombre, 199 contre 201 en clair, 132 contre 132 pour les
  deux alertes), mêmes scènes. Les seules différences : l'heure de l'horloge au repos (celle du banc, première et
  dernière images) et, sur les images du milieu, 0,2 à 1 % de pixels au plus (écart max 74 sur 255) dus à la palette du
  GIF, à l'avancement de l'anneau à un instant donné (minutage de la prise) ; vu à l'œil sur la feuille d'alerte, les
  deux images sont les mêmes.
- L'avant (île sur son horloge) : le kit est resté à `6a58a5818`, rien à refaire.
- Conclusion : aucune capture ni aucun GIF remplacé, les fichiers de ce dossier restent ceux du 5/11 et valent pour la
  pointe `c9b7850d9`. Les refaits de contrôle ne sont pas gardés.
- Hors du champ de ces médias : la veille de l'île libre sous une activité sans fin (testeur final 2, `veille-*.png` dans
  ses preuves) et la couche de clic sous une alerte (testeur final 2, `alerte-tete.png`) ne sont pas filmées ici.

## Reproduire

Scripts dans `page-niri/outils/ile/` (préfixe `pr123-media-api-`). Le 6/11, les mêmes scripts sous l'instance
`c123-media-api` (préfixe `c123-media-api-`, copies faites par `c123-media-api-copie.sh`), la comparaison des GIF par
`c123-media-api-gifcmp.sh <ancien> <nouveau> <dossier>` et le contrôle des données et des tailles par
`c123-media-api-prive.sh <dossier média> <dossier de travail>` :

| Script | Rôle |
|---|---|
| `pr123-media-api-banc.sh avant\|apres\|stop` | Lance (ou arrête) le banc sur `wt/pr123-kit` (avant) ou `wt/pr123-api` (après), île allumée |
| `pr123-media-api-reglages.py` | Réglages du banc : fond uni par thème, barre réduite, notifications de capture de niri ignorées |
| `pr123-media-api-stills.sh avant\|apres dark\|light` | Les PNG |
| `pr123-media-api-film.sh <nom> dark\|light live\|alert` | Un GIF (captures d'écran rapprochées, cadence reprise par ffmpeg, une palette) |
| `pr123-media-api-ipc.sh` | Les transcriptions `avant-ipc.txt` et `apres-ipc.txt` |
| `pr123-media-api-demo.sh` | Le script de démonstration (copie : `demo-ipc.sh`) |
| `c123-media-api-passe2.sh <dossier de travail>` | 7/11 : banc sur la tête, les 8 PNG et les 4 GIF refaits dans le dossier de travail (jamais dans celui-ci), comparaison à ce dossier ; `c123-media-api-passe2b.sh <dossier> <thème> <live\|alert>` rejoue un seul GIF |
| `pr123-schema-api-verif.py` | La vérification ci-dessous (`python3 -I pr123-schema-api-verif.py <dossier> <sortie> --scale-png 2 --scale-gif 2`) |

## Schéma et mesures

- `schema.md` : deux schémas Mermaid (chemin d'une activité, vie d'une activité de script), chaque nœud relié au code.
  Relevé sur `b302f1df6` le 5/11, puis de nouveau sur `b222553ef` le 6/11 (C4-TEXTE-api) : toutes les lignes citées ont
  été recomptées sur la pointe (`beginPluginActivity` est devenu `IslandPluginActivity.qml:40-63`), deux cases ajoutées
  (face du shell vide retirée par `dropIfEmpty`, tenue d'arrivée de 5 s d'une barre cachée) ; les deux schémas sont
  les mêmes que dans `description.en.md` et `description.fr.md`, vérifiés par `pr123-mermaid-check.mjs`.
  Remis à jour le 7/11 sur `c9b7850d9` (C4-TEXTE-api, 2e passe) : une citation avait glissé d'une ligne (un commentaire
  ajouté dans `IslandController.qml` avant le bloc cité : `IslandController.qml:795-802` est devenu 796-803), et deux
  notes s'ajoutent au second schéma (tenue d'arrivée d'une île libre réveillée à sa fin : `IslandFreeHostWindow.qml:207`
  et `:307` ; feuille d'alerte ouverte sans le clavier : `IslandController.qml:575-576` et `:1093-1097`). Les deux
  schémas sont de nouveau identiques à ceux de `description.en.md` et `description.fr.md`, et `pr123-mermaid-check.mjs`
  les accepte (flowchart de 65 lignes, séquence de 71).
- `mesures.md` : remis à jour le 7/11 depuis la fiche perf finale 2 (90/100, `c9b7850d9`) : processeur, mémoire à 5
  minutes, démarrage, poids, tests et porte ; temps de rendu par image et allocations mesurés sur la tête seule, au banc
  (63 images par seconde), jamais à 240 Hz. Les bulles (PR 3) ont leurs propres fiches : rien n'en est repris.

## Vérification (P7-SCHEMA-api, 5/11 ; refaite le 6/11 et le 7/11)

Refaite le 7/11 sur ce dossier (inchangé : `pr123-schema-api-verif.py` et `c123-media-api-prive.sh`) : mêmes tailles
(dossier entier 0,7 Mo, plus gros GIF 170 Ko), aucun chemin, nom d'utilisateur ni nom de machine, coins de chaque PNG et
de chaque image de GIF aux deux fonds unis du banc, mêmes chiffres de symétrie que ceux
détaillés plus bas (le script signale onze échecs, tous de ce genre : feuilles, anneau de focus, pastille horloge,
ombre en clair ; aucun n'est une faute de prise de vue). Les captures neuves de `c9b7850d9`, identiques à 2/255 près, n'apportent aucune autre mesure.
Le 6/11, sur ce dossier et sur les captures et
GIF neufs de `b222553ef` (`pr123-schema-api-verif.py` et
`c123-media-api-prive.sh`) : mêmes tailles (le plus gros GIF : 170 Ko, dossier entier environ 0,7 Mo, la limite est de 8 Mo),
mêmes boucles propres, aucun chemin, nom d'utilisateur ni nom de machine dans les textes, les octets et les métadonnées,
et les quatre coins de chaque PNG et de chaque image de GIF sont les deux fonds unis du banc (aucun fond d'écran). Les
mesures de symétrie ci-dessous sont les mêmes sur les captures neuves.

- Tailles : tout sous 8 Mo (le plus gros GIF : 170 Ko). GIF : boucle propre (première image = dernière) et animés
  tous les quatre ; images à 10, 50 et 90 % regardées, lisibles.
- Données : aucun chemin, nom d'utilisateur ni nom de machine dans les textes ni dans les métadonnées des images ; fonds
  unis, date et heure du banc seulement.
- Symétrie (`symetrie.py`, anneau de 6 px à 1x, tolérance 1 px à 1x ; PNG et GIF live agrandis deux fois, GIF alerte
  à 1x), mesurée sur les captures sombres : en clair, l'outil compte l'ombre portée dans la forme, la mesure n'y dit
  rien (même géométrie qu'en sombre).
  - Bulle compacte live et les quatre accents : gauche/droite à 1 px près (43/44 à 1x), haut/bas égaux. OK.
  - Feuille d'alerte : gauche/droite 12/12 à 1x, haut/bas 15/12. L'icône sans progression garde la case de l'anneau
    (`ReadyActivityRing.qml:21-27`, `ringInset`), son glyphe commence 3 px plus bas que la marge du bas des boutons. Écart de code,
    pas de capture : à corriger ou à dire dans « Known limits ». Toujours là à `b222553ef` (30/24 à 2x sur la capture neuve).
  - Feuille live : gauche/droite 9/12 et haut/bas 12/9 à 1x, dus à l'anneau de focus clavier du premier bouton (voulu
    sur cette capture), qui déborde de 3 px ; sous l'anneau, le bouton tombe aux mêmes marges que ceux de la feuille
    d'alerte (lu sur l'image, l'outil ne sait pas retirer l'anneau).
  - Rangées de boutons : parts inégales, voulues par le code (`weight: implicitWidth`, chaque part suit son libellé),
    ce que la norme C11 permet (« selon `weight` »).
  - Pastille horloge (avant, et première et dernière images des GIF) : 13/15 à 1x ; face de la base, hors de cette PR.
- Rien refait : aucun écart ne vient de la prise de vue.
