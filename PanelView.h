#import <UIKit/UIKit.h>

#ifdef __cplusplus
extern "C" {
#endif

BOOL BCXShowPanel(NSArray<NSDictionary *> *items, void (^runAction)(NSDictionary *item));
void BCXHidePanel(void);

#ifdef __cplusplus
}
#endif
