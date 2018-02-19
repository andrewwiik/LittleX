SHARED_CFLAGS = -fobjc-arc
CFLAGS = -fobjc-arc
ADDITIONAL_OBJCFLAGS = -fobjc-arc
include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = LittleX
LittleX_FILES = $(wildcard *.m)
LittleX_INSTALL_PATH = /Library/PreferenceBundles
LittleX_FRAMEWORKS = UIKit
LittleX_LDFLAGS += ./Preferences.tbd ./SpringBoardServices.tbd
LittleX_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk

after-all::
	@echo signing bundle
	@ldid -S $(THEOS_OBJ_DIR)/$(BUNDLE_NAME).bundle/$(BUNDLE_NAME)
	@echo Copying Bundle and Entry plist
	@mkdir -p $(THEOS_PROJECT_DIR)/Distribution/PreferenceBundles
	@mkdir -p $(THEOS_PROJECT_DIR)/Distribution/PreferenceLoader/Preferences
	@cp -r $(THEOS_OBJ_DIR)/$(BUNDLE_NAME).bundle $(THEOS_PROJECT_DIR)/Distribution/PreferenceBundles
	@cp ./entry.plist $(THEOS_PROJECT_DIR)/Distribution/PreferenceLoader/Preferences/$(BUNDLE_NAME).plist

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/LittleX.plist$(ECHO_END)
