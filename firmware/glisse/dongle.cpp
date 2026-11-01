// Glisse : le dongle. Une souris et un clavier Bluetooth pour l'iPhone, pilotés par le Mac à travers le port
// série USB. Écrit directement sur NimBLE pour tenir la cadence : un rapport souris par intervalle de
// connexion réellement négocié (iOS accepte 11,25 à 15 ms), au lieu d'empiler des notifications.
//
// Le Mac envoie des lignes de texte :
//   M dx dy                 déplacement relatif, en unités de souris (entiers, de n'importe quelle taille)
//   S dz dh                 molette verticale et horizontale (entiers)
//   B masque                état des boutons : 1 gauche, 2 droit, 4 milieu, 8 arrière, 16 avant
//   K mods k1 k2 k3 k4 k5 k6   état du clavier : octet de modificateurs HID puis jusqu'à six codes d'usage
//   R                       tout relâcher, souris et clavier (quand le Mac reprend la main)
//   ?                       état : répond "glisse <version> paired <0|1> connected <0|1> interval <ms>"
//   !                       oublier les appairages (puis oublier « Glisse » dans les réglages iOS et réappairer)

#include <Arduino.h>
#include <NimBLEDevice.h>
#include <NimBLEHIDDevice.h>

static const char *VERSION = "0.2";
static const uint32_t BAUD = 115200;
static const uint8_t REPORT_MOUSE = 1;
static const uint8_t REPORT_KEYBOARD = 2;
// Intervalle de connexion demandé, en unités de 1,25 ms : 9 = 11,25 ms, 12 = 15 ms. iOS prend l'un des deux.
static const uint16_t CONN_MIN = 9, CONN_MAX = 12, CONN_TIMEOUT = 400;

// Souris 5 boutons, X, Y, molette, défilement horizontal ; clavier standard 6 touches.
static const uint8_t REPORT_MAP[] = {
  0x05, 0x01,        // Usage Page (Generic Desktop)
  0x09, 0x02,        // Usage (Mouse)
  0xA1, 0x01,        // Collection (Application)
  0x85, REPORT_MOUSE,
  0x09, 0x01,        //   Usage (Pointer)
  0xA1, 0x00,        //   Collection (Physical)
  0x05, 0x09,        //     Usage Page (Button)
  0x19, 0x01, 0x29, 0x05,  // Usage Min 1, Max 5
  0x15, 0x00, 0x25, 0x01,  // Logical 0..1
  0x95, 0x05, 0x75, 0x01,  // 5 bits
  0x81, 0x02,        //     Input (Data, Var, Abs)
  0x95, 0x01, 0x75, 0x03,  // 3 bits de bourrage
  0x81, 0x03,        //     Input (Const)
  0x05, 0x01,        //     Usage Page (Generic Desktop)
  0x09, 0x30, 0x09, 0x31,  // X, Y
  0x15, 0x81, 0x25, 0x7F,  // -127..127
  0x75, 0x08, 0x95, 0x02,
  0x81, 0x06,        //     Input (Data, Var, Rel)
  0x09, 0x38,        //     Wheel
  0x15, 0x81, 0x25, 0x7F,
  0x75, 0x08, 0x95, 0x01,
  0x81, 0x06,
  0x05, 0x0C,        //     Usage Page (Consumer)
  0x0A, 0x38, 0x02,  //     AC Pan
  0x15, 0x81, 0x25, 0x7F,
  0x75, 0x08, 0x95, 0x01,
  0x81, 0x06,
  0xC0,              //   End Collection
  0xC0,              // End Collection

  0x05, 0x01,        // Usage Page (Generic Desktop)
  0x09, 0x06,        // Usage (Keyboard)
  0xA1, 0x01,        // Collection (Application)
  0x85, REPORT_KEYBOARD,
  0x05, 0x07,        //   Usage Page (Keyboard)
  0x19, 0xE0, 0x29, 0xE7,  // modificateurs
  0x15, 0x00, 0x25, 0x01,
  0x75, 0x01, 0x95, 0x08,
  0x81, 0x02,        //   Input (Data, Var, Abs)
  0x95, 0x01, 0x75, 0x08,
  0x81, 0x03,        //   réservé
  0x95, 0x05, 0x75, 0x01,
  0x05, 0x08,        //   Usage Page (LEDs)
  0x19, 0x01, 0x29, 0x05,
  0x91, 0x02,        //   Output (LEDs)
  0x95, 0x01, 0x75, 0x03,
  0x91, 0x03,        //   bourrage
  0x95, 0x06, 0x75, 0x08,
  0x15, 0x00, 0x26, 0xFF, 0x00,
  0x05, 0x07,
  0x19, 0x00, 0x2A, 0xFF, 0x00,
  0x81, 0x00,        //   Input (Data, Array)
  0xC0,              // End Collection
};

static NimBLEServer *server;
static NimBLEHIDDevice *hid;
static NimBLECharacteristic *mouseReport;
static NimBLECharacteristic *keyboardReport;

static volatile bool connected = false, paired = false;
static uint16_t connHandle = 0;
static uint32_t intervalMs = 15;

