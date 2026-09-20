#import <Foundation/Foundation.h>

#define BCX_PANEL_ACTION 11
#define BCX_PANEL_ITEMS @"panelItems"
#define BCX_ICON_SIZE @"panelIconSize"

NSArray<NSDictionary *> *BCXPanelItems(void);
void BCXSavePanelItems(NSArray<NSDictionary *> *items);
NSArray<NSDictionary *> *BCXBuiltinActions(void);
NSArray<NSDictionary *> *BCXShortcuts(void);
NSString *BCXShortcutName(NSString *identifier);
NSArray<NSDictionary *> *BCXInstalledApps(void);
NSArray<NSDictionary *> *BCXQuickActions(NSString *bundleID);
id BCXQuickActionItem(NSString *bundleID, NSString *type);
NSInteger BCXIconSize(void);
void BCXSetIconSize(NSInteger size);
NSString *BCXSymbol(NSDictionary *item);
