#import "PanelData.h"
#import "Common.h"
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <sqlite3.h>
#import <dlfcn.h>

static NSDictionary *BCXPreferences(void) {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:PREF_PATH]
        ?: [NSDictionary dictionaryWithContentsOfFile:LEGACY_PREF_PATH];
    return [prefs isKindOfClass:NSDictionary.class] ? prefs : @{};
}

static NSMutableDictionary<NSString *, NSArray *> *BCXQuickActionCache(void) {
    static NSMutableDictionary *cache;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ cache = [NSMutableDictionary dictionary]; });
    return cache;
}

void BCXCacheQuickActions(NSString *bundleID, NSArray *actions) {
    if (!bundleID.length || ![actions isKindOfClass:NSArray.class] || !actions.count) return;
    BCXQuickActionCache()[bundleID] = [actions copy];
}

NSArray<NSDictionary *> *BCXPanelItemsForKey(NSString *key) {
    NSDictionary *prefs = BCXPreferences();
    id items = prefs[key];
    if (![items isKindOfClass:NSArray.class]) return @[];
    NSMutableArray *valid = [NSMutableArray array];
    for (id item in items) {
        if ([item isKindOfClass:NSDictionary.class] && [item[@"kind"] isKindOfClass:NSString.class] &&
            [item[@"id"] isKindOfClass:NSString.class] && [item[@"title"] isKindOfClass:NSString.class]) {
            [valid addObject:item];
        }
    }
    return valid;
}

void BCXSavePanelItemsForKey(NSString *key, NSArray<NSDictionary *> *items) {
    NSMutableDictionary *prefs = [BCXPreferences() mutableCopy];
    prefs[key] = items;
    if ([prefs writeToFile:PREF_PATH atomically:YES]) {
        [[NSFileManager defaultManager] removeItemAtPath:LEGACY_PREF_PATH error:nil];
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR(Notify_Preferences), NULL, NULL, YES);
    }
}

CGFloat BCXIconSize(void) {
    CGFloat size = [BCXPreferences()[BCX_ICON_SIZE] doubleValue];
    return size >= 20 ? MIN(64, size) : 40;
}

void BCXSetIconSize(CGFloat size) {
    NSMutableDictionary *prefs = [BCXPreferences() mutableCopy];
    prefs[BCX_ICON_SIZE] = @(MAX(20, MIN(64, size)));
    if ([prefs writeToFile:PREF_PATH atomically:YES]) {
        [[NSFileManager defaultManager] removeItemAtPath:LEGACY_PREF_PATH error:nil];
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR(Notify_Preferences), NULL, NULL, YES);
    }
}

CGFloat BCXHandleHeight(void) {
    CGFloat height = [BCXPreferences()[BCX_HANDLE_HEIGHT] doubleValue];
    return height >= 48 ? MIN(160, height) : 84;
}

CGFloat BCXHandlePosition(void) {
    CGFloat position = [BCXPreferences()[BCX_HANDLE_POSITION] doubleValue];
    return position >= 0.1 ? MIN(0.9, position) : 0.58;
}

NSArray<NSDictionary *> *BCXBuiltinActions(void) {
    return @[
        @{@"kind":@"builtin", @"id":@"control", @"title":@"控制中心", @"symbol":@"switch.2"},
        @{@"kind":@"builtin", @"id":@"notification", @"title":@"通知中心", @"symbol":@"bell"},
        @{@"kind":@"builtin", @"id":@"screenshot", @"title":@"截图", @"symbol":@"camera.viewfinder"},
        @{@"kind":@"builtin", @"id":@"lock", @"title":@"锁屏", @"symbol":@"lock"},
        @{@"kind":@"builtin", @"id":@"respring", @"title":@"重启 SpringBoard", @"symbol":@"arrow.clockwise"},
        @{@"kind":@"builtin", @"id":@"closeapps", @"title":@"关闭后台应用", @"symbol":@"xmark.app"},
        @{@"kind":@"builtin", @"id":@"closeandrespring", @"title":@"关闭后台并重启 SB", @"symbol":@"arrow.triangle.2.circlepath"},
        @{@"kind":@"builtin", @"id":@"userspace", @"title":@"重启用户空间", @"symbol":@"power"},
        @{@"kind":@"builtin", @"id":@"reboot", @"title":@"重启手机", @"symbol":@"restart"},
        @{@"kind":@"builtin", @"id":@"shutdown", @"title":@"关机", @"symbol":@"power.circle"},
        @{@"kind":@"builtin", @"id":@"uicache", @"title":@"刷新应用图标", @"symbol":@"square.grid.2x2"}
    ];
}

