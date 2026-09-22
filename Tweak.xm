#import "Tweak.h"
#import "Common.h"
#import "PanelData.h"
#import "PanelView.h"
#import <spawn.h>
#import <signal.h>
#import <unistd.h>
#import <sys/wait.h>
#import <errno.h>
#import <dlfcn.h>
#import <objc/runtime.h>

static BOOL enable;
static CFAbsoluteTime suppressBreadcrumbUntil;
static void BCXRunPanelItem(NSDictionary *item);
static void BCXCloseBackgroundApps(BOOL includeForeground);

%hook SBDeviceApplicationSceneStatusBarBreadcrumbProvider
+ (BOOL)_shouldAddBreadcrumbToActivatingSceneEntity:(id)entity sceneHandle:(id)handle withTransitionContext:(id)context {
    return CFAbsoluteTimeGetCurrent() < suppressBreadcrumbUntil ? NO : %orig;
}
%end

static void BCXSkipNextBreadcrumb(void) {
    suppressBreadcrumbUntil = CFAbsoluteTimeGetCurrent() + 2.0;
}

static void settingsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:PREF_PATH]
        ?: [NSDictionary dictionaryWithContentsOfFile:LEGACY_PREF_PATH];
    enable = (BOOL)[dict[@"enable"] ? : @YES boolValue];
    dispatch_async(dispatch_get_main_queue(), ^{
        BCXConfigureSideHandles(enable, ^(NSDictionary *item) { BCXRunPanelItem(item); });
    });
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

static void BCXPresentAlert(UIAlertController *alert) {
    UIViewController *root = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class] || scene.activationState != UISceneActivationStateForegroundActive) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if (window.isKeyWindow) { root = window.rootViewController; break; }
        }
        if (root) break;
    }
    if (!root) return;
    while (root.presentedViewController) root = root.presentedViewController;
    [root presentViewController:alert animated:YES completion:nil];
}

static void BCXAlert(NSString *message) {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"快捷面板" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:nil]];
    BCXPresentAlert(alert);
}

static void BCXConfirm(NSString *name, void (^action)(void)) {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:name
        message:[NSString stringWithFormat:@"点击确认将执行%@", name] preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"确认" style:UIAlertActionStyleDestructive
        handler:^(UIAlertAction *item) { action(); }]];
    BCXPresentAlert(alert);
}

static BOOL BCXSpawn(NSString *program, NSString *argument) {
    const char *path = jbroot(program.UTF8String);
    if (access(path, X_OK) != 0) return NO;
    pid_t pid = 0;
    char *argv[] = {(char *)path, (char *)argument.UTF8String, NULL};
    extern char **environ;
    return posix_spawn(&pid, path, NULL, NULL, argv, environ) == 0;
}

static void BCXRebootUserspace(void) {
    static BOOL running = NO;
    if (running) return;
    running = YES;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        // Dopamine roothide's own UI uses jbctl, which carries the reboot entitlement.
        NSArray *paths = @[jbroot(@"/basebin/jbctl"), jbroot(@"/usr/bin/launchctl"),
            jbroot(@"/bin/launchctl"), @"/usr/bin/launchctl", @"/bin/launchctl"];
        NSMutableArray *failures = [NSMutableArray array];
        for (NSString *program in [NSOrderedSet orderedSetWithArray:paths]) {
            const char *path = program.fileSystemRepresentation;
            BOOL jbctl = [program.lastPathComponent isEqualToString:@"jbctl"];
            char *argv[] = {(char *)path, (char *)(jbctl ? "reboot_userspace" : "reboot"),
                jbctl ? NULL : (char *)"userspace", NULL};
            pid_t pid = 0;
            extern char **environ;
            int error = posix_spawn(&pid, path, NULL, NULL, argv, environ);
            if (error == ENOENT || error == ENOTDIR) continue;
            if (error) {
                [failures addObject:[NSString stringWithFormat:@"%@：启动 %d", program, error]];
                continue;
            }
            int status = 0;
            pid_t waited;
            do { waited = waitpid(pid, &status, 0); } while (waited < 0 && errno == EINTR);
            if (waited < 0) {
                [failures addObject:[NSString stringWithFormat:@"%@：读取结果 %d", program, errno]];
                break; // The child may already have requested a reboot; do not issue another.
            }
            if (WIFEXITED(status) && WEXITSTATUS(status) == 0) {
                dispatch_async(dispatch_get_main_queue(), ^{ running = NO; });
                return;
            }
            [failures addObject:[NSString stringWithFormat:@"%@：%@ %d", program,
                WIFEXITED(status) ? @"退出码" : @"终止信号",
                WIFEXITED(status) ? WEXITSTATUS(status) : WTERMSIG(status)]];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            running = NO;
            BCXAlert(failures.count ? [@"用户空间重启失败。\n" stringByAppendingString:[failures componentsJoinedByString:@"\n"]]
                : @"未找到越狱环境的用户空间重启工具。");
        });
    });
}

