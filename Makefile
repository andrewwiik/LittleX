
ARCHS = arm64

export ADDITIONAL_CFLAGS = -I$(THEOS_PROJECT_DIR)/../headers

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = LittleX
LittleX_FILES = Tweak.xm
LittleX_LIBRARIES = MobileGestalt
LittleX_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk

after-all::
	@echo Signing Binary
	@ldid -S $(THEOS_OBJ_DIR)/$(TWEAK_NAME).dylib
	@echo Copying to Distribution Folder
	@mkdir -p $(THEOS_PROJECT_DIR)/Distribution/SBInject
	@cp ./$(TWEAK_NAME).plist $(THEOS_PROJECT_DIR)/Distribution/SBInject
	@cp $(THEOS_OBJ_DIR)/$(TWEAK_NAME).dylib $(THEOS_PROJECT_DIR)/Distribution/SBInject
	@find $(THEOS_PROJECT_DIR)/Distribution/ -name ".DS_Store" -depth -exec rm {} \;

after-install::
	install.exec "killall -9 SpringBoard"

SUBPROJECTS += settings
include $(THEOS_MAKE_PATH)/aggregate.mk