NSString *BCXSymbol(NSDictionary *item) {
    NSString *custom = item[@"customSymbol"];
    if ([custom isKindOfClass:NSString.class] && custom.length && [UIImage systemImageNamed:custom]) return custom;
    NSString *kind = item[@"kind"];
    if ([kind isEqualToString:@"shortcut"]) return @"square.stack.3d.up";
    if ([kind isEqualToString:@"quick"]) return @"app.badge";
    return [item[@"symbol"] isKindOfClass:NSString.class] ? item[@"symbol"] : @"square.grid.2x2";
}

UIImage *BCXItemImage(NSDictionary *item, CGFloat size) {
    NSData *data = item[@"customImage"];
    UIImage *image = [data isKindOfClass:NSData.class] ? [UIImage imageWithData:data] : nil;
    if (image) return image;
    return [UIImage systemImageNamed:BCXSymbol(item)
        withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:size weight:UIImageSymbolWeightRegular]];
}

@interface UIImage (BCXApplicationIcon)
+ (UIImage *)_applicationIconImageForBundleIdentifier:(NSString *)bundleID format:(NSInteger)format scale:(CGFloat)scale;
@end

UIImage *BCXApplicationIcon(NSString *bundleID) {
    @try {
        return [UIImage _applicationIconImageForBundleIdentifier:bundleID format:2 scale:UIScreen.mainScreen.scale];
    } @catch (NSException *exception) { return nil; }
}

// Read only: Shortcut storage belongs to the Shortcuts app. Unknown schemas return an empty list.
static sqlite3 *BCXOpenShortcuts(void) {
    sqlite3 *db = NULL;
    if (sqlite3_open_v2("/var/mobile/Library/Shortcuts/Shortcuts.sqlite", &db, SQLITE_OPEN_READONLY, NULL) != SQLITE_OK) {
        if (db) sqlite3_close(db);
        return NULL;
    }
    sqlite3_busy_timeout(db, 250);
    return db;
}

NSArray<NSDictionary *> *BCXShortcuts(void) {
    sqlite3 *db = BCXOpenShortcuts();
    if (!db) return @[];
    sqlite3_stmt *stmt = NULL;
    NSMutableArray *items = [NSMutableArray array];
    if (sqlite3_prepare_v2(db, "SELECT ZWORKFLOWID, ZNAME FROM ZSHORTCUT WHERE ZNAME IS NOT NULL ORDER BY ZNAME COLLATE NOCASE", -1, &stmt, NULL) == SQLITE_OK) {
        while (sqlite3_step(stmt) == SQLITE_ROW) {
            const char *identifier = (const char *)sqlite3_column_text(stmt, 0);
            const char *name = (const char *)sqlite3_column_text(stmt, 1);
            if (identifier && name) {
                NSString *uid = [NSString stringWithUTF8String:identifier];
                NSString *title = [NSString stringWithUTF8String:name];
                if (uid.length && title.length) [items addObject:@{@"kind":@"shortcut", @"id":uid, @"title":title}];
            }
        }
    }
    if (stmt) sqlite3_finalize(stmt);
    sqlite3_close(db);
    return items;
}