static int32_t accX = 0, accY = 0, accZ = 0, accH = 0;
static uint8_t buttons = 0, lastButtons = 0;
static uint8_t keys[8] = {0};  // mods, réservé, 6 touches
static bool keysDirty = false;
static char line[64];
static size_t lineLen = 0;

static int8_t clamp127(int32_t v) { return v > 127 ? 127 : v < -127 ? -127 : (int8_t)v; }

class Callbacks : public NimBLEServerCallbacks {
  void onConnect(NimBLEServer *s, NimBLEConnInfo &info) override {
    connected = true;
    connHandle = info.getConnHandle();
    s->updateConnParams(connHandle, CONN_MIN, CONN_MAX, 0, CONN_TIMEOUT);
    Serial.println("connected 1");
  }
  void onDisconnect(NimBLEServer *s, NimBLEConnInfo &info, int reason) override {
    connected = false;
    paired = false;
    Serial.println("paired 0");
    NimBLEDevice::startAdvertising();
  }
  void onAuthenticationComplete(NimBLEConnInfo &info) override {
    paired = info.isEncrypted();
    Serial.printf("paired %d\n", paired ? 1 : 0);
  }
};

static void sendKeyboard() {
  if (!paired) return;
  keyboardReport->setValue(keys, sizeof(keys));
  keyboardReport->notify();
}

static void releaseAll() {
  buttons = 0;
  accX = accY = accZ = accH = 0;
  memset(keys, 0, sizeof(keys));
  keysDirty = true;
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
      if (sscanf(cmd + 1, "%d", &a) == 1) buttons = (uint8_t)a;
      break;
    case 'K': {
      int v[7] = {0};
      if (sscanf(cmd + 1, "%d %d %d %d %d %d %d", &v[0], &v[1], &v[2], &v[3], &v[4], &v[5], &v[6]) == 7) {
        keys[0] = (uint8_t)v[0];
        keys[1] = 0;
        for (int i = 0; i < 6; i++) keys[2 + i] = (uint8_t)v[1 + i];
        keysDirty = true;
      }
      break;
    }
    case 'R':
      releaseAll();
      break;
    case '?':
      Serial.printf("glisse %s paired %d connected %d interval %lu\n", VERSION, paired ? 1 : 0, connected ? 1 : 0, (unsigned long)intervalMs);
      break;
    case '!':
      NimBLEDevice::deleteAllBonds();
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
      lineLen = 0;
    }
  }
}

// Un rapport souris par intervalle de connexion, seulement s'il y a quelque chose à dire.
static void flushMouse() {
  if (!paired) { accX = accY = accZ = accH = 0; lastButtons = buttons; return; }
  int8_t dx = clamp127(accX), dy = clamp127(accY), dz = clamp127(accZ), dh = clamp127(accH);
  if (!dx && !dy && !dz && !dh && buttons == lastButtons) return;
  uint8_t report[5] = {buttons, (uint8_t)dx, (uint8_t)dy, (uint8_t)dz, (uint8_t)dh};
  mouseReport->setValue(report, sizeof(report));
  mouseReport->notify();
  accX -= dx; accY -= dy; accZ -= dz; accH -= dh;
  lastButtons = buttons;
}

// L'intervalle réellement négocié avec l'iPhone, relu de temps en temps.
static void refreshInterval() {
  if (!connected) return;
  NimBLEConnInfo info = server->getPeerInfoByHandle(connHandle);
  uint32_t ms = (uint32_t)(info.getConnInterval() * 5 / 4);
  if (ms >= 7 && ms <= 200) intervalMs = ms;
}

void setup() {
  Serial.begin(BAUD);
  NimBLEDevice::init("Glisse");
  NimBLEDevice::setPower(9);
  NimBLEDevice::setSecurityAuth(true, false, true);  // lien chiffré et mémorisé, sans code
  NimBLEDevice::setSecurityIOCap(BLE_HS_IO_NO_INPUT_OUTPUT);

  server = NimBLEDevice::createServer();
  server->setCallbacks(new Callbacks());
  hid = new NimBLEHIDDevice(server);
  hid->setManufacturer("Glisse");
  hid->setPnp(0x02, 0xE502, 0xA111, 0x0002);
  hid->setHidInfo(0x00, 0x01);
  hid->setReportMap((uint8_t *)REPORT_MAP, sizeof(REPORT_MAP));
  mouseReport = hid->getInputReport(REPORT_MOUSE);
  keyboardReport = hid->getInputReport(REPORT_KEYBOARD);
  hid->getOutputReport(REPORT_KEYBOARD);  // les LED du clavier, pour que le descripteur soit complet
  hid->setBatteryLevel(100);
  server->start();

  NimBLEAdvertising *adv = NimBLEDevice::getAdvertising();
  adv->setAppearance(0x03C2);  // souris
  adv->addServiceUUID(hid->getHidService()->getUUID());
  adv->setName("Glisse");
  adv->enableScanResponse(true);
  adv->start();
}

void loop() {
  readSerial();

  static uint32_t lastReport = 0, lastRefresh = 0;
  uint32_t now = millis();
  if (now - lastReport >= intervalMs) {
    lastReport = now;
    flushMouse();
  }
  if (keysDirty) {
    keysDirty = false;
    sendKeyboard();
  }
  if (now - lastRefresh >= 1000) {
    lastRefresh = now;
    refreshInterval();
  }
}
