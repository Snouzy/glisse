# Glisse : la souris du Mac glisse sur l'iPhone

Un dongle ESP32 branché en USB au Mac se présente à l'iPhone comme une souris Bluetooth. Quand le curseur
sort par le bord de l'écran du Mac, l'app Mac capture la souris et envoie ses mouvements au dongle ; quand
le curseur estimé ressort par le bord côté Mac, le Mac reprend la main.

## v1 (1er novembre 2026)

- [x] Vérifier ce qui existe : HijelHID_BLEMouse (NimBLE, iOS via AssistiveTouch), esp32-kvm (hôte Windows,
      pas de logique de bord). Personne ne fait le passage au bord : c'est la partie à écrire.
- [x] Firmware `firmware/glisse` : souris BLE 5 boutons + molette, lit des lignes sur le port série USB
      (`M dx dy`, `B masque`, `S dz dh`, `?`), accumule et envoie un rapport par période.
- [x] `GlisseCore` (Swift, testé) : protocole série, détection du bord avec résistance, curseur virtuel sur
      le rectangle de l'iPhone avec retour par le bord côté Mac.
- [x] `GlisseApp` (barre des menus) : CGEventTap, capture quand le curseur passe le bord, curseur figé et
      masqué, envoi série, raccourci ⌃⌥⌘P pour basculer à la main, état dans l'icône, réglages
      (bord, taille de l'iPhone, vitesse).
- [x] Compiler le firmware pour la devkit (FQBN selon la carte), flasher, appairer dans
      Réglages › Accessibilité › Toucher › AssistiveTouch › Appareils.
- [x] Essai réel : passage au bord, retour, dérive de l'estimation, molette, boutons latéraux.
      Trouvé et corrigé : retour trop tôt (résistance au retour + recalage au bord), curseur du Mac qui
      bougeait quand même (re-parquage à chaque événement), clics sur le Mac (bouclier), Universal Control
      qui prenait le bord droit (documenté).
- [x] README avec le montage, les réglages iOS conseillés (vitesse du pointeur au minimum) et les limites.

## v2, si la v1 plaît

- Clavier dans le même appareil BLE (descripteur HID composite, pas fourni par HijelHID).
- Presse-papiers Mac → iPhone en tapant le texte.
- Deux bords (iPhone à gauche ou à droite), plusieurs iPhone.

## Décisions

- **Mouvement par accumulation** : HijelHID envoie un rapport toutes les 8 ms et limite chaque rapport à
  ±127. Le firmware additionne les deltas reçus entre deux rapports et garde le reste pour le suivant, au
  lieu d'envoyer un rapport par événement.
- **Protocole texte** sur le port série : lisible au moniteur série, 115 200 bauds suffisent (10 octets par
  mouvement à 125 Hz).
- **Retour au Mac estimé (R1) avec secours (R2)** : iOS ne dit pas où est son curseur. L'app intègre les
  deltas sur un rectangle virtuel de la taille de l'iPhone ; le raccourci ⌃⌥⌘P rend la main à coup sûr.
  Mettre la vitesse du pointeur iOS au minimum réduit la dérive.
- **Le clavier reste au Mac en v1** : on peut taper sur le Mac pendant que le curseur est sur l'iPhone.
