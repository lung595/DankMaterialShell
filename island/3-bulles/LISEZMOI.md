# Médias de la PR 3 « island: arrival, wing, cards, tiles, notifications and plugin activities »

Captures et GIF des bulles, faits au banc seulement (instance `pr123-media-bulles` le 5/11, `c123-media-bulles` le 6/11). Pointes actuelles : base `island/2-api` (c9b7850d9), tête `island/3-bubbles` (b79b3934d).

## Mise à jour du 7/11 (passe finale, pointe b79b3934d)

La base n'a pas bougé (c9b7850d9). La tête est passée de a4f96802b à b79b3934d par un seul fixup de 2 lignes : `island.userHeld = false;` dans `begin()` de `IslandPluginActivity.qml` (1 fichier, +2 lignes ; le `range-diff` ne montre de différence que sur les deux premiers commits de la pile, les cinq autres sont identiques). C'est une remise à faux d'un drapeau qui ne sert qu'à poser ou non la couche de clic dehors : ni couleur, ni taille, ni forme, ni durée, ni image (`boucle-correction-123/controles/bulles/accessibilite-final-3.md`). Aucune scène n'a donc été rejouée : les 24 images fixes et les 12 GIF sont gardés tels quels, aux mêmes noms (dates inchangées, 5/11 et 6/11). Seul `mesures.md` est remis à jour (fiche `perf-final-3.md` : chiffres de perf repris de `perf-final-2.md`, poids recalculé à +376 534 octets, porte et tests de la pointe b79b3934d), et l'en-tête de `schema.md` (aucune ligne citée ne bouge : le fichier changé n'y est pas cité). Les vérifications ci-dessous (section du 7/11, passe finale) sont rejouées sur les 36 fichiers.

## Mise à jour du 7/11 (passe précédente, pointe a4f96802b)

Les pointes ont encore bougé (base b222553ef vers c9b7850d9, tête 0463985bd vers a4f96802b), par quelques lignes de logique seulement : 4 fichiers, 9 lignes côté bulles (`IslandArrivalState.qml` : `drainMs` devient une propriété ; `IslandBarHost.qml` : `holdsHost` tient aussi l'hôte pendant une bulle machine ; `IslandController.qml` : `outsideClickCollapses` ne vaut pas pour une bulle ramenée par l'utilisateur ; `IslandFreeHostWindow.qml` : l'île libre se réveille quand l'hôte est tenu) et 6 lignes côté base (4 ajoutées, 2 retirées, `IslandController.qml` et `IslandFreeHostWindow.qml`). Aucune couleur, taille, forme, durée ni image n'a changé : la comparaison de 21 vues des deux pointes (`boucle-correction-123/controles/bulles/accessibilite-final-2.md`) ne montre que la barre amont et l'état du banc. Aucune scène n'a donc été rejouée : les 24 images fixes et les 12 GIF du 6/11 sont gardés tels quels, aux mêmes noms. Seuls `mesures.md` (chiffres des dernières fiches perf, pointe a4f96802b) et `schema.md` (numéros de ligne décalés de 2 à 3 dans `IslandController.qml` et `IslandArrivalState.qml`) sont remis à jour.

## Mise à jour du 6/11 (corrections des PR 1, 2 et 3)

Les corrections ont déplacé les pointes (base b302f1df6 vers b222553ef, tête 130fc3ad1 vers 0463985bd). Toutes les scènes ont été rejouées au banc `c123-media-bulles` (mêmes réglages, fond uni neutre, noms fictifs), la tête puis la base, thèmes clair et sombre, et comparées aux médias du 5/11 :

- **Images fixes (24)** : identiques pixel à pixel (tolérance de 3 %, relevés de processeur et de mémoire de la barre masqués), sauf ce qui vit seul à l'instant de la prise : la barre de progression de la notification, le sable de l'alerte du plugin, l'anneau de focus du champ de recherche du lanceur sur la tuile sombre. Elles sont gardées telles quelles.
- **GIF de l'arrivée, de l'aile, de la carte, de la notification et du plugin (10)** : même mouvement, image par image, aux quelques images près d'un départ de commande (décalage de 0 à 3 images). Gardés tels quels.
- **GIF de la tuile (2)** : la bulle devient tuile en une chorégraphie plus courte (le mouvement de la bulle vers la tuile dure environ 0,45 s au lieu de 0,85 s, sans l'ondulation de la version précédente). Refaits sur la tête 0463985bd, thèmes sombre et clair ; ce sont les seuls fichiers changés.

## Comment ils ont été faits

- Banc isolé (son propre HOME, sa propre session) : fond uni neutre (un PNG d'une seule couleur, gris foncé ou gris clair), aucune donnée personnelle, applications de la machine masquées dans le lanceur (il ne reste que les applications de DMS), presse-papiers et fenêtre « Screenshot captured » éteints, appareils et noms fictifs (« Sample Mail », « Tea », « Pasta »).
- Vitesse d'animation normale (250 ms, réglage par défaut). Chaque scène est jouée une fois, sous une rafale de captures d'écran du compositeur du banc (environ 35 images par seconde, sans le curseur), chaque image datée de son instant.
- Image fixe : l'image la plus proche de l'instant marqué dans la scène. GIF : images prises à 25 par seconde sur la ligne du temps réelle, palette générée par ffmpeg (`palettegen`, `paletteuse`), boucle infinie ; chaque GIF commence et finit sur l'horloge de l'île (première et dernière image identiques, vérifié pixel à pixel).
- Avant = base `island/2-api` (la même scène jouée sur la base), après = tête. Le thème clair et le thème sombre sont joués séparément.

## Ce que « avant » montre

La base a déjà la face d'activité de l'API et une notification en face compacte dans l'île. Elle n'a ni l'aile, ni la carte ouverte, ni la tuile ; l'arrivée de la PR se voit dans le mouvement, donc dans les GIF. Les images « avant » montrent l'état de la base au même instant de la scène. L'activité de plugin n'a pas d'« avant » : l'API de plugin pour l'île et l'exemple IslandActivityExample arrivent avec cette PR.

## Fichiers

| Fichier | Ce qu'il montre | Taille |
|---|---|---|
| `arrivee-apres-clair.png` | Arrivée, après, thème clair : L'île passe de l'horloge à la face de l'activité avec l'arrivée de la PR, puis retourne à l'horloge. (1280x250) | 16 Ko |
| `arrivee-apres-sombre.png` | Arrivée, après, thème sombre : L'île passe de l'horloge à la face de l'activité avec l'arrivée de la PR, puis retourne à l'horloge. (1280x250) | 14 Ko |
| `arrivee-avant-clair.png` | Arrivée, avant (base `island/2-api`), thème clair : L'activité est affichée par la face de l'API (PR 2) ; à l'arrêt l'image est la même, la différence est dans le mouvement (voir le GIF). (1280x250) | 16 Ko |
| `arrivee-avant-sombre.png` | Arrivée, avant (base `island/2-api`), thème sombre : L'activité est affichée par la face de l'API (PR 2) ; à l'arrêt l'image est la même, la différence est dans le mouvement (voir le GIF). (1280x250) | 15 Ko |
| `arrivee-clair.gif` | Arrivée, GIF, thème clair : Une activité arrive dans l'île (activité « live » lancée par l'IPC : « Tea », avec sa pastille de progression). L'île passe de l'horloge à la face de l'activité avec l'arrivée de la PR, puis retourne à l'horloge. (1280x180) | 119 Ko |
| `arrivee-sombre.gif` | Arrivée, GIF, thème sombre : Une activité arrive dans l'île (activité « live » lancée par l'IPC : « Tea », avec sa pastille de progression). L'île passe de l'horloge à la face de l'activité avec l'arrivée de la PR, puis retourne à l'horloge. (1280x180) | 95 Ko |
| `aile-apres-clair.png` | Aile, après, thème clair : « Tea » est gardée en bulle dans l'aile à droite de l'île, l'alerte prend l'île ; quand l'alerte part, « Tea » revient puis s'éteint. (1280x250) | 17 Ko |
| `aile-apres-sombre.png` | Aile, après, thème sombre : « Tea » est gardée en bulle dans l'aile à droite de l'île, l'alerte prend l'île ; quand l'alerte part, « Tea » revient puis s'éteint. (1280x250) | 16 Ko |
| `aile-avant-clair.png` | Aile, avant (base `island/2-api`), thème clair : L'alerte remplace « Tea », qui disparaît : pas d'aile, rien ne la garde. (1280x250) | 15 Ko |
| `aile-avant-sombre.png` | Aile, avant (base `island/2-api`), thème sombre : L'alerte remplace « Tea », qui disparaît : pas d'aile, rien ne la garde. (1280x250) | 14 Ko |
| `aile-clair.gif` | Aile, GIF, thème clair : Une seconde activité (alerte « Pasta ») arrive pendant que « Tea » occupe l'île. « Tea » est gardée en bulle dans l'aile à droite de l'île, l'alerte prend l'île ; quand l'alerte part, « Tea » revient puis s'éteint. (1280x180) | 439 Ko |
| `aile-sombre.gif` | Aile, GIF, thème sombre : Une seconde activité (alerte « Pasta ») arrive pendant que « Tea » occupe l'île. « Tea » est gardée en bulle dans l'aile à droite de l'île, l'alerte prend l'île ; quand l'alerte part, « Tea » revient puis s'éteint. (1280x180) | 349 Ko |
| `carte-apres-clair.png` | Carte ouverte, après, thème clair : La carte s'ouvre sous l'île (application, heure, titre, texte, bouton Dismiss), puis se range (`arrival tidy`). (1280x250) | 26 Ko |
| `carte-apres-sombre.png` | Carte ouverte, après, thème sombre : La carte s'ouvre sous l'île (application, heure, titre, texte, bouton Dismiss), puis se range (`arrival tidy`). (1280x250) | 25 Ko |
| `carte-avant-clair.png` | Carte ouverte, avant (base `island/2-api`), thème clair : L'île ne montre que la face compacte de la notification : la commande `arrival open` n'existe pas encore. (1280x250) | 16 Ko |
| `carte-avant-sombre.png` | Carte ouverte, avant (base `island/2-api`), thème sombre : L'île ne montre que la face compacte de la notification : la commande `arrival open` n'existe pas encore. (1280x250) | 15 Ko |
| `carte-clair.gif` | Carte ouverte, GIF, thème clair : Une notification (« Sample Mail », « Lunch at noon? ») arrive et sa carte est ouverte (`island arrival open`). La carte s'ouvre sous l'île (application, heure, titre, texte, bouton Dismiss), puis se range (`arrival tidy`). (960x375) | 316 Ko |
| `carte-sombre.gif` | Carte ouverte, GIF, thème sombre : Une notification (« Sample Mail », « Lunch at noon? ») arrive et sa carte est ouverte (`island arrival open`). La carte s'ouvre sous l'île (application, heure, titre, texte, bouton Dismiss), puis se range (`arrival tidy`). (960x375) | 282 Ko |
| `tuile-apres-clair.png` | Tuile, après, thème clair : L'île descend sous le lanceur et la bulle devient une tuile verticale à côté de lui ; à la fermeture du lanceur la tuile se range. (1280x340) | 48 Ko |
| `tuile-apres-sombre.png` | Tuile, après, thème sombre : L'île descend sous le lanceur et la bulle devient une tuile verticale à côté de lui ; à la fermeture du lanceur la tuile se range. (1280x340) | 49 Ko |
| `tuile-avant-clair.png` | Tuile, avant (base `island/2-api`), thème clair : Le lanceur s'ouvre seul, aucune bulle ni tuile à côté. (1280x340) | 47 Ko |
| `tuile-avant-sombre.png` | Tuile, avant (base `island/2-api`), thème sombre : Le lanceur s'ouvre seul, aucune bulle ni tuile à côté. (1280x340) | 47 Ko |
| `tuile-clair.gif` | Tuile, GIF, thème clair : Le lanceur s'ouvre pendant que des bulles sont en aile (« Tea » et « Pasta »). L'île descend sous le lanceur et la bulle devient une tuile verticale à côté de lui ; à la fermeture du lanceur la tuile se range. (760x340) | 248 Ko |
| `tuile-sombre.gif` | Tuile, GIF, thème sombre : Le lanceur s'ouvre pendant que des bulles sont en aile (« Tea » et « Pasta »). L'île descend sous le lanceur et la bulle devient une tuile verticale à côté de lui ; à la fermeture du lanceur la tuile se range. (760x340) | 231 Ko |
| `notif-apres-clair.png` | Notification, après, thème clair : Elle arrive comme une carte courte dans l'île (titre et texte), puis se réduit en face compacte, puis l'île reprend l'horloge. (1280x250) | 20 Ko |
| `notif-apres-sombre.png` | Notification, après, thème sombre : Elle arrive comme une carte courte dans l'île (titre et texte), puis se réduit en face compacte, puis l'île reprend l'horloge. (1280x250) | 19 Ko |
| `notif-avant-clair.png` | Notification, avant (base `island/2-api`), thème clair : L'île ne montre que la face compacte (application et titre), sans l'arrivée en carte. (1280x250) | 16 Ko |
| `notif-avant-sombre.png` | Notification, avant (base `island/2-api`), thème sombre : L'île ne montre que la face compacte (application et titre), sans l'arrivée en carte. (1280x250) | 15 Ko |
| `notif-clair.gif` | Notification, GIF, thème clair : Une notification (« Sample Mail », « Lunch at noon? ») sans action. Elle arrive comme une carte courte dans l'île (titre et texte), puis se réduit en face compacte, puis l'île reprend l'horloge. (1280x220) | 394 Ko |
| `notif-sombre.gif` | Notification, GIF, thème sombre : Une notification (« Sample Mail », « Lunch at noon? ») sans action. Elle arrive comme une carte courte dans l'île (titre et texte), puis se réduit en face compacte, puis l'île reprend l'horloge. (1280x220) | 353 Ko |
| `plugin-2-apres-clair.png` | Activité de plugin (`request alert`), après, thème clair : la même alerte. (1280x370) | 17 Ko |
| `plugin-2-apres-sombre.png` | Activité de plugin (`request alert`), après, thème sombre : l'alerte « Pasta » du plugin ouverte, avec le sable qui coule sous elle. (1280x370) | 16 Ko |
| `plugin-apres-clair.png` | Activité de plugin (`request live`), après, thème clair : la même face. (1280x370) | 13 Ko |
| `plugin-apres-sombre.png` | Activité de plugin (IslandActivityExample, `request live`), après, thème sombre : la face « Tea » dessinée par le plugin dans l'île. (1280x370) | 12 Ko |
| `plugin-clair.gif` | Activité de plugin, GIF, thème clair : la même scène. (640x370) | 111 Ko |
| `plugin-sombre.gif` | Activité de plugin, GIF, thème sombre : `request live` (« Tea »), puis `request alert` (« Pasta » avec son sable), puis `release`, retour à l'horloge. (640x370) | 90 Ko |

Total : 36 fichiers, 3.5 Mo. Chaque GIF fait moins de 8 Mo (le plus gros : 439 Ko), de 3,5 à 8 secondes, 25 images par seconde.

## Vérifications du 6/11

- Aucun fond d'écran, chemin ni nom personnel : fond uni (un PNG d'une seule couleur écrit dans le HOME du banc), applications de DMS seules dans le lanceur, noms fictifs. Recherche, dans les octets des fichiers de ce dossier, d'un chemin de dossier personnel, du nom du propriétaire et d'un dossier de session : aucune.
- Symétrie (`symetrie.py`, tolérance de 1 px) : la pilule de l'aile (encre à 2 px de chaque bord), l'icône de notification (8 et 9 px à gauche et à droite, 6 et 7 px en haut et en bas) et la tuile (icône à 10 px de chaque côté), en clair et en sombre : centrées. Le haut et le bas de la tuile ne sont pas jugés : l'icône est en tête et le point en pied, par construction.
- GIF : 12 fichiers, tous sous 8 Mo, 25 images par seconde, boucle infinie ; première et dernière image identiques (à un pixel près pour la tuile sombre) ; chaque film refait tient dans la même minute, pour que l'horloge de l'île ne change pas entre la première et la dernière image.

