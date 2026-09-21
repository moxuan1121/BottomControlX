#import "Tweak.h"
#import "Common.h"
#import "PanelData.h"
#import "PanelView.h"
#import <spawn.h>
#import <signal.h>
#import <unistd.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#import <stdint.h>

static BOOL enable;
static CGFloat leftValue;
static CGFloat rightWidth;
static BOOL showGestureAreas;
static const CGFloat BCXCornerInset = 0;

static inline UIInterfaceOrientation getAppOrientation();
static void BCXUpdateDebugOverlay(void);

static void settingsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:PREF_PATH]
        ?: [NSDictionary dictionaryWithContentsOfFile:LEGACY_PREF_PATH];
    enable = (BOOL)[dict[@"enable"] ? : @YES boolValue];
    leftValue = (CGFloat)[dict[@"leftValue"] ? : @0.25 doubleValue];
    rightWidth = (CGFloat)[dict[@"rightWidth"] ? : @0.25 doubleValue];
    showGestureAreas = (BOOL)[dict[@"showGestureAreas"] boolValue];
    dispatch_async(dispatch_get_main_queue(), ^{ BCXUpdateDebugOverlay(); });
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
    const char *library = jbroot("/basebin/libjailbreak.dylib");
    void *handle = dlopen(library, RTLD_NOW | RTLD_LOCAL);
    typedef int (*BCXSetMacLabel)(uint64_t, uint64_t, uint64_t *);
    typedef int (*BCXExecSuspended)(pid_t *, const char *, ...);
    BCXSetMacLabel setMacLabel = handle ? (BCXSetMacLabel)dlsym(handle, "jbclient_root_set_mac_label") : NULL;
    BCXExecSuspended execSuspended = handle ? (BCXExecSuspended)dlsym(handle, "exec_cmd_suspended") : NULL;
    if (!setMacLabel || !execSuspended || access(jbctl, X_OK) != 0) {
        if (handle) dlclose(handle);
        return NO;
    }

    uid_t originalUser = getuid();
    gid_t originalGroup = getgid();
    int userResult = originalUser == 0 ? 0 : setuid(0);
    int groupResult = originalGroup == 0 ? 0 : setgid(0);
    if (userResult != 0 || groupResult != 0) {
        if (groupResult == 0 && originalGroup != 0) setgid(originalGroup);
        if (userResult == 0 && originalUser != 0) seteuid(originalUser);
        dlclose(handle);
        return NO;
    }

    uint64_t originalLabel = 0;
    BOOL labelChanged = setMacLabel(1, UINT64_MAX, &originalLabel) == 0;
    pid_t pid = 0;
    BOOL started = labelChanged && execSuspended(&pid, jbctl, "reboot_userspace", NULL) == 0;
    if (started) kill(pid, SIGCONT);
    if (labelChanged) setMacLabel(1, originalLabel, NULL);
    if (originalGroup != 0) setgid(originalGroup);
    if (originalUser != 0) seteuid(originalUser);
    dlclose(handle);
    return started;
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

static void BCXFetchAllQuickActions(void (^completion)(NSArray<NSDictionary *> *items)) {
    NSArray<NSDictionary *> *apps = BCXInstalledApps();
    NSMutableArray<NSDictionary *> *result = [NSMutableArray array];
    dispatch_group_t group = dispatch_group_create();
    __block BOOL finished = NO;
    void (^finish)(void) = ^{
        if (finished) return;
        finished = YES;
        completion([result copy]);
    };
    for (NSDictionary *app in apps) {
        NSString *bundleID = app[@"id"];
        dispatch_group_enter(group);
        BCXFetchQuickActions(bundleID, BCXIconViewForBundleID(bundleID), ^(NSArray<NSDictionary *> *actions) {
            for (NSDictionary *action in actions) {
                NSMutableDictionary *entry = [action mutableCopy];
                entry[@"appTitle"] = app[@"title"] ?: bundleID;
                [result addObject:entry];
            }
            dispatch_group_leave(group);
        });
    }
    dispatch_group_notify(group, dispatch_get_main_queue(), finish);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), dispatch_get_main_queue(), finish);
}

