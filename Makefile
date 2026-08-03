TARGET := iphone:clang:latest:17.0
# Scheme defaults to roothide (Dopamine/rootHide); build legacy rootless with
#   make clean package THEOS_PACKAGE_SCHEME=rootless ARCHS="arm64 arm64e"
THEOS_PACKAGE_SCHEME ?= roothide
ARCHS ?= arm64e
INSTALL_TARGET_PROCESSES = SpringBoard

ifeq ($(shell uname -s),Darwin)
TARGET_CODESIGN = /usr/bin/codesign
TARGET_CODESIGN_FLAGS = -f -s -
endif

include $(THEOS)/makefiles/common.mk

# Shared support library: preferences + color math (mirrors libdottoplus.dylib).
LIBRARY_NAME = libdottoplus
libdottoplus_FILES = libdottoplus/DottoPlusPlusPreferences.m libdottoplus/RGBPixel.m libdottoplus/UIColor+dottoPlusPlus.m
libdottoplus_INSTALL_PATH = /usr/local/lib
libdottoplus_CFLAGS = -fobjc-arc -Wall -Wextra -Werror -Ilibdottoplus
libdottoplus_FRAMEWORKS = UIKit CoreGraphics Foundation

# Theos-built libraries live in the object dir; add it to the linker search path.
DOTTO_LIB_LDFLAGS = -L$(THEOS_OBJ_DIR)

# The library installs to /usr/local/lib, but the rootless scheme links it via
# @rpath with default rpaths that skip /usr/local/lib. Add the install path as
# an rpath on every consumer (prefix resolves to /var/jb on rootless).
DOTTO_RPATH = -Wl,-rpath,$(THEOS_PACKAGE_INSTALL_PREFIX)/usr/local/lib

# SpringBoard badge tweak.
TWEAK_NAME = dotto
dotto_FILES = Tweak.x
dotto_CFLAGS = -fobjc-arc -Wall -Wextra -Werror -Ilibdottoplus -DDISABLE_ROOTLESS_COMPAT_WARNING
dotto_FRAMEWORKS = UIKit Foundation CoreGraphics
dotto_LIBRARIES = dottoplus
# Categories on SpringBoard classes reference their class symbols; resolve at
# runtime like classic substrate tweaks.
dotto_LDFLAGS = $(DOTTO_LIB_LDFLAGS) -undefined dynamic_lookup $(DOTTO_RPATH)

# Settings bundle.
BUNDLE_NAME = dottoPrefs
dottoPrefs_FILES = dottoPrefs/DottoPlusPlusRootListController.m \
	dottoPrefs/DottoPlusPlusAppearanceSelectionTableCell.m \
	dottoPrefs/DottoPlusPlusColorSelectionTableCell.m \
	dottoPrefs/DottoPlusPlusColorRowStackView.m \
	dottoPrefs/DottoPlusPlusColorItemView.m \
	dottoPrefs/DottoPlusPlusLinksListController.m \
	dottoPrefs/DottoPlusPlusCreditCells.m
dottoPrefs_INSTALL_PATH = /Library/PreferenceBundles
# Bundle resources (Info.plist, Root.plist, images) live in dottoPrefs/Resources.
dottoPrefs_RESOURCE_DIRS = dottoPrefs/Resources
dottoPrefs_CFLAGS = -fobjc-arc -Wall -Wextra -Werror -Ilibdottoplus -DDISABLE_ROOTLESS_COMPAT_WARNING
dottoPrefs_FRAMEWORKS = UIKit Foundation
dottoPrefs_PRIVATE_FRAMEWORKS = Preferences
dottoPrefs_LIBRARIES = dottoplus
# Xcode SDKs do not ship the private Preferences framework; link against the
# vendored stub (same layout as the pinned theos SDK). jbroot() resolves at
# runtime from the always-loaded libroothide.
dottoPrefs_LDFLAGS = $(DOTTO_LIB_LDFLAGS) -F$(THEOS_PROJECT_DIR)/sdks -undefined dynamic_lookup $(DOTTO_RPATH)

include $(THEOS_MAKE_PATH)/library.mk
include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/bundle.mk
