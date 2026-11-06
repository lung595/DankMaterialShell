# Médias de la PR 3 « island: arrival, wing, cards, tiles, notifications and plugin activities »

Captures et GIF des bulles, faits au banc seulement (instance `pr123-media-bulles` le 5/11, `c123-media-bulles` le 6/11). Pointes actuelles : base `island/2-api` (b222553ef), tête `island/3-bubbles` (0463985bd).

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

## Reste à savoir

- Les GIF sont joués à la vitesse réelle du banc ; une machine plus lente ou plus rapide peut en changer légèrement le rythme.
- Les images de la tuile montrent le lanceur ouvert avec les applications de DMS seulement (les applications de la machine sont masquées).
- Rien n'a été installé chez le propriétaire : tout vient du banc, arrêté à la fin.
