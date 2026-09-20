#import "Tweak.h"
#import "Common.h"
#import "PanelData.h"
#import "PanelView.h"
#import <spawn.h>
#import <signal.h>
#import <unistd.h>
#import <sys/wait.h>
#import <dlfcn.h>
#import <objc/runtime.h>

#define Home                1
#define CCC                 2
#define Lock                3
#define CS                  9
#define ScreenShot          5
#define SecretShot          6
#define NoAction            10

static BOOL enable;
static CGFloat leftValue;
static CGFloat rightWidth;

static inline UIInterfaceOrientation getAppOrientation();

static void settingsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:PREF_PATH];
    enable = (BOOL)[dict[@"enable"] ? : @YES boolValue];
    leftValue = (CGFloat)[dict[@"leftValue"] ? : @0.25 doubleValue];
    rightWidth = (CGFloat)[dict[@"rightWidth"] ? : @0.25 doubleValue];
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

static BOOL BCXRebootUserspace(void) {
    const char *jbctl = jbroot("/basebin/jbctl");
    pid_t pid = 0;
    char *argv[] = {(char *)jbctl, "reboot_userspace", NULL};
    extern char **environ;
    if (access(jbctl, X_OK) == 0 && posix_spawn(&pid, jbctl, NULL, NULL, argv, environ) == 0) {
        int status = 0;
        if (waitpid(pid, &status, 0) < 0 || !WIFEXITED(status) || WEXITSTATUS(status) == 0) return YES;
    }
    const char *launchctl = "/bin/launchctl";
    char *fallback[] = {(char *)launchctl, "reboot", "userspace", NULL};
    return posix_spawn(&pid, launchctl, NULL, NULL, fallback, environ) == 0;
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
        id view = icon && [map respondsToSelector:viewSelector]
            ? ((id (*)(id, SEL, id))objc_msgSend)(map, viewSelector, icon) : nil;
        if (view || !icon) return view;
        Class viewClass = NSClassFromString(@"SBIconView");
        SEL initializer = @selector(initWithConfigurationOptions:);
        view = [viewClass instancesRespondToSelector:initializer]
            ? ((id (*)(id, SEL, NSUInteger))objc_msgSend)([viewClass alloc], initializer, 0) : [viewClass new];
        if ([view respondsToSelector:@selector(setIcon:)])
            ((void (*)(id, SEL, id))objc_msgSend)(view, @selector(setIcon:), icon);
        return view;
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

static BOOL BCXActivateQuickAction(id action, NSString *bundleID, id iconView) {
    Class iconClass = NSClassFromString(@"SBIconView");
    SEL activate = @selector(activateShortcut:withBundleIdentifier:forIconView:);
    @try {
        if (iconView && [iconClass respondsToSelector:activate]) {
            ((void (*)(id, SEL, id, id, id))objc_msgSend)(iconClass, activate, action, bundleID, iconView);
            return YES;
        }
        dlopen("/System/Library/PrivateFrameworks/FrontBoardServices.framework/FrontBoardServices", RTLD_LAZY);
        Class actionClass = NSClassFromString(@"UIHandleApplicationShortcutAction");
        Class optionsClass = NSClassFromString(@"FBSOpenApplicationOptions");
        Class serviceClass = NSClassFromString(@"FBSOpenApplicationService");
        SEL initAction = @selector(initWithSBSShortcutItem:);
        SEL makeOptions = @selector(optionsWithDictionary:);
        SEL open = @selector(openApplication:withOptions:completion:);
        if (![actionClass instancesRespondToSelector:initAction] || ![optionsClass respondsToSelector:makeOptions] ||
            ![serviceClass instancesRespondToSelector:open]) return NO;
        id launchAction = ((id (*)(id, SEL, id))objc_msgSend)([actionClass alloc], initAction, action);
        if (!launchAction) return NO;
        SEL modeSelector = @selector(activationMode);
        BOOL suspended = [action respondsToSelector:modeSelector] &&
            ((NSUInteger (*)(id, SEL))objc_msgSend)(action, modeSelector) == 1;
        NSDictionary *values = @{@"__ActivateSuspended":@(suspended), @"__Actions":@[launchAction],
            @"__PromptUnlockDevice":@YES, @"__LaunchOrigin":@"__SBLaunchOriginShortcutItem"};
        id options = ((id (*)(id, SEL, id))objc_msgSend)(optionsClass, makeOptions, values);
        id service = [serviceClass new];
        ((void (*)(id, SEL, id, id, id))objc_msgSend)(service, open, bundleID, options, nil);
        return YES;
    } @catch (NSException *exception) { return NO; }
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

// iOS 15 VoiceShortcutClient runs the workflow from SpringBoard without opening Shortcuts.
static BOOL BCXRunShortcut(NSString *identifier) {
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:identifier];
    if (!uuid) return NO;
    if (!dlopen("/System/Library/PrivateFrameworks/VoiceShortcutClient.framework/VoiceShortcutClient", RTLD_LAZY)) return NO;
    Class runnerClass = NSClassFromString(@"WFSpringBoardWorkflowRunnerClient");
    SEL initializer = @selector(initWithWorkflowIdentifier:);
    if (![runnerClass instancesRespondToSelector:initializer]) return NO;
    @try {
        id runner = ((id (*)(id, SEL, id))objc_msgSend)([runnerClass alloc], initializer, uuid.UUIDString);
        if (!runner || ![runner respondsToSelector:@selector(start)]) return NO;
        ((void (*)(id, SEL))objc_msgSend)(runner, @selector(start));
        return YES;
    } @catch (NSException *exception) { return NO; }
}

static void BCXRunPanelItem(NSDictionary *item) {
    NSString *kind = item[@"kind"];
    NSString *identifier = item[@"id"];
    if ([kind isEqualToString:@"shortcut"]) {
        if (!BCXRunShortcut(identifier)) BCXAlert(@"无法在后台运行此快捷指令，请在设置中重新选择。");
        return;
    }
    if ([kind isEqualToString:@"quick"]) {
        NSString *bundleID = item[@"app"];
        id iconView = BCXIconViewForBundleID(bundleID);
        id action = BCXQuickActionItem(bundleID, identifier, iconView);
        if (!action) {
            BCXAlert(@"此应用的快捷操作已不可用，请在设置中重新选择。");
            return;
        }
        if (!BCXActivateQuickAction(action, bundleID, iconView)) {
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
        if (!BCXRebootUserspace()) BCXAlert(@"无法启动用户空间重启工具。");
    } else if ([identifier isEqualToString:@"uicache"]) {
        if (!BCXSpawn(@"/usr/bin/uicache", @"-a")) BCXAlert(@"无法启动图标刷新工具。");
    }
}

static inline UIInterfaceOrientation getAppOrientation() {
    SpringBoard *sb = (SpringBoard *)UIApplication.sharedApplication;
    if ([sb respondsToSelector:@selector(_frontMostAppOrientation)]) {
        int orientation = [sb _frontMostAppOrientation];
        if (orientation > 0) return (UIInterfaceOrientation)orientation;
    }
    return UIApplication.sharedApplication.activeInterfaceOrientation;
}

static __weak UIPanGestureRecognizer *activeRecognizer;
static NSArray<NSDictionary *> *activeItems;

static BOOL BCXBeginSwipe(SBFluidSwitcherGestureManager *manager) {
    if (!enable || getAppOrientation() != UIInterfaceOrientationPortrait || BCXIsLocked()) return NO;
    UIPanGestureRecognizer *recognizer = nil;
    @try { recognizer = [manager.deckGrabberTongue valueForKey:@"_edgePullGestureRecognizer"]; }
    @catch (NSException *exception) { return NO; }
    if (![recognizer isKindOfClass:UIPanGestureRecognizer.class]) return NO;
    CGFloat x = [recognizer locationInView:nil].x;
    CGFloat width = UIScreen.mainScreen.bounds.size.width;
    NSString *zoneKey = x <= width * leftValue ? BCX_LEFT_ITEMS
        : x >= width * (1 - rightWidth) ? BCX_RIGHT_ITEMS : BCX_CENTER_ITEMS;
    NSArray *items = BCXPanelItemsForKey(zoneKey);
    if (!items.count) return NO;
    if (activeRecognizer != recognizer) {
        activeRecognizer = recognizer;
        activeItems = items;
        [recognizer addTarget:manager action:@selector(bcx_handleGesture:)];
        if (items.count > 1) {
            if (!BCXBeginPanel(items, ^(NSDictionary *item) { BCXRunPanelItem(item); })) {
                [recognizer removeTarget:manager action:@selector(bcx_handleGesture:)];
                activeRecognizer = nil;
                activeItems = nil;
                return NO;
            }
        }
    }
    return YES;
}

%hook SBFluidSwitcherGestureManager

%new
- (void)bcx_handleGesture:(UIPanGestureRecognizer *)recognizer {
    if (activeRecognizer != recognizer) return;
    UIGestureRecognizerState state = recognizer.state;
    CGFloat distance = MAX(0, -[recognizer translationInView:nil].y);
    if (state == UIGestureRecognizerStateChanged || state == UIGestureRecognizerStateBegan) {
        if (activeItems.count > 1) BCXUpdatePanel(distance);
    } else if (state == UIGestureRecognizerStateEnded ||
               state == UIGestureRecognizerStateCancelled ||
               state == UIGestureRecognizerStateFailed) {
        BOOL commit = state == UIGestureRecognizerStateEnded && distance >= 80;
        if (activeItems.count > 1) BCXFinishPanel(commit);
        else if (commit && activeItems.count == 1) BCXRunPanelItem(activeItems.firstObject);
        [recognizer removeTarget:self action:@selector(bcx_handleGesture:)];
        activeRecognizer = nil;
        activeItems = nil;
    }
}

- (void)grabberTongueBeganPulling:(id)arg1 withDistance:(double)arg2 andVelocity:(double)arg3 {
    if (!BCXBeginSwipe(self)) %orig;
}

- (void)grabberTongueBeganPulling:(id)arg1 withDistance:(double)arg2 andVelocity:(double)arg3 andGesture:(id)arg4 {
    if (!BCXBeginSwipe(self)) %orig;
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
