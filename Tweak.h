#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <math.h>

@interface SpringBoard : UIApplication
+ (id)sharedApplication;
- (void)takeScreenshot;
- (id)_accessibilityFrontMostApplication;
- (void)_simulateLockButtonPress;
@end

@interface SBControlCenterController : NSObject
- (id)initWithWindowScene:(id)scene controlCenterCoordinator:(id)coordinator;// iOS 18.6 - ?
- (void)presentAnimated:(BOOL)animated;
@end

@interface SBCoverSheetSlidingViewController : UIViewController
- (CGPoint)_locationForGesture:(id)arg1;
- (id)dismissGestureRecognizer;
@end

@interface SBCoverSheetPresentationManager : NSObject
+ (SBCoverSheetPresentationManager *)sharedInstance;
- (void)setCoverSheetPresented:(BOOL)arg1 animated:(BOOL)arg2 withCompletion:(id)arg3;
@end

