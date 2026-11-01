# Firmware du dongle, avec arduino-cli.
#
#   make            compile pour la carte par défaut
#   make upload     compile et flashe (PORT détecté, ou PORT=/dev/cu.xxx)
#   make monitor    moniteur série
#   make BOARD=s3   ESP32-S3 (USB natif), BOARD=c3 pour un ESP32-C3, BOARD=classic pour un ESP32 WROOM
#
# Prérequis (une fois) :
#   arduino-cli config add board_manager.additional_urls https://espressif.github.io/arduino-esp32/package_esp32_index.json
#   arduino-cli core update-index && arduino-cli core install esp32:esp32
#   arduino-cli lib install NimBLE-Arduino

BOARD ?= classic
SKETCH := glisse
BUILD := build/$(BOARD)

ifeq ($(BOARD),classic)
  FQBN := esp32:esp32:esp32:PartitionScheme=huge_app
else ifeq ($(BOARD),s3)
  FQBN := esp32:esp32:esp32s3:CDCOnBoot=cdc,PartitionScheme=huge_app
else ifeq ($(BOARD),c3)
  FQBN := esp32:esp32:esp32c3:CDCOnBoot=cdc,PartitionScheme=huge_app
else
  $(error BOARD doit être classic, s3 ou c3)
endif

PORT ?= $(shell ls /dev/cu.usbserial* /dev/cu.SLAB_USBtoUART* /dev/cu.usbmodem* /dev/cu.wchusbserial* 2>/dev/null | head -1)

.PHONY: all compile upload monitor clean

all: compile

compile:
	arduino-cli compile --fqbn "$(FQBN)" --build-path "$(BUILD)" --warnings default $(SKETCH)

upload: compile
	@test -n "$(PORT)" || { echo "Aucun port série trouvé : branche la carte ou passe PORT=/dev/cu.xxx"; exit 1; }
	arduino-cli upload --fqbn "$(FQBN)" --input-dir "$(BUILD)" --port "$(PORT)" $(SKETCH)

monitor:
	@test -n "$(PORT)" || { echo "Aucun port série trouvé"; exit 1; }
	arduino-cli monitor --port "$(PORT)" --config baudrate=115200

clean:
	rm -rf build