NSArray<NSDictionary *> *BCXInstalledApps(void) {
    dlopen("/System/Library/Frameworks/CoreServices.framework/CoreServices", RTLD_LAZY);
    dlopen("/System/Library/Frameworks/MobileCoreServices.framework/MobileCoreServices", RTLD_LAZY);
    Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
    if (![workspaceClass respondsToSelector:@selector(defaultWorkspace)]) return @[];
    id workspace = ((id (*)(id, SEL))objc_msgSend)(workspaceClass, @selector(defaultWorkspace));
    NSMutableArray *proxies = [NSMutableArray array];
    for (NSString *name in @[@"allApplications", @"allInstalledApplications"]) {
        SEL selector = NSSelectorFromString(name);
        id values = [workspace respondsToSelector:selector]
            ? ((id (*)(id, SEL))objc_msgSend)(workspace, selector) : nil;
        if ([values isKindOfClass:NSArray.class]) [proxies addObjectsFromArray:values];
    }
    NSMutableArray *apps = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];
    for (id proxy in proxies) {
        @try {
            NSString *identifier = [proxy respondsToSelector:@selector(applicationIdentifier)]
                ? ((id (*)(id, SEL))objc_msgSend)(proxy, @selector(applicationIdentifier)) : nil;
            NSString *name = [proxy respondsToSelector:@selector(localizedName)]
                ? ((id (*)(id, SEL))objc_msgSend)(proxy, @selector(localizedName)) : nil;
            if (identifier.length && name.length && ![seen containsObject:identifier]) {
                [seen addObject:identifier];
                [apps addObject:@{@"id":identifier, @"title":name}];
            }
        } @catch (NSException *exception) { }
    }
    return [apps sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [a[@"title"] localizedStandardCompare:b[@"title"]];
    }];
}

static id BCXShortcutService(void) {
    dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", RTLD_LAZY);
    Class iconViewClass = NSClassFromString(@"SBIconView");
    if ([iconViewClass respondsToSelector:@selector(applicationShortcutService)]) {
        id service = ((id (*)(id, SEL))objc_msgSend)(iconViewClass, @selector(applicationShortcutService));
        if (service) return service;
    }
    UIApplication *application = UIApplication.sharedApplication;
    SEL current = @selector(shortcutService);
    if ([application respondsToSelector:current]) {
        id service = ((id (*)(id, SEL))objc_msgSend)(application, current);
        if (service) return service;
    }
    Class serviceClass = NSClassFromString(@"SBSApplicationShortcutService");
    @try { return serviceClass ? [[serviceClass alloc] init] : nil; }
    @catch (NSException *exception) { return nil; }
}

static NSArray *BCXArrayFromFetchResult(id result) {
    if ([result respondsToSelector:@selector(composedApplicationShortcutItems)])
        result = ((id (*)(id, SEL))objc_msgSend)(result, @selector(composedApplicationShortcutItems));
    return [result isKindOfClass:NSArray.class] ? result : @[];
}

static NSArray *BCXServiceQuickActions(NSString *bundleID) {
    if (![bundleID isKindOfClass:NSString.class] || !bundleID.length) return @[];
    id service = BCXShortcutService();
    SEL selector = @selector(applicationShortcutItemsOfTypes:forBundleIdentifier:);
    if (![service respondsToSelector:selector]) return @[];
    @try {
        return BCXArrayFromFetchResult(((id (*)(id, SEL, NSUInteger, id))objc_msgSend)(service, selector, 3, bundleID));
    } @catch (NSException *exception) {
        return @[];
    }
}

static NSArray *BCXIconQuickActions(id iconView) {
    if (!iconView) return @[];
    @try {
        SEL fetch = @selector(_fetchApplicationShortcutItemsIfAppropriate);
        if ([iconView respondsToSelector:fetch]) {
            ((void (*)(id, SEL))objc_msgSend)(iconView, fetch);
            SEL effective = @selector(effectiveApplicationShortcutItems);
            NSArray *items = [iconView respondsToSelector:effective]
                ? BCXArrayFromFetchResult(((id (*)(id, SEL))objc_msgSend)(iconView, effective)) : @[];
            if (items.count) return items;
        }
        SEL current = @selector(applicationShortcutItems);
        return [iconView respondsToSelector:current]
            ? BCXArrayFromFetchResult(((id (*)(id, SEL))objc_msgSend)(iconView, current)) : @[];
    } @catch (NSException *exception) { return @[]; }
}

