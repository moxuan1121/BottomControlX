#import <UIKit/UIKit.h>

#ifdef __cplusplus
extern "C" {
#endif

#define BCX_PANEL_ACTION 11
#define BCX_PANEL_ITEMS @"panelItems"
#define BCX_LEFT_ITEMS @"panelItemsLeft"
#define BCX_CENTER_ITEMS @"panelItemsCenter"
#define BCX_RIGHT_ITEMS @"panelItemsRight"
#define BCX_ICON_SIZE @"panelIconSize"

NSArray<NSDictionary *> *BCXPanelItems(void);
void BCXSavePanelItems(NSArray<NSDictionary *> *items);
NSArray<NSDictionary *> *BCXPanelItemsForKey(NSString *key);
void BCXSavePanelItemsForKey(NSString *key, NSArray<NSDictionary *> *items);
NSArray<NSDictionary *> *BCXBuiltinActions(void);
NSArray<NSDictionary *> *BCXShortcuts(void);
NSArray<NSDictionary *> *BCXInstalledApps(void);
NSArray<NSDictionary *> *BCXQuickActions(NSString *bundleID);
NSArray<NSDictionary *> *BCXQuickActionsForIconView(NSString *bundleID, id iconView);
void BCXFetchQuickActions(NSString *bundleID, id iconView, void (^completion)(NSArray<NSDictionary *> *items));
NSArray<NSDictionary *> *BCXRequestQuickActions(NSString *bundleID);
id BCXQuickActionItem(NSString *bundleID, NSString *type, id iconView);
CGFloat BCXIconSize(void);
void BCXSetIconSize(CGFloat size);
NSString *BCXSymbol(NSDictionary *item);
UIImage *BCXItemImage(NSDictionary *item, CGFloat size);
UIImage *BCXApplicationIcon(NSString *bundleID);

#ifdef __cplusplus
}
#endif
