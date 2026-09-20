#import "Tweak.h"
#import "Common.h"
#import "PanelData.h"
#import "PanelView.h"
#import <spawn.h>
#import <signal.h>
#import <unistd.h>

#define Home                1
#define CCC                 2
#define Lock                3
#define CS                  9
#define ScreenShot          5
#define SecretShot          6
#define NoAction            10

static BOOL enable;

static int BottomLeftGesture;
static int BottomCenterGesture;
static int BottomRightGesture;

static CGFloat leftValue;
static CGFloat rightValue;
static float velocityValue;
static BOOL lowerSensibility;
static inline UIInterfaceOrientation getAppOrientation();

static int BCXGestureValue(NSDictionary *prefs, NSString *key, NSString *oldHome, NSString *oldApp) {
    if (prefs[key]) return [prefs[key] intValue];
    id home = prefs[oldHome];
    id app = prefs[oldApp];
    if (home && [home intValue] != Home) return [home intValue];
    if (app && [app intValue] != Home) return [app intValue];
    return Home;
}

static void settingsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:PREF_PATH];
    
    enable = (BOOL)[dict[@"enable"] ? : @YES boolValue];
    
    BottomLeftGesture = BCXGestureValue(dict, @"BottomLeftGesture", @"SBBottomLeftGesture", @"AppBottomLeftGesture");
    BottomCenterGesture = BCXGestureValue(dict, @"BottomCenterGesture", @"SBBottomCenterGesture", @"AppBottomCenterGesture");
    BottomRightGesture = BCXGestureValue(dict, @"BottomRightGesture", @"SBBottomRightGesture", @"AppBottomRightGesture");
    
    leftValue = (CGFloat)[dict[@"leftValue"] ? : @0.25 doubleValue];
    rightValue = (CGFloat)[dict[@"rightValue"] ? : @0.75 doubleValue];
    velocityValue = (float)[dict[@"velocityValue"] ? : @150 floatValue];
    
    lowerSensibility = (BOOL)[dict[@"lowerSensibility"] ? : @NO boolValue];
}

static id gControl = nil;

%hook SBControlCenterController
- (id)init {
    gControl = %orig;
    return gControl;
}
- (id)initWithWindowScene:(id)scene controlCenterCoordinator:(id)coordinator {
    if (!gControl) {
        gControl = %orig;
        return gControl;
    }
    return %orig;
}
%end

static void showControlCenter(void) {
    SEL present = @selector(presentAnimated:);
    if (gControl && [gControl respondsToSelector:present]) {
        ((void (*)(id, SEL, BOOL))objc_msgSend)(gControl, present, YES);
    }
}

// SecretShot https://github.com/iCrazeiOS/SBShot https://stackoverflow.com/questions/21415080/make-screenshot-of-the-whole-screen-in-ios7
OBJC_EXTERN UIImage *_UICreateScreenUIImage(void);
void takeScreenshotAndSave() {
    UIImage *image = _UICreateScreenUIImage();
    if (image == nil) return;
    UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil);
}

static BOOL BCXIsLocked(void) {
    Class lockClass = NSClassFromString(@"SBLockStateAggregator");
    return lockClass && ([[lockClass sharedInstance] lockState] & 0x02);
}

static void BCXAlert(NSString *message) {
    UIViewController *root = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class] || scene.activationState != UISceneActivationStateForegroundActive) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if (window.isKeyWindow) { root = window.rootViewController; break; }
        }
        if (root) break;
    }
    if (!root) return;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"快捷面板" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:nil]];
    [root presentViewController:alert animated:YES completion:nil];
}

static BOOL BCXSpawn(NSString *program, NSString *argument) {
    const char *path = jbroot(program.UTF8String);
    if (access(path, X_OK) != 0) return NO;
    pid_t pid = 0;
    char *argv[] = {(char *)path, (char *)argument.UTF8String, NULL};
    extern char **environ;
    return posix_spawn(&pid, path, NULL, NULL, argv, environ) == 0;
}