static void BCXQuickRequestReceived(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSDictionary *request = [NSDictionary dictionaryWithContentsOfFile:QUICK_IPC_PATH];
        NSString *token = request[@"token"];
        NSString *bundleID = request[@"app"];
        if (![token isKindOfClass:NSString.class] || ![bundleID isKindOfClass:NSString.class]) return;
        if ([bundleID isEqualToString:@"*"]) {
            BCXFetchAllQuickActions(^(NSArray<NSDictionary *> *actions) {
                NSArray *resolved = actions.count ? actions : BCXAllQuickActions();
                [@{@"token":token, @"actions":resolved} writeToFile:QUICK_IPC_PATH atomically:YES];
            });
            return;
        }
        id iconView = BCXIconViewForBundleID(bundleID);
        __block BOOL replied = NO;
        void (^reply)(NSArray *) = ^(NSArray *actions) {
            if (replied) return;
            replied = YES;
            [@{@"token":token, @"actions":actions ?: @[]} writeToFile:QUICK_IPC_PATH atomically:YES];
        };
        BCXFetchQuickActions(bundleID, iconView, reply);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 4 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            reply(BCXQuickActionsForIconView(bundleID, iconView));
        });
    });
}

static BOOL BCXActivateQuickAction(id action, NSString *bundleID, id iconView) {
    SEL activate = @selector(activateShortcut:withBundleIdentifier:forIconView:);
    @try {
        Class iconClass = NSClassFromString(@"SBIconView");
        if ([iconClass respondsToSelector:activate]) {
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

static id BCXQuickActionFallback(NSDictionary *item) {
    Class itemClass = NSClassFromString(@"UIApplicationShortcutItem");
    SEL initializer = @selector(initWithType:localizedTitle:subtitle:icon:userInfo:);
    if (![itemClass instancesRespondToSelector:initializer]) return nil;
    @try {
        return ((id (*)(id, SEL, id, id, id, id, id))objc_msgSend)([itemClass alloc], initializer,
            item[@"id"], item[@"title"] ?: @"", @"", nil,
            [item[@"userInfo"] isKindOfClass:NSDictionary.class] ? item[@"userInfo"] : nil);
    } @catch (NSException *exception) { return nil; }
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

static BOOL BCXPowerAction(BOOL reboot) {
    dlopen("/System/Library/PrivateFrameworks/FrontBoardServices.framework/FrontBoardServices", RTLD_LAZY);
    Class serviceClass = NSClassFromString(@"FBSystemService");
    SEL shared = @selector(sharedInstance);
    SEL action = @selector(shutdownAndReboot:);
    if (![serviceClass respondsToSelector:shared]) return NO;
    id service = ((id (*)(id, SEL))objc_msgSend)(serviceClass, shared);
    if (![service respondsToSelector:action]) return NO;
    ((void (*)(id, SEL, BOOL))objc_msgSend)(service, action, reboot);
    return YES;
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
        id action = BCXQuickActionItem(bundleID, identifier, iconView) ?: BCXQuickActionFallback(item);
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
    else if ([identifier isEqualToString:@"respring"]) kill(getpid(), SIGTERM);
    else if ([identifier isEqualToString:@"closeandrespring"]) {
        BCXCloseBackgroundApps();
        kill(getpid(), SIGTERM);
    } else if ([identifier isEqualToString:@"userspace"]) {
        if (!BCXRebootUserspace()) BCXAlert(@"无法启动用户空间重启工具。");
    } else if ([identifier isEqualToString:@"reboot"]) {
        if (!BCXPowerAction(YES)) BCXAlert(@"无法重启手机。");
    } else if ([identifier isEqualToString:@"shutdown"]) {
        if (!BCXPowerAction(NO)) BCXAlert(@"无法关闭手机。");
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

static NSString *BCXBundleIDForIconView(id iconView) {
    @try {
        for (NSString *name in @[@"applicationBundleIdentifier", @"bundleIdentifier"]) {
            SEL selector = NSSelectorFromString(name);
            id value = [iconView respondsToSelector:selector]
                ? ((id (*)(id, SEL))objc_msgSend)(iconView, selector) : nil;
            if ([value isKindOfClass:NSString.class] && [value length]) return value;
        }
        id icon = [iconView respondsToSelector:@selector(icon)]
            ? ((id (*)(id, SEL))objc_msgSend)(iconView, @selector(icon)) : nil;
        for (NSString *name in @[@"applicationBundleID", @"applicationBundleIdentifier", @"bundleIdentifier"]) {
            SEL selector = NSSelectorFromString(name);
            id value = [icon respondsToSelector:selector]
                ? ((id (*)(id, SEL))objc_msgSend)(icon, selector) : nil;
            if ([value isKindOfClass:NSString.class] && [value length]) return value;
        }
    } @catch (NSException *exception) { }
    return nil;
}

%hook SBIconView
- (void)setApplicationShortcutItems:(NSArray *)items {
    %orig;
    BCXCacheQuickActions(BCXBundleIDForIconView(self), items);
}
%end

static __weak UIPanGestureRecognizer *activeRecognizer;
static NSArray<NSDictionary *> *activeItems;
static BOOL activeCancelsTouches;
static BOOL activeDelaysTouchesBegan;
static BOOL activeDelaysTouchesEnded;
static UIWindow *debugGestureWindow;
static const void *BCXOwnRecognizerKey = &BCXOwnRecognizerKey;

static NSString *BCXZoneKeyAtX(CGFloat x) {
    CGFloat width = UIScreen.mainScreen.bounds.size.width;
    if (width <= 0) return nil;
    CGFloat position = x / width;
    CGFloat leftEnd = MIN(0.48, BCXCornerInset + leftValue);
    CGFloat rightStart = MAX(0.52, 1 - BCXCornerInset - rightWidth);
    if (position >= BCXCornerInset && position <= leftEnd) return BCX_LEFT_ITEMS;
    if (position >= rightStart && position <= 1 - BCXCornerInset) return BCX_RIGHT_ITEMS;
    return nil;
}

static BOOL BCXClaimsX(CGFloat x) {
    if (!enable || getAppOrientation() != UIInterfaceOrientationPortrait || BCXIsLocked()) return NO;
    NSString *zoneKey = BCXZoneKeyAtX(x);
    return zoneKey && BCXPanelItemsForKey(zoneKey).count > 0;
}

static void BCXUpdateDebugOverlay(void) {
    if (!showGestureAreas) {
        debugGestureWindow.hidden = YES;
        debugGestureWindow = nil;
        return;
    }
    UIWindowScene *scene = nil;
    for (UIScene *candidate in UIApplication.sharedApplication.connectedScenes) {
        if ([candidate isKindOfClass:UIWindowScene.class] && candidate.activationState == UISceneActivationStateForegroundActive) {
            scene = (UIWindowScene *)candidate;
            break;
        }
    }
    if (!scene) return;
    if (!debugGestureWindow) {
        debugGestureWindow = [[UIWindow alloc] initWithWindowScene:scene];
        debugGestureWindow.windowLevel = UIWindowLevelStatusBar + 100;
        debugGestureWindow.userInteractionEnabled = NO;
        UIViewController *controller = [UIViewController new];
        controller.view.backgroundColor = UIColor.clearColor;
        debugGestureWindow.rootViewController = controller;
        for (NSInteger tag = 1; tag <= 2; tag++) {
            UIView *area = [UIView new];
            area.tag = tag;
            area.layer.borderWidth = 1;
            [controller.view addSubview:area];
        }
    }
    CGRect bounds = scene.coordinateSpace.bounds;
    CGFloat width = bounds.size.width;
    CGFloat leftEnd = MIN(0.48, BCXCornerInset + leftValue);
    CGFloat rightStart = MAX(0.52, 1 - BCXCornerInset - rightWidth);
    UIView *left = [debugGestureWindow.rootViewController.view viewWithTag:1];
    UIView *right = [debugGestureWindow.rootViewController.view viewWithTag:2];
    left.frame = CGRectMake(width * BCXCornerInset, bounds.size.height - 24, width * (leftEnd - BCXCornerInset), 24);
    right.frame = CGRectMake(width * rightStart, bounds.size.height - 24, width * (1 - BCXCornerInset - rightStart), 24);
    left.backgroundColor = [UIColor.systemRedColor colorWithAlphaComponent:0.32];
    left.layer.borderColor = UIColor.systemRedColor.CGColor;
    right.backgroundColor = [UIColor.systemBlueColor colorWithAlphaComponent:0.32];
    right.layer.borderColor = UIColor.systemBlueColor.CGColor;
    debugGestureWindow.frame = bounds;
    debugGestureWindow.hidden = NO;
}

static BOOL BCXBeginRecognizer(SBFluidSwitcherGestureManager *manager, UIPanGestureRecognizer *recognizer) {
    if (!enable || getAppOrientation() != UIInterfaceOrientationPortrait || BCXIsLocked()) return NO;
    if (![recognizer isKindOfClass:UIPanGestureRecognizer.class]) return NO;
    CGPoint translation = [recognizer translationInView:nil];
    CGPoint velocity = [recognizer velocityInView:nil];
    BOOL clearlyHorizontal = fabs(translation.x) > 12 && fabs(translation.x) > fabs(translation.y) * 1.25;
    clearlyHorizontal |= fabs(velocity.x) > 300 && fabs(velocity.x) > fabs(velocity.y) * 1.8;
    if (clearlyHorizontal) return NO;
    if (showGestureAreas && !debugGestureWindow) BCXUpdateDebugOverlay();
    NSString *zoneKey = BCXZoneKeyAtX([recognizer locationInView:nil].x);
    if (!zoneKey) return NO;
    NSArray *items = BCXPanelItemsForKey(zoneKey);
    if (!items.count) return NO;
    if (activeRecognizer != recognizer) {
        activeRecognizer = recognizer;
        activeItems = items;
        activeCancelsTouches = recognizer.cancelsTouchesInView;
        activeDelaysTouchesBegan = recognizer.delaysTouchesBegan;
        activeDelaysTouchesEnded = recognizer.delaysTouchesEnded;
        recognizer.cancelsTouchesInView = YES;
        recognizer.delaysTouchesBegan = YES;
        recognizer.delaysTouchesEnded = YES;
        [recognizer addTarget:manager action:@selector(bcx_handleGesture:)];
        if (items.count > 1) {
            if (!BCXBeginPanel(items, ^(NSDictionary *item) { BCXRunPanelItem(item); })) {
                [recognizer removeTarget:manager action:@selector(bcx_handleGesture:)];
                recognizer.cancelsTouchesInView = activeCancelsTouches;
                recognizer.delaysTouchesBegan = activeDelaysTouchesBegan;
                recognizer.delaysTouchesEnded = activeDelaysTouchesEnded;
                activeRecognizer = nil;
                activeItems = nil;
                return NO;
            }
        }
    }
    return YES;
}

static BOOL BCXSuppressSystemSwipe(SBFluidSwitcherGestureManager *manager, id gesture) {
    if (activeRecognizer) return YES;
    @try {
        id edgeGesture = [manager.deckGrabberTongue valueForKey:@"_edgePullGestureRecognizer"];
        if ([edgeGesture respondsToSelector:@selector(locationInView:)]) {
            CGPoint point = ((CGPoint (*)(id, SEL, id))objc_msgSend)(edgeGesture, @selector(locationInView:), nil);
            if (BCXClaimsX(point.x)) {
                BCXBeginRecognizer(manager, edgeGesture);
                return YES;
            }
        }
        if ([gesture respondsToSelector:@selector(locationInView:)]) {
            CGPoint point = ((CGPoint (*)(id, SEL, id))objc_msgSend)(gesture, @selector(locationInView:), nil);
            if (BCXClaimsX(point.x)) {
                if ([edgeGesture isKindOfClass:UIPanGestureRecognizer.class]) BCXBeginRecognizer(manager, edgeGesture);
                return YES;
            }
        }
    } @catch (NSException *exception) { }
    return NO;
}

static void BCXInstallOwnRecognizer(SBFluidSwitcherGestureManager *manager, SBGrabberTongue *tongue) {
    @try {
        UIView *container = [tongue valueForKey:@"_tongueContainer"];
        if (![container isKindOfClass:UIView.class] || objc_getAssociatedObject(container, BCXOwnRecognizerKey)) return;
        UIPanGestureRecognizer *recognizer = [[UIPanGestureRecognizer alloc] initWithTarget:manager action:@selector(bcx_handleOwnGesture:)];
        recognizer.maximumNumberOfTouches = 1;
        recognizer.cancelsTouchesInView = YES;
        recognizer.delaysTouchesBegan = YES;
        [container addGestureRecognizer:recognizer];
        objc_setAssociatedObject(container, BCXOwnRecognizerKey, recognizer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } @catch (NSException *exception) { }
}

%hook SBFluidSwitcherGestureManager

- (void)setDeckGrabberTongue:(SBGrabberTongue *)tongue {
    %orig;
    BCXInstallOwnRecognizer(self, tongue);
}

%new
- (void)bcx_handleOwnGesture:(UIPanGestureRecognizer *)recognizer {
    if (recognizer.state == UIGestureRecognizerStateBegan && !BCXBeginRecognizer(self, recognizer)) {
        recognizer.enabled = NO;
        recognizer.enabled = YES;
        return;
    }
    [self bcx_handleGesture:recognizer];
}

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
        CGFloat velocity = -[recognizer velocityInView:nil].y;
        BOOL commit = state == UIGestureRecognizerStateEnded && (distance >= 80 || velocity >= 700);
        if (activeItems.count > 1) BCXFinishPanel(commit);
        else if (commit && activeItems.count == 1) BCXRunPanelItem(activeItems.firstObject);
        [recognizer removeTarget:self action:@selector(bcx_handleGesture:)];
        recognizer.cancelsTouchesInView = activeCancelsTouches;
        recognizer.delaysTouchesBegan = activeDelaysTouchesBegan;
        recognizer.delaysTouchesEnded = activeDelaysTouchesEnded;
        activeRecognizer = nil;
        activeItems = nil;
    }
}

- (void)grabberTongueBeganPulling:(id)arg1 withDistance:(double)arg2 andVelocity:(double)arg3 {
    if (!BCXSuppressSystemSwipe(self, nil)) %orig;
}

- (void)grabberTongueBeganPulling:(id)arg1 withDistance:(double)arg2 andVelocity:(double)arg3 andGesture:(id)arg4 {
    if (!BCXSuppressSystemSwipe(self, arg4)) %orig;
}
%end


%hook SBMainSwitcherViewController
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)recognizer {
    if ([recognizer isKindOfClass:UIPanGestureRecognizer.class]) {
        UIPanGestureRecognizer *pan = (UIPanGestureRecognizer *)recognizer;
        CGPoint velocity = [pan velocityInView:nil];
        if (velocity.y < 0 && -velocity.y > fabs(velocity.x) && BCXClaimsX([pan locationInView:nil].x)) return NO;
    }
    return %orig;
}
%end


%hook SBFluidSwitcherGestureExclusionTrapezoid
- (BOOL)shouldBeginGestureAtStartingPoint:(CGPoint)point velocity:(CGPoint)velocity bounds:(CGRect)bounds {
    BOOL upward = velocity.y < 0 && -velocity.y > fabs(velocity.x);
    if (upward && BCXClaimsX(point.x)) return NO;
    return %orig;
}

- (BOOL)allowHorizontalSwipesOutsideTrapezoid {
    return enable ? YES : %orig;
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
