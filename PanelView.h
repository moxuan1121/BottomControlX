#import <UIKit/UIKit.h>

BOOL BCXShowPanel(NSArray<NSDictionary *> *items, void (^runAction)(NSDictionary *item));
void BCXHidePanel(void);