static id BCXIconViewForBundleID(NSString *bundleID) {
    Class controllerClass = NSClassFromString(@"SBIconController");
    if (![controllerClass respondsToSelector:@selector(sharedInstance)]) return nil;
    @try {
        id controller = [controllerClass sharedInstance];
        id model = [controller respondsToSelector:@selector(model)] ? [controller model] : nil;
        SEL iconSelector = @selector(applicationIconForBundleIdentifier:);
        id icon = [model respondsToSelector:iconSelector]
            ? ((id (*)(id, SEL, id))objc_msgSend)(model, iconSelector, bundleID) : nil;
        SEL mapSelector = @selector(homescreenIconViewMap);
        id map = [controller respondsToSelector:mapSelector]
            ? ((id (*)(id, SEL))objc_msgSend)(controller, mapSelector) : nil;
        SEL viewSelector = @selector(iconViewForIcon:);
        return icon && [map respondsToSelector:viewSelector]
            ? ((id (*)(id, SEL, id))objc_msgSend)(map, viewSelector, icon) : nil;
    } @catch (NSException *exception) {
        return nil;
    }
}

static void BCXQuickRequestReceived(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSDictionary *request = [NSDictionary dictionaryWithContentsOfFile:QUICK_IPC_PATH];
        NSString *token = request[@"token"];
        NSString *bundleID = request[@"app"];
        if (![token isKindOfClass:NSString.class] || ![bundleID isKindOfClass:NSString.class]) return;
        NSArray *actions = BCXQuickActionsForIconView(bundleID, BCXIconViewForBundleID(bundleID));
        [@{@"token":token, @"actions":actions} writeToFile:QUICK_IPC_PATH atomically:YES];
    });
}

static void BCXCloseBackgroundApps(void) {
    Class controllerClass = NSClassFromString(@"SBApplicationController");
    id controller = [controllerClass respondsToSelector:@selector(sharedInstance)] ? [controllerClass sharedInstance] : nil;
    SEL runningSelector = @selector(runningApplications);
    if (![controller respondsToSelector:runningSelector]) return;
    id running = ((id (*)(id, SEL))objc_msgSend)(controller, runningSelector);
    if (![running isKindOfClass:NSArray.class]) return;
    // ponytail: ends running background apps; add switcher-card removal only if users need it.
    for (id app in running) {
        @try {
            SEL internalSelector = @selector(isInternalApplication);
            if ([app respondsToSelector:internalSelector] && ((BOOL (*)(id, SEL))objc_msgSend)(app, internalSelector)) continue;
            SEL stateSelector = @selector(processState);
            id state = [app respondsToSelector:stateSelector]
                ? ((id (*)(id, SEL))objc_msgSend)(app, stateSelector) : nil;
            if (![state respondsToSelector:@selector(pid)] || ![state respondsToSelector:@selector(isForeground)]) continue;
            if (((BOOL (*)(id, SEL))objc_msgSend)(state, @selector(isForeground))) continue;
            pid_t pid = ((pid_t (*)(id, SEL))objc_msgSend)(state, @selector(pid));
            if (pid > 1 && pid != getpid()) kill(pid, SIGTERM);
        } @catch (NSException *exception) { }
    }
}