static BOOL BCXOpenApplication(NSString *bundleID) {
    if (!bundleID.length) return NO;
    id springBoard = UIApplication.sharedApplication;
    SEL launch = @selector(launchApplicationWithIdentifier:suspended:);
    if ([springBoard respondsToSelector:launch]) {
        @try {
            BCXSkipNextBreadcrumb();
            if (((BOOL (*)(id, SEL, id, BOOL))objc_msgSend)(springBoard, launch, bundleID, NO)) return YES;
        } @catch (NSException *exception) { }
    }
    dlopen("/System/Library/Frameworks/CoreServices.framework/CoreServices", RTLD_LAZY);
    dlopen("/System/Library/Frameworks/MobileCoreServices.framework/MobileCoreServices", RTLD_LAZY);
    Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
    SEL shared = @selector(defaultWorkspace);
    SEL open = @selector(openApplicationWithBundleID:);
    if (![workspaceClass respondsToSelector:shared]) return NO;
    id workspace = ((id (*)(id, SEL))objc_msgSend)(workspaceClass, shared);
    if (![workspace respondsToSelector:open]) return NO;
    BCXSkipNextBreadcrumb();
    BOOL opened = ((BOOL (*)(id, SEL, id))objc_msgSend)(workspace, open, bundleID);
    if (!opened) suppressBreadcrumbUntil = 0;
    return opened;
}

static void BCXClearAllBackgroundApps(void) {
    // Leave the foreground scene before deleting its layout; otherwise iOS recreates a blank card.
    id springBoard = UIApplication.sharedApplication;
    SEL home = @selector(_simulateHomeButtonPress);
    if ([springBoard respondsToSelector:home]) ((void (*)(id, SEL))objc_msgSend)(springBoard, home);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.45 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    BCXCloseBackgroundApps(YES);
    Class switcherClass = NSClassFromString(@"SBMainSwitcherViewController");
    id switcher = [switcherClass respondsToSelector:@selector(sharedInstance)]
        ? ((id (*)(id, SEL))objc_msgSend)(switcherClass, @selector(sharedInstance)) : nil;
    SEL recent = @selector(recentAppLayouts);
    SEL remove = @selector(_deleteAppLayoutsMatchingBundleIdentifier:);
    if (![switcher respondsToSelector:recent] || ![switcher respondsToSelector:remove]) return;
    NSArray *layouts = ((id (*)(id, SEL))objc_msgSend)(switcher, recent);
    for (id layout in [layouts copy]) {
        @try {
            NSArray *items = [layout respondsToSelector:@selector(allItems)]
                ? ((id (*)(id, SEL))objc_msgSend)(layout, @selector(allItems)) : nil;
            id first = items.firstObject;
            NSString *bundleID = [first respondsToSelector:@selector(bundleIdentifier)]
                ? ((id (*)(id, SEL))objc_msgSend)(first, @selector(bundleIdentifier)) : nil;
            if (bundleID.length && ![bundleID isEqualToString:@"com.apple.springboard"])
                ((void (*)(id, SEL, id))objc_msgSend)(switcher, remove, bundleID);
        } @catch (NSException *exception) { }
    }
    });
}

