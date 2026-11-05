# Médias de la PR 2 « island: activities API and scripts over IPC »

Tout est pris au banc (instance `pr123-media-api`, écran virtuel 1280x720, fond uni neutre, aucune donnée de la machine :
barre réduite au lanceur, aux espaces de travail et à deux boutons, aucun appareil). Cadrage : la bande de l'île, agrandie
deux fois pour les PNG.

- **Avant** : base `island/1-kit` (36a043958), la PR en moins.
- **Après** : tête `island/2-api` (b302f1df6).
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

## Reproduire

Scripts dans `page-niri/outils/ile/` (préfixe `pr123-media-api-`) :

| Script | Rôle |
|---|---|
| `pr123-media-api-banc.sh avant\|apres\|stop` | Lance (ou arrête) le banc sur `wt/pr123-kit` (avant) ou `wt/pr123-api` (après), île allumée |
| `pr123-media-api-reglages.py` | Réglages du banc : fond uni par thème, barre réduite, notifications de capture de niri ignorées |
| `pr123-media-api-stills.sh avant\|apres dark\|light` | Les PNG |
| `pr123-media-api-film.sh <nom> dark\|light live\|alert` | Un GIF (captures d'écran rapprochées, cadence reprise par ffmpeg, une palette) |
| `pr123-media-api-ipc.sh` | Les transcriptions `avant-ipc.txt` et `apres-ipc.txt` |
| `pr123-media-api-demo.sh` | Le script de démonstration (copie : `demo-ipc.sh`) |
| `pr123-schema-api-verif.py` | La vérification ci-dessous (`python3 -I pr123-schema-api-verif.py <dossier> <sortie> --scale-png 2 --scale-gif 2`) |

## Schéma et mesures

- `schema.md` : deux schémas Mermaid (chemin d'une activité, vie d'une activité de script), chaque nœud relié au code.
- `mesures.md` : processeur, mémoire, démarrage, poids, tests et porte ; temps par image et allocations non mesurés.

## Vérification (P7-SCHEMA-api, 5/11)

- Tailles : tout sous 8 Mo (le plus gros GIF : 170 Ko). GIF : boucle propre (première image = dernière) et animés
  tous les quatre ; images à 10, 50 et 90 % regardées, lisibles.
- Données : aucun chemin, nom d'utilisateur ni nom de machine dans les textes ni dans les métadonnées des images ; fonds
  unis, date et heure du banc seulement.
- Symétrie (`symetrie.py`, anneau de 6 px à 1x, tolérance 1 px à 1x ; PNG et GIF live agrandis deux fois, GIF alerte
  à 1x), mesurée sur les captures sombres : en clair, l'outil compte l'ombre portée dans la forme, la mesure n'y dit
  rien (même géométrie qu'en sombre).
  - Bulle compacte live et les quatre accents : gauche/droite à 1 px près (43/44 à 1x), haut/bas égaux. OK.
  - Feuille d'alerte : gauche/droite 12/12 à 1x, haut/bas 15/12. L'icône sans progression garde la case de l'anneau
    (`ReadyActivityRing.qml:19-25`), son glyphe commence 3 px plus bas que la marge du bas des boutons. Écart de code,
    pas de capture : à corriger ou à dire dans « Known limits ».
  - Feuille live : gauche/droite 9/12 et haut/bas 12/9 à 1x, dus à l'anneau de focus clavier du premier bouton (voulu
    sur cette capture), qui déborde de 3 px ; sous l'anneau, le bouton tombe aux mêmes marges que ceux de la feuille
    d'alerte (lu sur l'image, l'outil ne sait pas retirer l'anneau).
  - Rangées de boutons : parts inégales, voulues par le code (`weight: implicitWidth`, chaque part suit son libellé),
    ce que la norme C11 permet (« selon `weight` »).
  - Pastille horloge (avant, et première et dernière images des GIF) : 13/15 à 1x ; face de la base, hors de cette PR.
- Rien refait : aucun écart ne vient de la prise de vue.