static void BCXRunPanelItem(NSDictionary *item) {
    NSString *kind = item[@"kind"];
    NSString *identifier = item[@"id"];
    if ([kind isEqualToString:@"shortcut"]) {
        NSString *name = item[@"title"];
        if (![name isKindOfClass:NSString.class] || !name.length) return;
        NSURLComponents *url = [NSURLComponents new];
        url.scheme = @"shortcuts";
        url.host = @"run-shortcut";
        url.queryItems = @[[NSURLQueryItem queryItemWithName:@"name" value:name]];
        [UIApplication.sharedApplication openURL:url.URL options:@{} completionHandler:nil];
        return;
    }
    if ([kind isEqualToString:@"quick"]) {
        NSString *bundleID = item[@"app"];
        id iconView = BCXIconViewForBundleID(bundleID);
        id action = BCXQuickActionItem(bundleID, identifier, iconView);
        Class iconClass = NSClassFromString(@"SBIconView");
        SEL selector = @selector(activateShortcut:withBundleIdentifier:forIconView:);
        if (!action || !iconView || ![iconClass respondsToSelector:selector]) {
            BCXAlert(@"无法运行此应用的图标快捷操作。请确认应用图标仍在桌面，并在设置中重新选择。");
            return;
        }
        @try {
            ((void (*)(id, SEL, id, id, id))objc_msgSend)(iconClass, selector, action, bundleID, iconView);
        } @catch (NSException *exception) {
            BCXAlert(@"无法打开此应用的快捷操作。");
        }
        return;
    }
    if (![kind isEqualToString:@"builtin"]) return;
    if ([identifier isEqualToString:@"control"]) showControlCenter();
    else if ([identifier isEqualToString:@"notification"]) [[%c(SBCoverSheetPresentationManager) sharedInstance] setCoverSheetPresented:YES animated:YES withCompletion:nil];
    else if ([identifier isEqualToString:@"screenshot"]) [(SpringBoard *)UIApplication.sharedApplication takeScreenshot];
    else if ([identifier isEqualToString:@"lock"]) [(SpringBoard *)UIApplication.sharedApplication _simulateLockButtonPress];
    else if ([identifier isEqualToString:@"closeapps"]) BCXCloseBackgroundApps();
    else if ([identifier isEqualToString:@"respring"] || [identifier isEqualToString:@"closeandrespring"]) {
        if ([identifier isEqualToString:@"closeandrespring"]) BCXCloseBackgroundApps();
        if (!BCXSpawn(@"/usr/bin/sbreload", nil)) BCXAlert(@"无法启动 SpringBoard 重启工具。");
    } else if ([identifier isEqualToString:@"userspace"]) {
        if (!BCXSpawn(@"/basebin/jbctl", @"reboot_userspace")) BCXAlert(@"无法启动用户空间重启工具。");
    } else if ([identifier isEqualToString:@"uicache"]) {
        if (!BCXSpawn(@"/usr/bin/uicache", @"-a")) BCXAlert(@"无法启动图标刷新工具。");
    }
}

static BOOL BCXOpenPanel(void) {
    if (getAppOrientation() != UIInterfaceOrientationPortrait || BCXIsLocked()) return NO;
    return BCXShowPanel(BCXPanelItems(), ^(NSDictionary *item) { BCXRunPanelItem(item); });
}

typedef NS_ENUM(NSInteger, GestureZone) {
    GestureZoneLeft,
    GestureZoneCenter,
    GestureZoneRight
};

// Get the exact orientation of the foreground app
static inline UIInterfaceOrientation getAppOrientation() {
    SpringBoard *sb = (SpringBoard *)[UIApplication sharedApplication];
    if ([sb respondsToSelector:@selector(_frontMostAppOrientation)]) {
        int ori = [sb _frontMostAppOrientation];
        if (ori > 0) return (UIInterfaceOrientation)ori;
    }
    return [UIApplication sharedApplication].activeInterfaceOrientation;
}

static inline BOOL isValidUpwardSwipe(CGPoint v, CGFloat minAngleDegrees) {
    if (v.y >= 0) return NO; // Reject anything other than the upward direction (v.y < 0)
    CGFloat swipeAngle = fabs(atan2(v.y, v.x) - (-M_PI_2));
    CGFloat maxAllowedDeviation = (90.0f - minAngleDegrees) * (M_PI / 180.0f);
    return swipeAngle <= maxAllowedDeviation;
}

