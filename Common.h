#include <roothide.h>

#define PREF_PATH jbroot(@"/var/mobile/Library/Preferences/com.ichitaso.bottomcontrolx.plist")
#define QUICK_IPC_PATH jbroot(@"/var/mobile/Library/Preferences/com.ichitaso.bottomcontrolx.quick.plist")
#define Notify_Preferences "com.ichitaso.bottomcontrolx.prefschanged"
#define Notify_QuickRequest "com.ichitaso.bottomcontrolx.quickrequest"

#define IS_PAD ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)

#define TWEAK_TITLE @"BottomControlX"
#define TWEAK_DESCRIPTION @"底部上滑快捷面板"
#define BUNDLE_NAME @"BottomControlX.bundle"
#define BUNDLE_ID @"com.ichitaso.bottomcontrolx"

#define CREDITS @"© 2015-2026 Cannathea by ichitaso"

#define SettingsColor(alphaValue) [UIColor colorWithRed:30.0f/255.0f green:144.0f/255.0f blue:255.0f/255.0f alpha:alphaValue]
#define PSTableColor(alphaValue) [UIColor colorWithRed:0.00 green:0.00 blue:0.00 alpha:alphaValue]
#define PSDarkColor(alphaValue) [UIColor colorWithRed:1.00 green:1.00 blue:1.00 alpha:alphaValue]

#ifdef DEBUG
    #define NSLog(fmt, ...) NSLog((@"[BottomControlX] " fmt), ##__VA_ARGS__)
#else
    #define NSLog(fmt, ...)
#endif