static NSArray *BCXStaticQuickActions(NSString *bundleID) {
    dlopen("/System/Library/Frameworks/MobileCoreServices.framework/MobileCoreServices", RTLD_LAZY);
    Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
    id workspace = [workspaceClass respondsToSelector:@selector(defaultWorkspace)]
        ? ((id (*)(id, SEL))objc_msgSend)(workspaceClass, @selector(defaultWorkspace)) : nil;
    SEL proxySelector = @selector(applicationProxyForIdentifier:);
    if (![workspace respondsToSelector:proxySelector]) return @[];
    @try {
        id proxy = ((id (*)(id, SEL, id))objc_msgSend)(workspace, proxySelector, bundleID);
        SEL urlSelector = @selector(bundleURL);
        NSURL *url = [proxy respondsToSelector:urlSelector]
            ? ((id (*)(id, SEL))objc_msgSend)(proxy, urlSelector) : nil;
        NSArray *entries = [NSBundle bundleWithURL:url].infoDictionary[@"UIApplicationShortcutItems"];
        Class itemClass = NSClassFromString(@"SBSApplicationShortcutItem");
        SEL staticSelector = @selector(_staticApplicationShortcutItemsFromInfoPlistEntry:);
        if (![entries isKindOfClass:NSArray.class] || ![itemClass respondsToSelector:staticSelector]) return @[];
        id result = ((id (*)(id, SEL, id))objc_msgSend)(itemClass, staticSelector, entries);
        return [result isKindOfClass:NSArray.class] ? result : @[];
    } @catch (NSException *exception) { return @[]; }
}

static NSArray *BCXApplicationQuickActions(NSString *bundleID) {
    Class controllerClass = NSClassFromString(@"SBApplicationController");
    id controller = [controllerClass respondsToSelector:@selector(sharedInstance)]
        ? ((id (*)(id, SEL))objc_msgSend)(controllerClass, @selector(sharedInstance)) : nil;
    SEL applicationSelector = @selector(applicationWithBundleIdentifier:);
    if (![controller respondsToSelector:applicationSelector]) return @[];
    @try {
        id application = ((id (*)(id, SEL, id))objc_msgSend)(controller, applicationSelector, bundleID);
        NSMutableArray *items = [NSMutableArray array];
        for (NSString *name in @[@"staticApplicationShortcutItems", @"dynamicApplicationShortcutItems"]) {
            SEL selector = NSSelectorFromString(name);
            NSArray *part = [application respondsToSelector:selector]
                ? ((id (*)(id, SEL))objc_msgSend)(application, selector) : nil;
            if ([part isKindOfClass:NSArray.class]) [items addObjectsFromArray:part];
        }
        return items;
    } @catch (NSException *exception) { return @[]; }
}

static NSArray *BCXRawQuickActions(NSString *bundleID, id iconView) {
    NSMutableArray *actions = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];
    NSArray *cached = BCXQuickActionCache()[bundleID] ?: @[];
    for (NSArray *source in @[cached, BCXApplicationQuickActions(bundleID), BCXIconQuickActions(iconView), BCXServiceQuickActions(bundleID), BCXStaticQuickActions(bundleID)]) {
        for (id action in source) {
            @try {
                SEL selector = @selector(type);
                NSString *type = [action respondsToSelector:selector]
                    ? ((id (*)(id, SEL))objc_msgSend)(action, selector) : nil;
                if ([type isKindOfClass:NSString.class] && type.length && ![seen containsObject:type]) {
                    [seen addObject:type];
                    [actions addObject:action];
                }
            } @catch (NSException *exception) { }
        }
    }
    return actions;
}

static NSArray<NSDictionary *> *BCXQuickActionDictionaries(NSArray *actions, NSString *bundleID) {
    NSMutableArray *items = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];
    for (id action in actions) {
        @try {
            NSString *type = [action respondsToSelector:@selector(type)]
                ? ((id (*)(id, SEL))objc_msgSend)(action, @selector(type)) : nil;
            NSString *title = [action respondsToSelector:@selector(localizedTitle)]
                ? ((id (*)(id, SEL))objc_msgSend)(action, @selector(localizedTitle)) : nil;
            if (type.length && title.length && ![seen containsObject:type]) {
                [seen addObject:type];
                NSMutableDictionary *entry = [@{@"kind":@"quick", @"id":type, @"app":bundleID, @"title":title} mutableCopy];
                SEL userInfoSelector = @selector(userInfo);
                id userInfo = [action respondsToSelector:userInfoSelector]
                    ? ((id (*)(id, SEL))objc_msgSend)(action, userInfoSelector) : nil;
                if ([userInfo isKindOfClass:NSDictionary.class] &&
                    [NSPropertyListSerialization propertyList:userInfo isValidForFormat:NSPropertyListBinaryFormat_v1_0]) {
                    entry[@"userInfo"] = userInfo;
                }
                [items addObject:entry];
            }
        } @catch (NSException *exception) { }
    }
    return items;
}

