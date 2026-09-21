#import <UIKit/UIKit.h>

#ifdef __cplusplus
extern "C" {
#endif

#define BCX_LEFT_ITEMS @"panelItemsLeft"
#define BCX_RIGHT_ITEMS @"panelItemsRight"
#define BCX_ICON_SIZE @"panelIconSize"
#define BCX_HANDLE_HEIGHT @"handleHeight"
#define BCX_HANDLE_POSITION @"handlePosition"
#define BCX_PANEL_MIN_WIDTH @"panelMinimumWidth"

NSArray<NSDictionary *> *BCXPanelItemsForKey(NSString *key);
void BCXSavePanelItemsForKey(NSString *key, NSArray<NSDictionary *> *items);
NSArray<NSDictionary *> *BCXBuiltinActions(void);
NSArray<NSDictionary *> *BCXShortcuts(void);
NSArray<NSDictionary *> *BCXInstalledApps(void);
NSArray<NSDictionary *> *BCXQuickActions(NSString *bundleID);
NSArray<NSDictionary *> *BCXAllQuickActions(void);
NSArray<NSDictionary *> *BCXQuickActionsForIconView(NSString *bundleID, id iconView);
void BCXFetchQuickActions(NSString *bundleID, id iconView, void (^completion)(NSArray<NSDictionary *> *items));
NSArray<NSDictionary *> *BCXRequestQuickActions(NSString *bundleID);
id BCXQuickActionItem(NSString *bundleID, NSString *type, id iconView);
void BCXCacheQuickActions(NSString *bundleID, NSArray *actions);
CGFloat BCXIconSize(void);
void BCXSetIconSize(CGFloat size);
CGFloat BCXHandleHeight(void);
CGFloat BCXHandlePosition(void);
CGFloat BCXPanelMinimumWidth(void);
NSString *BCXSymbol(NSDictionary *item);
UIImage *BCXItemImage(NSDictionary *item, CGFloat size);
UIImage *BCXApplicationIcon(NSString *bundleID);

#ifdef __cplusplus
}
#endif
