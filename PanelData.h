#import <UIKit/UIKit.h>

#ifdef __cplusplus
extern "C" {
#endif

#define BCX_LEFT_ITEMS @"panelItemsLeft"
#define BCX_RIGHT_ITEMS @"panelItemsRight"
#define BCX_HANDLE_SIDE @"handleSide"
#define BCX_ICON_SIZE @"panelIconSize"
#define BCX_HANDLE_HEIGHT @"handleHeight"
#define BCX_HANDLE_POSITION @"handlePosition"
#define BCX_HANDLE_INDICATOR_POSITION @"handleIndicatorPosition"
#define BCX_HANDLE_SHADOW_WIDTH @"handleShadowWidth"
#define BCX_HANDLE_SHADOW_POSITION @"handleShadowPosition"
#define BCX_PANEL_MIN_WIDTH @"panelMinimumWidth"
#define BCX_HANDLE_TRIGGER_DISTANCE @"handleTriggerDistance"
#define BCX_HANDLE_FAST_DISTANCE @"handleFastDistance"
#define BCX_HANDLE_FAST_VELOCITY @"handleFastVelocity"

NSArray<NSDictionary *> *BCXPanelItemsForKey(NSString *key);
NSArray<NSDictionary *> *BCXHandleItems(void);
BOOL BCXHandleOnRight(void);
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
CGFloat BCXHandleIndicatorPosition(void);
CGFloat BCXHandleShadowWidth(void);
CGFloat BCXHandleShadowPosition(void);
CGFloat BCXPanelMinimumWidth(void);
CGFloat BCXHandleTriggerDistance(void);
CGFloat BCXHandleFastDistance(void);
CGFloat BCXHandleFastVelocity(void);
NSString *BCXSymbol(NSDictionary *item);
UIImage *BCXItemImage(NSDictionary *item, CGFloat size);
UIImage *BCXApplicationIcon(NSString *bundleID);

#ifdef __cplusplus
}
#endif