NSArray<NSDictionary *> *BCXAllQuickActions(void) {
    NSMutableArray *result = [NSMutableArray array];
    for (NSDictionary *app in BCXInstalledApps()) {
        NSString *bundleID = app[@"id"];
        NSMutableArray *raw = [NSMutableArray arrayWithArray:BCXApplicationQuickActions(bundleID)];
        [raw addObjectsFromArray:BCXStaticQuickActions(bundleID)];
        for (NSDictionary *action in BCXQuickActionDictionaries(raw, bundleID)) {
            NSMutableDictionary *entry = [action mutableCopy];
            entry[@"appTitle"] = app[@"title"] ?: bundleID;
            [result addObject:entry];
        }
    }
    return result;
}

NSArray<NSDictionary *> *BCXQuickActionsForIconView(NSString *bundleID, id iconView) {
    return BCXQuickActionDictionaries(BCXRawQuickActions(bundleID, iconView), bundleID);
}

void BCXFetchQuickActions(NSString *bundleID, id iconView, void (^completion)(NSArray<NSDictionary *> *items)) {
    id service = BCXShortcutService();
    SEL fetch = @selector(fetchApplicationShortcutItemsOfTypes:forBundleIdentifier:withCompletionHandler:);
    if (![service respondsToSelector:fetch]) {
        completion(BCXQuickActionsForIconView(bundleID, iconView));
        return;
    }
    @try {
        ((void (*)(id, SEL, NSUInteger, id, id))objc_msgSend)(service, fetch, 3, bundleID, ^(id result) {
            NSArray *fetched = BCXArrayFromFetchResult(result);
            NSMutableArray *all = [fetched mutableCopy];
            for (id action in BCXRawQuickActions(bundleID, iconView)) if (![all containsObject:action]) [all addObject:action];
            NSArray *items = BCXQuickActionDictionaries(all, bundleID);
            dispatch_async(dispatch_get_main_queue(), ^{ completion(items); });
        });
    } @catch (NSException *exception) {
        completion(BCXQuickActionsForIconView(bundleID, iconView));
    }
}

NSArray<NSDictionary *> *BCXQuickActions(NSString *bundleID) {
    return BCXQuickActionsForIconView(bundleID, nil);
}

NSArray<NSDictionary *> *BCXRequestQuickActions(NSString *bundleID) {
    if (![bundleID isKindOfClass:NSString.class] || !bundleID.length) return @[];
    NSString *token = NSUUID.UUID.UUIDString;
    if (![@{@"token":token, @"app":bundleID} writeToFile:QUICK_IPC_PATH atomically:YES]) return BCXQuickActions(bundleID);
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR(Notify_QuickRequest), NULL, NULL, YES);
    for (NSInteger attempt = 0; attempt < 60; attempt++) {
        [NSThread sleepForTimeInterval:0.1];
        NSDictionary *reply = [NSDictionary dictionaryWithContentsOfFile:QUICK_IPC_PATH];
        if ([reply[@"token"] isEqualToString:token] && [reply[@"actions"] isKindOfClass:NSArray.class]) return reply[@"actions"];
    }
    return BCXQuickActions(bundleID);
}

id BCXQuickActionItem(NSString *bundleID, NSString *type, id iconView) {
    for (id action in BCXRawQuickActions(bundleID, iconView)) {
        @try {
            if ([action respondsToSelector:@selector(type)] &&
                [((id (*)(id, SEL))objc_msgSend)(action, @selector(type)) isEqualToString:type]) return action;
        } @catch (NSException *exception) { }
    }
    return nil;
}
