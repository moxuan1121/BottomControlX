#import <UIKit/UIKit.h>

#ifdef __cplusplus
extern "C" {
#endif

BOOL BCXBeginPanel(NSArray<NSDictionary *> *items, void (^runAction)(NSDictionary *item));
void BCXUpdatePanel(CGFloat progress);
void BCXFinishPanel(BOOL show);
void BCXHidePanel(void);

#ifdef __cplusplus
}
#endif
