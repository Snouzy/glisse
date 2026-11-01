# Glisse

La souris du Mac glisse sur l'iPhone. Pousse le curseur contre le bord de l'écran : il passe sur l'iPhone
posé à côté, avec les clics, la molette et les boutons latéraux. Ramène-le par le même bord, ou ⌃⌥⌘P.

Universal Control ne fait ça qu'avec un iPad, et une app iOS ne peut pas piloter le reste du téléphone.
Glisse contourne par le matériel : un ESP32 branché en USB au Mac se fait passer pour une souris Bluetooth
auprès de l'iPhone, et une app dans la barre des menus du Mac lui envoie la souris quand le curseur est
« sur l'iPhone ».

```
 Mac ── USB série ──▶ ESP32 (souris BLE) ── Bluetooth ──▶ iPhone (AssistiveTouch)
```

## Montage

1. **Flasher le dongle** (une carte ESP32 avec Bluetooth : classique, C3 ou S3, pas S2).

   ```bash
   brew install arduino-cli
   arduino-cli config add board_manager.additional_urls https://espressif.github.io/arduino-esp32/package_esp32_index.json
   arduino-cli core update-index && arduino-cli core install esp32:esp32
   arduino-cli lib install NimBLE-Arduino HijelHID_BLEMouse
   cd firmware && make upload            # BOARD=classic par défaut ; BOARD=s3 ou BOARD=c3 sinon
   ```

   Sur un Mac Apple Silicon sans Rosetta, l'outil `ctags` fourni par Arduino est en x86 : `brew install ctags`
   et remplacer `~/Library/Arduino15/packages/builtin/tools/ctags/5.8-arduino11/ctags` par un lien vers
   `/opt/homebrew/bin/ctags`.

2. **Appairer l'iPhone.** Réglages › Accessibilité › Toucher › AssistiveTouch : activer, puis
   Appareils › Appareils Bluetooth › « Glisse ». Dans le même écran, mettre la **vitesse du pointeur au
   minimum** : l'app estime où est le curseur iOS, et l'accélération d'iOS fausse l'estimation.

3. **Installer l'app Mac.**

   ```bash
   cd mac && ./scripts/install.sh       # ~/Applications/Glisse.app, lancée
   ```

   macOS demande l'accès Accessibilité (pour lire et retenir la souris). L'icône iPhone apparaît dans la
   barre des menus : barrée sans dongle, avec un point d'exclamation tant que l'iPhone n'est pas relié.

## Usage

- Pousse le curseur contre le bord (à droite par défaut, réglable dans le menu) : après quelques points de
  résistance il passe sur l'iPhone. Le curseur du Mac reste figé au bord pendant ce temps.
- Clic gauche, droit (menu AssistiveTouch), milieu, arrière, avant et la molette sont transmis.
- Retour : ramène le curseur par le bord côté Mac, ou ⌃⌥⌘P à tout moment. Si le dongle est débranché ou
  l'iPhone se déconnecte, le Mac reprend la main tout seul.
- Le clavier reste au Mac : on peut taper sur le Mac pendant que la souris est sur l'iPhone.

Menu : le bord, la vitesse sur l'iPhone, « Chemin avant de revenir » (la largeur de l'iPhone en unités de
souris : si le curseur revient au Mac trop tôt, prendre plus grand ; s'il faut traverser l'iPhone plusieurs
fois, plus petit), molette inversée, oublier l'appairage du dongle.

## Universal Control

Si un autre Mac ou un iPad est relié par Universal Control, il réclame lui aussi un bord de l'écran, et il
gagne : le système le gère avant que Glisse voie quoi que ce soit. Dans Réglages Système › Écrans, range
l'autre appareil du côté opposé à l'iPhone, et dans Avancé… décoche « Se reconnecter automatiquement à un
Mac ou iPad à proximité ».

## Limites connues

- iOS ne dit pas où est son curseur : le retour par le bord est une estimation, protégée par une résistance
  (menu « Résistance au retour »). Pousser contre le bord côté Mac recale le vrai pointeur sur l'estimation.
  ⌃⌥⌘P est le secours.
- Un seul bord, un seul iPhone, pas de clavier (v2 : descripteur HID composite souris + clavier).

## Comment ça tient

- La dissociation souris/curseur de macOS (`CGAssociateMouseAndMouseCursorPosition`) ne tient pas pour une
  app en arrière-plan : pendant que la souris est sur l'iPhone, Glisse re-parque le curseur au bord à chaque
  événement, comme Synergy, et lit les deltas de l'événement.
- Le curseur est caché avec la propriété privée « SetsCursorInBackground » de SkyLight (Synergy, Barrier).
- Une fenêtre invisible de Glisse se tient sous le curseur parqué et avale tout clic qui s'échapperait.

## Code

- `firmware/glisse/` : le dongle (Arduino, [HijelHID_BLEMouse](https://github.com/HijelHub/HijelHID_BLEMouse),
  NimBLE). Protocole texte sur le port série, décrit en tête de `dongle.cpp`.
- `mac/` : paquet SwiftPM. `GlisseCore` (logique pure, testée : protocole, passage du bord, curseur
  virtuel), `GlisseApp` (barre des menus, CGEventTap, port série). `swift test` dans `mac/`.
