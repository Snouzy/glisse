// Glisse : le dongle. Une souris Bluetooth pour l'iPhone, pilotée par le Mac à travers le port série USB.
//
// Le Mac envoie des lignes de texte :
//   M dx dy      déplacement relatif, en unités de souris (entiers, de n'importe quelle taille)
//   S dz dh      molette verticale et horizontale (entiers)
//   B masque     état des boutons : 1 gauche, 2 droit, 4 milieu, 8 arrière, 16 avant
//   R            relâcher tous les boutons (quand le Mac reprend la main)
//   ?            état : répond "glisse <version> paired <0|1> connected <0|1>"
//   !            oublier l'appairage (puis relancer l'appairage dans les réglages iOS)
//
// HijelHID envoie un rapport HID toutes les 8 ms (125 Hz) et limite chaque rapport à ±127 par axe. Les
// deltas reçus entre deux rapports sont additionnés ; ce qui dépasse attend le rapport suivant.

#include <Arduino.h>
#include <HijelHID_BLEMouse.h>

static const char *VERSION = "0.1";
static const uint32_t BAUD = 115200;
static const uint32_t REPORT_MS = 8;

// 5 boutons (la MX Anywhere 3S a arrière et avant), molette horizontale (le trackpad du Mac en a une).
HijelBLEMouse mouse("Glisse", "Glisse", 100, 5, true);

static int32_t accX = 0, accY = 0;
static int32_t accZ = 0, accH = 0;
static uint8_t buttons = 0;
static bool paired = false;
static char line[48];
static size_t lineLen = 0;

static int8_t clamp127(int32_t v) {
  if (v > 127) return 127;
  if (v < -127) return -127;
  return (int8_t)v;
}

static void handle(const char *cmd) {
  int a = 0, b = 0;
  switch (cmd[0]) {
    case 'M':
      if (sscanf(cmd + 1, "%d %d", &a, &b) == 2) { accX += a; accY += b; }
      break;
    case 'S':
      if (sscanf(cmd + 1, "%d %d", &a, &b) >= 1) { accZ += a; accH += b; }
      break;
    case 'B':
      if (sscanf(cmd + 1, "%d", &a) == 1) {
        buttons = (uint8_t)a;
        mouse.setButtons(buttons);
      }
      break;
    case 'R':
      buttons = 0;
      mouse.setButtons(0);
      accX = accY = accZ = accH = 0;
      break;
    case '?':
      Serial.printf("glisse %s paired %d connected %d\n", VERSION, mouse.isPaired() ? 1 : 0, mouse.isConnected() ? 1 : 0);
      break;
    case '!':
      mouse.clearBonds();
      Serial.println("bonds cleared");
      break;
    default:
      break;
  }
}

static void readSerial() {
  while (Serial.available()) {
    char c = (char)Serial.read();
    if (c == '\n' || c == '\r') {
      if (lineLen > 0) { line[lineLen] = 0; handle(line); lineLen = 0; }
    } else if (lineLen < sizeof(line) - 1) {
      line[lineLen++] = c;
    } else {
      lineLen = 0;  // ligne trop longue : on repart
    }
  }
}

static void flushReport() {
  if (!mouse.isPaired()) { accX = accY = accZ = accH = 0; return; }
  int8_t dx = clamp127(accX), dy = clamp127(accY);
  if (dx || dy) {
    mouse.move(dx, dy);
    accX -= dx;
    accY -= dy;
  }
  if (accZ) { mouse.addScroll(clamp127(accZ)); accZ -= clamp127(accZ); }
  if (accH) { mouse.addScrollH(clamp127(accH)); accH -= clamp127(accH); }
}

void setup() {
  Serial.begin(BAUD);
  mouse.setLogLevel(HIDLogLevel::Off);
  mouse.setUpdateRate(HIDRate::Hz125);
  mouse.begin();
}

void loop() {
  readSerial();

  static uint32_t lastReport = 0;
  uint32_t now = millis();
  if (now - lastReport >= REPORT_MS) {
    lastReport = now;
    flushReport();
  }

  bool p = mouse.isPaired();
  if (p != paired) {
    paired = p;
    Serial.printf("paired %d\n", p ? 1 : 0);
  }
}
