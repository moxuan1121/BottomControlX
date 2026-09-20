#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <math.h>

@interface UIApplication (SpringBoard)
- (UIInterfaceOrientation)activeInterfaceOrientation;
@end

@interface SpringBoard : UIApplication
+ (id)sharedApplication;
- (void)takeScreenshot;
- (id)_accessibilityFrontMostApplication;
- (int)_frontMostAppOrientation;
- (void)_simulateLockButtonPress;
@end

@interface SBGrabberTongue : NSObject {
    UIPanGestureRecognizer *_edgePullGestureRecognizer;
    UIView *_tongueContainer;
}
@end

@interface SBFluidSwitcherGestureManager : NSObject
@property(retain, nonatomic) SBGrabberTongue *deckGrabberTongue;
- (void)bcx_handleGesture:(UIPanGestureRecognizer *)recognizer;
@end

@interface SBFluidSwitcherViewController : UIViewController @end
@interface SBFluidSwitcherScreenEdgePanGestureRecognizer : NSObject {
    SBFluidSwitcherViewController *_switcherViewController;
}
@end

@interface SBControlCenterController : NSObject
- (id)initWithWindowScene:(id)scene controlCenterCoordinator:(id)coordinator;// iOS 18.6 - ?
- (void)presentAnimated:(BOOL)animated;
@end

@interface SBCoverSheetSlidingViewController : UIViewController
@property (retain, nonatomic) SBGrabberTongue *grabberTongue;
- (CGPoint)_locationForGesture:(id)arg1;
- (id)dismissGestureRecognizer;
@end

@interface SBCoverSheetPresentationManager : NSObject
+ (SBCoverSheetPresentationManager *)sharedInstance;
- (void)setCoverSheetPresented:(BOOL)arg1 animated:(BOOL)arg2 withCompletion:(id)arg3;
@end

@interface SBLockStateAggregator : NSObject
+ (id)sharedInstance;
- (unsigned long long)lockState;
@end