// Normalization of Points
static inline CGPoint getNormalizedPoint(CGPoint point, UIInterfaceOrientation orientation, CGSize portraitSize) {
    switch (orientation) {
        case UIInterfaceOrientationLandscapeRight:
            // 3: right dock
            return CGPointMake(point.y, portraitSize.width - point.x);
        case UIInterfaceOrientationLandscapeLeft:
            // 4: left dock
            return CGPointMake(portraitSize.height - point.y, point.x);
        case UIInterfaceOrientationPortraitUpsideDown:
            // 2: up dock
            return CGPointMake(portraitSize.width - point.x, portraitSize.height - point.y);
        case UIInterfaceOrientationPortrait:
            // 1: portrait
        default:
            return point;
    }
}
// Normalization of the velocity vector
static inline CGPoint getNormalizedVelocity(CGPoint v, UIInterfaceOrientation orientation) {
    switch (orientation) {
        case UIInterfaceOrientationLandscapeRight:
            // A swipe from bottom to top (in the negative Y direction on the screen) corresponds to the positive X direction in Portrait mode
            return CGPointMake(v.y, -v.x);

        case UIInterfaceOrientationLandscapeLeft:
            // Swiping from bottom to top corresponds to the negative X direction in Portrait mode
            return CGPointMake(-v.y, v.x);

        case UIInterfaceOrientationPortraitUpsideDown:
            return CGPointMake(-v.x, -v.y);

        case UIInterfaceOrientationPortrait:
        default:
            return v;
    }
}
// Zone determination based on ratios
static inline GestureZone getZoneByRatio(CGFloat touchX, CGFloat screenWidth) {
    if (touchX <= screenWidth * leftValue) {
        return GestureZoneLeft;
    } else if (touchX <= screenWidth * rightValue) {
        return GestureZoneCenter;
    }
    return GestureZoneRight;
}

static BOOL BCXClaimsSwipe(CGFloat touchX) {
    CGFloat width = fmin(UIScreen.mainScreen.bounds.size.width, UIScreen.mainScreen.bounds.size.height);
    GestureZone zone = getZoneByRatio(touchX, width);
    int action = zone == GestureZoneLeft ? BottomLeftGesture
        : zone == GestureZoneCenter ? BottomCenterGesture : BottomRightGesture;
    return action != Home && !(action == BCX_PANEL_ACTION && BCXIsLocked());
}

inline int handleSwipeUpGesture(CGFloat startPointX, int leftAction, int centerAction, int rightAction, CGPoint velocity = CGPointMake(1, -6)) {
    if (!isValidUpwardSwipe(velocity, 67.5f)) {
        return 0;
    }

    UIInterfaceOrientation orientation = getAppOrientation();
    CGRect mainBounds = [UIScreen mainScreen].bounds;
    
    CGFloat currentWidth = UIInterfaceOrientationIsLandscape(orientation)
                           ? fmax(mainBounds.size.width, mainBounds.size.height)
                           : fmin(mainBounds.size.width, mainBounds.size.height);

    GestureZone zone = getZoneByRatio(startPointX, currentWidth);
    int targetAction = (zone == GestureZoneLeft)   ? leftAction
                     : (zone == GestureZoneCenter) ? centerAction
                                                   : rightAction;

    switch (targetAction) {
        case BCX_PANEL_ACTION:
            return BCXOpenPanel() ? 1 : 0;
        case CCC:
            showControlCenter();
            return 1;
        case Lock:
            [(SpringBoard *)[UIApplication sharedApplication] _simulateLockButtonPress];
            return 1;
        case CS:
            [[%c(SBCoverSheetPresentationManager) sharedInstance] setCoverSheetPresented:YES animated:YES withCompletion:nil];
            return 1;
        case ScreenShot:
            [(SpringBoard *)[UIApplication sharedApplication] takeScreenshot];
            return 1;
        case SecretShot:
            takeScreenshotAndSave();
            return 1;
        case NoAction:
            return -1;
        case Home:
        default:
            return 0;
    }
}

// handle fluid gesture
static BOOL isFluidGestureTriggered = NO;

