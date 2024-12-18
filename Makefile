ifndef RACK_DIR
$(error RACK_DIR is not defined)
endif

include $(RACK_DIR)/arch.mk

ifdef ARCH_X64
	PRESET_ARCH := x64
endif

ifdef ARCH_ARM64
	PRESET_ARCH := arm64
endif

ifdef ARCH_WIN
	PRESET_OS := windows
endif

ifdef ARCH_LIN
	PRESET_OS := linux
endif

ifdef ARCH_MAC
	PRESET_OS := osx
endif

ifdef BUILD_TYPE
	PRESET_CONFIG := $(BUILD_TYPE)
else
	ifdef DEBUG
		PRESET_CONFIG := debug
	else
		PRESET_CONFIG := release
	endif
endif

ifdef VERBOSE
	PRESET_VERBOSE := -verbose
endif

PRESET ?= $(PRESET_ARCH)-$(PRESET_OS)-$(PRESET_CONFIG)$(PRESET_VERBOSE)

# The below are Makefile commands which intelligently call a CMake Preset,
# by detecting your system variables...

reconfigure:
	cmake \
	--preset $(PRESET) \
  --fresh

configure:
	cmake \
	--preset $(PRESET)

build: configure
	cmake \
  --build $(PWD)/build \
	--preset $(PRESET)

test: build
	ctest \
  --test-dir $(PWD)/build \
	--preset $(PRESET)

package: test
	cmake \
  --install $(PWD)/build \
	--prefix $(PWD)/install

workflow:
	cmake \
  --workflow \
	--preset $(PRESET) \
	--fresh
