#include <roothide.h>

#define PREF_PATH jbroot(@"/var/mobile/Library/Preferences/com.mox1121.shortcutpanel.plist")
#define LEGACY_PREF_PATH jbroot(@"/var/mobile/Library/Preferences/com.ichitaso.bottomcontrolx.plist")
#define QUICK_IPC_PATH jbroot(@"/var/mobile/Library/Preferences/com.mox1121.shortcutpanel.quick.plist")
#define Notify_Preferences "com.mox1121.shortcutpanel.prefschanged"
#define Notify_QuickRequest "com.mox1121.shortcutpanel.quickrequest"

#ifdef DEBUG
    #define NSLog(fmt, ...) NSLog((@"[ShortcutPanel] " fmt), ##__VA_ARGS__)
#else
    #define NSLog(fmt, ...)
#endif