## Vérifications du 7/11

Les 36 fichiers sont ceux du 6/11, intacts (dates inchangées) ; les vérifications sont rejouées sur eux, sans nouvelle capture :

- Recherche, dans les octets des 36 fichiers, d'un chemin de dossier personnel, d'un nom de fond d'écran ou d'un dossier de configuration : rien.
- Symétrie (`symetrie.py`, tolérance de 1 px) : mêmes marges qu'au 6/11, pilule de l'aile, icône de notification et tuile (gauche et droite à 10 px), en clair et en sombre. L'écart haut et bas de la tuile (10 et 66 px) est voulu : le point de la tuile est à son pied, son icône à sa tête.
- GIF : 12 fichiers, 25 images par seconde, de 3,96 à 8,24 secondes, le plus gros à 449 777 octets (moins de 8 Mo), première et dernière image identiques (à un pixel près pour la tuile sombre).

## Vérifications du 7/11, passe finale (pointe b79b3934d)

Les 36 fichiers sont toujours ceux du 5/11 (34) et du 6/11 (2 GIF de la tuile), intacts ; rejoué sans nouvelle capture avec `c123b-media-bulles-verif.sh` :

- Aucun fond d'écran, chemin ni nom personnel : recherche, dans les octets des 36 fichiers, d'un chemin de dossier personnel, du nom du propriétaire, du nom de la machine, d'un nom de fond d'écran, d'un dossier de configuration ou de session : rien ; métadonnées des PNG et des GIF sans commentaire ni chemin ; coins de toutes les images et de toutes les images des GIF aux deux seules couleurs unies du banc (gris foncé et gris clair, à 1 près).
- Symétrie (`symetrie.py`, tolérance de 1 px) : pilule de l'aile (encre à 2 px de chaque bord), icône de notification (8 et 9 px à gauche et à droite, 6 et 7 px en haut et en bas) et tuile (10 px à gauche et à droite), en clair et en sombre : centrées. Le haut et le bas de la tuile (10 et 66 px) ne sont pas jugés : l'icône est en tête et le point en pied, par construction.
- GIF : 12 fichiers, tous moins de 8 Mo (le plus gros : 449 777 octets, `aile-clair.gif`), 25 images par seconde, de 3,96 à 8,24 secondes, boucle infinie (extension de boucle présente dans les 12), première et dernière image identiques (0 pixel de différence, sauf `tuile-sombre.gif` : 1 pixel).

## Reste à savoir

- Les GIF sont joués à la vitesse réelle du banc ; une machine plus lente ou plus rapide peut en changer légèrement le rythme.
- Les images de la tuile montrent le lanceur ouvert avec les applications de DMS seulement (les applications de la machine sont masquées).
- Rien n'a été installé chez le propriétaire : tout vient du banc, arrêté à la fin.
