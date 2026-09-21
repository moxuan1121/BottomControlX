#import <UIKit/UIKit.h>

#ifdef __cplusplus
extern "C" {
#endif

void BCXConfigureSideHandles(BOOL enabled, void (^runAction)(NSDictionary *item));
BOOL BCXBeginSidePanel(NSArray<NSDictionary *> *items, BOOL fromLeft, void (^runAction)(NSDictionary *item));
void BCXUpdatePanel(CGFloat dragDistance);
void BCXFinishPanel(BOOL show);
void BCXHidePanel(void);

#ifdef __cplusplus
}
#endif
