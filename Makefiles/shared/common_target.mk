# This file factorize the shared target {mandir|sbindir|bindir|...}{install|uninstall}

ifndef TARGET_DIR
echo "No TARGET_DIR defined. Fail !"
exit 1
endif

TARGET_DIR_RIGHTS?=755
TARGET_FILE_RIGHTS?=755


BUILDED_FILES=$(patsubst %.in,%,$(SOURCE_FILES))
TARGET_FILES=$(addprefix $(TARGET_DIR)/,$(notdir $(BUILDED_FILES)))

ifdef SOURCE_FILES
install:
	install -m $(TARGET_DIR_RIGHTS) -d $(TARGET_DIR)
	install -m $(TARGET_FILE_RIGHTS) $(BUILDED_FILES) $(TARGET_DIR)

uninstall:
	-rm -f $(TARGET_FILES)
else
install:
uninstall:
endif