static id BCXIconViewForBundleID(NSString *bundleID, BOOL menuProbe) {
    Class controllerClass = NSClassFromString(@"SBIconController");
    if (![controllerClass respondsToSelector:@selector(sharedInstance)]) return nil;
    @try {
        id controller = [controllerClass sharedInstance];
        id manager = [controller respondsToSelector:@selector(iconManager)]
            ? ((id (*)(id, SEL))objc_msgSend)(controller, @selector(iconManager)) : nil;
        id model = [controller respondsToSelector:@selector(model)] ? [controller model] : nil;
        if (!model && [manager respondsToSelector:@selector(iconModel)])
            model = ((id (*)(id, SEL))objc_msgSend)(manager, @selector(iconModel));
        SEL iconSelector = @selector(applicationIconForBundleIdentifier:);
        id icon = [model respondsToSelector:iconSelector]
            ? ((id (*)(id, SEL, id))objc_msgSend)(model, iconSelector, bundleID) : nil;
        SEL mapSelector = @selector(homescreenIconViewMap);
        id map = [controller respondsToSelector:mapSelector]
            ? ((id (*)(id, SEL))objc_msgSend)(controller, mapSelector) : nil;
        SEL viewSelector = @selector(iconViewForIcon:);
        id view = icon && [map respondsToSelector:viewSelector]
            ? ((id (*)(id, SEL, id))objc_msgSend)(map, viewSelector, icon) : nil;
        if (!view && icon && [manager respondsToSelector:@selector(firstIconViewForIcon:)])
            view = ((id (*)(id, SEL, id))objc_msgSend)(manager, @selector(firstIconViewForIcon:), icon);
        if (!menuProbe && view) return view;
        if (!icon) return nil;
        Class viewClass = NSClassFromString(@"SBIconView");
        SEL initializer = @selector(initWithConfigurationOptions:);
        view = [viewClass instancesRespondToSelector:initializer]
            ? ((id (*)(id, SEL, NSUInteger))objc_msgSend)([viewClass alloc], initializer, 0) : [viewClass new];
        if ([view respondsToSelector:@selector(setIcon:)])
            ((void (*)(id, SEL, id))objc_msgSend)(view, @selector(setIcon:), icon);
        if (manager && [view respondsToSelector:@selector(setDelegate:)])
            ((void (*)(id, SEL, id))objc_msgSend)(view, @selector(setDelegate:), manager);
        return view;
    } @catch (NSException *exception) {
        return nil;
    }
}