%hook SBFluidSwitcherGestureManager
// iOS 11 - 13.x
// https://developer.limneos.net/?ios=11.1.2&framework=SpringBoard&header=SBFluidSwitcherGestureManager.h
- (void)grabberTongueBeganPulling:(id)arg1 withDistance:(double)arg2 andVelocity:(double)arg3 {
    if (!enable || getAppOrientation() != UIInterfaceOrientationPortrait || BCXIsLocked()) {
        %orig;
        return;
    }

    UIPanGestureRecognizer *recognizer = [self.deckGrabberTongue valueForKey:@"_edgePullGestureRecognizer"];
    
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        isFluidGestureTriggered = NO;
    }

    if (isFluidGestureTriggered) {
        return;
    }

    UIView *container = [self.deckGrabberTongue valueForKey:@"_tongueContainer"];
    CGPoint rawPoint = [recognizer locationInView:container];
    CGPoint rawVelocity = [recognizer velocityInView:container];

    UIInterfaceOrientation orientation = getAppOrientation();
    
    // Since the `bounds` may already be rotated depending on the iOS version, ensure the dimensions correspond to Portrait orientation
    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    CGSize portraitSize = CGSizeMake(fmin(screenSize.width, screenSize.height), fmax(screenSize.width, screenSize.height));

    CGPoint normalizedPoint = getNormalizedPoint(rawPoint, orientation, portraitSize);
    CGPoint normalizedVelocity = getNormalizedVelocity(rawVelocity, orientation);
    
    int result = (lowerSensibility && arg3 <= velocityValue) ? 0
        : handleSwipeUpGesture(normalizedPoint.x, BottomLeftGesture, BottomCenterGesture, BottomRightGesture, normalizedVelocity);

    if (result != 0) {
        isFluidGestureTriggered = YES;
        return;
    } else if (BCXClaimsSwipe(normalizedPoint.x)) {
        return;
    } else {
        %orig;
    }
}
// iOS 13.4? or laetr
- (void)grabberTongueBeganPulling:(id)arg1 withDistance:(double)arg2 andVelocity:(double)arg3 andGesture:(id)arg4 {
    if (!enable || getAppOrientation() != UIInterfaceOrientationPortrait || BCXIsLocked()) {
        %orig;
        return;
    }

    UIPanGestureRecognizer *recognizer = [self.deckGrabberTongue valueForKey:@"_edgePullGestureRecognizer"];
    
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        isFluidGestureTriggered = NO;
    }

    if (isFluidGestureTriggered) {
        return;
    }

    UIView *container = [self.deckGrabberTongue valueForKey:@"_tongueContainer"];
    CGPoint rawPoint = [recognizer locationInView:container];
    CGPoint rawVelocity = [recognizer velocityInView:container];

    UIInterfaceOrientation orientation = getAppOrientation();
    
    // Since the `bounds` may already be rotated depending on the iOS version, ensure the dimensions correspond to Portrait orientation
    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    CGSize portraitSize = CGSizeMake(fmin(screenSize.width, screenSize.height), fmax(screenSize.width, screenSize.height));

    CGPoint normalizedPoint = getNormalizedPoint(rawPoint, orientation, portraitSize);
    CGPoint normalizedVelocity = getNormalizedVelocity(rawVelocity, orientation);
    
    int result = (lowerSensibility && arg3 <= velocityValue) ? 0
        : handleSwipeUpGesture(normalizedPoint.x, BottomLeftGesture, BottomCenterGesture, BottomRightGesture, normalizedVelocity);

    if (result != 0) {
        isFluidGestureTriggered = YES;
        return;
    } else if (BCXClaimsSwipe(normalizedPoint.x)) {
        return;
    } else {
        %orig;
    }
}
%end

%ctor {
    %init;
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL,
        BCXQuickRequestReceived, CFSTR(Notify_QuickRequest), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    // Settings Notifications
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                    NULL,
                                    settingsChanged,
                                    CFSTR(Notify_Preferences),
                                    NULL,
                                    CFNotificationSuspensionBehaviorCoalesce);

    settingsChanged(NULL, NULL, NULL, NULL, NULL);
}
