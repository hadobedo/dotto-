TARGET := iphone:clang:latest:17.0
ARCHS := arm64e
INSTALL_TARGET_PROCESSES = SpringBoard
THEOS_PACKAGE_SCHEME = roothide

ifeq ($(shell uname -s),Darwin)
TARGET_CODESIGN = /usr/bin/codesign
TARGET_CODESIGN_FLAGS = -f -s -
endif

include $(THEOS)/makefiles/common.mk

# Shared support library: preferences + color math (mirrors libdottoplus.dylib).
LIBRARY_NAME = libdottoplus
libdottoplus_FILES = libdottoplus/DottoPreferences.m libdottoplus/RGBPixel.m libdottoplus/UIColor+dotto.m
libdottoplus_INSTALL_PATH = /usr/local/lib
libdottoplus_CFLAGS = -fobjc-arc -Wall -Wextra -Werror -Ilibdottoplus
libdottoplus_FRAMEWORKS = UIKit CoreGraphics Foundation

# SpringBoard badge tweak.
TWEAK_NAME = dotto
dotto_FILES = Tweak.x
dotto_CFLAGS = -fobjc-arc -Wall -Wextra -Werror -Ilibdottoplus
dotto_FRAMEWORKS = UIKit Foundation CoreGraphics
dotto_LIBRARIES = dottoplus

# Settings bundle.
BUNDLE_NAME = dottoPrefs
dottoPrefs_FILES = dottoPrefs/DottoRootListController.m \
	dottoPrefs/DottoAppearanceSelectionTableCell.m \
	dottoPrefs/DottoColorSelectionTableCell.m \
	dottoPrefs/DottoColorRowStackView.m \
	dottoPrefs/DottoColorItemView.m
dottoPrefs_INSTALL_PATH = /Library/PreferenceBundles
# Bundle resources (Info.plist, Root.plist, images) live in dottoPrefs/Resources.
dottoPrefs_RESOURCE_DIRS = dottoPrefs/Resources
dottoPrefs_CFLAGS = -fobjc-arc -Wall -Wextra -Werror -Ilibdottoplus
dottoPrefs_FRAMEWORKS = UIKit Foundation
dottoPrefs_PRIVATE_FRAMEWORKS = Preferences
dottoPrefs_LIBRARIES = dottoplus

include $(THEOS_MAKE_PATH)/library.mk
include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/bundle.mk
