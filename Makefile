# Sega Master System Rachel Client Makefile

ASM198X ?= asm198x
PASMO ?= pasmo
PYTHON ?= python3

SRC_DIR = src
BUILD_DIR = build

TARGET = $(BUILD_DIR)/rachel.sms

SRCS = $(wildcard $(SRC_DIR)/*.asm $(SRC_DIR)/net/*.asm)

.PHONY: all clean check reference-parity

all: $(BUILD_DIR) $(TARGET)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(TARGET): $(SRCS) | $(BUILD_DIR)
	$(ASM198X) --dialect pasmo -I $(SRC_DIR) $(SRC_DIR)/main.asm -o $@
	$(PYTHON) tools/finalize_rom.py $@

reference-parity: $(TARGET)
	cd $(SRC_DIR) && $(PASMO) --bin main.asm ../$(BUILD_DIR)/reference.sms
	$(PYTHON) tools/finalize_rom.py $(BUILD_DIR)/reference.sms
	cmp $(TARGET) $(BUILD_DIR)/reference.sms

check: reference-parity
	$(PYTHON) tests/verify_rom.py $(TARGET)

clean:
	rm -rf $(BUILD_DIR)

# For emulator testing
run: $(TARGET)
	@echo "Load $(TARGET) in an SMS emulator (Meka, Kega Fusion, etc.)"
