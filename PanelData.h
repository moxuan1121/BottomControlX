#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

#define BCX_PANEL_ACTION 11
#define BCX_PANEL_ITEMS @"panelItems"
#define BCX_ICON_SIZE @"panelIconSize"

NSArray<NSDictionary *> *BCXPanelItems(void);
void BCXSavePanelItems(NSArray<NSDictionary *> *items);
NSArray<NSDictionary *> *BCXBuiltinActions(void);
NSArray<NSDictionary *> *BCXShortcuts(void);
NSArray<NSDictionary *> *BCXInstalledApps(void);
NSArray<NSDictionary *> *BCXQuickActions(NSString *bundleID);
NSArray<NSDictionary *> *BCXQuickActionsForIconView(NSString *bundleID, id iconView);
NSArray<NSDictionary *> *BCXRequestQuickActions(NSString *bundleID);
id BCXQuickActionItem(NSString *bundleID, NSString *type, id iconView);
NSInteger BCXIconSize(void);
void BCXSetIconSize(NSInteger size);
NSString *BCXSymbol(NSDictionary *item);

#ifdef __cplusplus
}
#endif