static void BCXFetchAllQuickActions(void (^completion)(NSArray<NSDictionary *> *items)) {
    NSArray<NSDictionary *> *apps = BCXInstalledApps();
    NSMutableDictionary<NSString *, NSArray *> *resultsByApp = [NSMutableDictionary dictionary];
    dispatch_group_t group = dispatch_group_create();
    __block BOOL finished = NO;
    void (^finish)(void) = ^{
        if (finished) return;
        finished = YES;
        NSMutableArray *result = [NSMutableArray array];
        for (NSDictionary *app in apps) {
            for (NSDictionary *action in resultsByApp[app[@"id"]]) {
                NSMutableDictionary *entry = [action mutableCopy];
                entry[@"appTitle"] = app[@"title"] ?: app[@"id"];
                [result addObject:entry];
            }
        }
        completion(result);
    };
    for (NSDictionary *app in apps) {
        NSString *bundleID = app[@"id"];
        id iconView = BCXIconViewForBundleID(bundleID, YES);
        resultsByApp[bundleID] = BCXQuickActionsForIconView(bundleID, iconView);
        dispatch_group_enter(group);
        BCXFetchQuickActions(bundleID, iconView, ^(NSArray<NSDictionary *> *actions) {
            if (!finished) resultsByApp[bundleID] = actions;
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
        id iconView = BCXIconViewForBundleID(bundleID, YES);
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

static void BCXCloseBackgroundApps(BOOL includeForeground) {
    Class controllerClass = NSClassFromString(@"SBApplicationController");
    id controller = [controllerClass respondsToSelector:@selector(sharedInstance)] ? [controllerClass sharedInstance] : nil;
    SEL runningSelector = @selector(runningApplications);
    if (![controller respondsToSelector:runningSelector]) return;
    id running = ((id (*)(id, SEL))objc_msgSend)(controller, runningSelector);
    if (![running isKindOfClass:NSArray.class]) return;
    for (id app in running) {
        @try {
            SEL internalSelector = @selector(isInternalApplication);
            if ([app respondsToSelector:internalSelector] && ((BOOL (*)(id, SEL))objc_msgSend)(app, internalSelector)) continue;
            SEL stateSelector = @selector(processState);
            id state = [app respondsToSelector:stateSelector]
                ? ((id (*)(id, SEL))objc_msgSend)(app, stateSelector) : nil;
            if (![state respondsToSelector:@selector(pid)] || ![state respondsToSelector:@selector(isForeground)]) continue;
            if (!includeForeground && ((BOOL (*)(id, SEL))objc_msgSend)(state, @selector(isForeground))) continue;
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
        id iconView = BCXIconViewForBundleID(bundleID, NO);
        id action = BCXQuickActionItem(bundleID, identifier, iconView) ?: BCXQuickActionFallback(item);
        if (!action) {
            BCXAlert(@"此应用的快捷操作已不可用，请在设置中重新选择。");
            return;
        }
        BCXSkipNextBreadcrumb();
        if (!BCXActivateQuickAction(action, bundleID, iconView)) {
            suppressBreadcrumbUntil = 0;
            BCXAlert(@"无法打开此应用的快捷操作。");
        }
        return;
    }
    if ([kind isEqualToString:@"app"]) {
        if (!BCXOpenApplication(identifier)) BCXAlert(@"无法打开此应用。");
        return;
    }
    if ([kind isEqualToString:@"url"]) {
        NSURL *url = [NSURL URLWithString:identifier];
        if (!url.scheme.length || [@[@"file", @"javascript", @"data"] containsObject:url.scheme.lowercaseString] ||
            ([@[@"http", @"https"] containsObject:url.scheme.lowercaseString] && !url.host.length)) {
            BCXAlert(@"URL 无效或不受支持。");
            return;
        }
        BCXSkipNextBreadcrumb();
        [UIApplication.sharedApplication openURL:url options:@{} completionHandler:^(BOOL success) {
            if (!success) {
                suppressBreadcrumbUntil = 0;
                BCXAlert(@"无法打开此 URL。请检查目标应用是否已安装。");
            }
        }];
        return;
    }
    if (![kind isEqualToString:@"builtin"]) return;
    if ([identifier isEqualToString:@"control"]) showControlCenter();
    else if ([identifier isEqualToString:@"notification"]) [[%c(SBCoverSheetPresentationManager) sharedInstance] setCoverSheetPresented:YES animated:YES withCompletion:nil];
    else if ([identifier isEqualToString:@"screenshot"]) [(SpringBoard *)UIApplication.sharedApplication takeScreenshot];
    else if ([identifier isEqualToString:@"lock"]) [(SpringBoard *)UIApplication.sharedApplication _simulateLockButtonPress];
    else if ([identifier isEqualToString:@"closeapps"]) BCXCloseBackgroundApps(NO);
    else if ([identifier isEqualToString:@"clearall"]) BCXClearAllBackgroundApps();
    else if ([identifier isEqualToString:@"respring"]) kill(getpid(), SIGTERM);
    else if ([identifier isEqualToString:@"closeandrespring"]) {
        BCXCloseBackgroundApps(NO);
        kill(getpid(), SIGTERM);
    } else if ([identifier isEqualToString:@"userspace"]) {
        BCXConfirm(@"重启用户空间", ^{ BCXRebootUserspace(); });
    } else if ([identifier isEqualToString:@"reboot"]) {
        BCXConfirm(@"重启手机", ^{ if (!BCXPowerAction(YES)) BCXAlert(@"无法重启手机。"); });
    } else if ([identifier isEqualToString:@"shutdown"]) {
        if (!BCXPowerAction(NO)) BCXAlert(@"无法关闭手机。");
    } else if ([identifier isEqualToString:@"uicache"]) {
        if (!BCXSpawn(@"/usr/bin/uicache", @"-a")) BCXAlert(@"无法启动图标刷新工具。");
    }
}

static NSString *BCXBundleIDForIconView(id iconView) {
    @try {
        for (NSString *name in @[@"applicationBundleIdentifierForShortcuts", @"applicationBundleIdentifier", @"bundleIdentifier"]) {
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
    // Other tweaks may replace the setter argument inside %orig; read the stored result.
    SEL getter = @selector(applicationShortcutItems);
    NSArray *stored = [(id)self respondsToSelector:getter]
        ? ((id (*)(id, SEL))objc_msgSend)(self, getter) : items;
    BCXCacheQuickActions(BCXBundleIDForIconView(self), stored);
}
- (NSArray *)effectiveApplicationShortcutItems {
    NSArray *items = %orig;
    BCXCacheQuickActions(BCXBundleIDForIconView(self), items);
    return items;
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
