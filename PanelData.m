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
    // A later application-only fetch must not erase items captured from the full icon menu.
    NSMutableDictionary *merged = [NSMutableDictionary dictionary];
    NSMutableArray *order = [NSMutableArray array];
    for (NSArray *source in @[BCXQuickActionCache()[bundleID] ?: @[], actions]) {
        for (id item in source) {
            if (![item respondsToSelector:@selector(type)]) continue;
            NSString *type = ((id (*)(id, SEL))objc_msgSend)(item, @selector(type));
            if (![type isKindOfClass:NSString.class] || !type.length) continue;
            if (!merged[type]) [order addObject:type];
            merged[type] = item;
        }
    }
    NSMutableArray *result = [NSMutableArray array];
    for (NSString *type in order) [result addObject:merged[type]];
    BCXQuickActionCache()[bundleID] = result;
}

NSArray<NSDictionary *> *BCXPanelItemsForKey(NSString *key) {
    NSDictionary *prefs = BCXPreferences();
    id items = prefs[key];
    if (!items && [key isEqualToString:BCX_LEFT_ITEMS]) items = prefs[BCX_RIGHT_ITEMS];
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

NSArray<NSDictionary *> *BCXHandleItems(void) {
    return BCXPanelItemsForKey(BCX_LEFT_ITEMS);
}

BOOL BCXHandleOnRight(void) {
    NSDictionary *prefs = BCXPreferences();
    if (prefs[BCX_HANDLE_SIDE]) return [prefs[BCX_HANDLE_SIDE] isEqualToString:@"right"];
    return !prefs[BCX_LEFT_ITEMS] && [prefs[BCX_RIGHT_ITEMS] isKindOfClass:NSArray.class];
}

CGFloat BCXHandleHeight(void) {
    CGFloat height = [BCXPreferences()[BCX_HANDLE_HEIGHT] doubleValue];
    return height >= 48 ? MIN(160, height) : 84;
}

CGFloat BCXHandlePosition(void) {
    CGFloat position = [BCXPreferences()[BCX_HANDLE_POSITION] doubleValue];
    return position >= 0.1 ? MIN(0.9, position) : 0.58;
}

CGFloat BCXHandleIndicatorPosition(void) {
    id value = BCXPreferences()[BCX_HANDLE_INDICATOR_POSITION];
    return value ? MAX(-6, MIN(6, [value doubleValue])) : 2;
}

CGFloat BCXHandleShadowWidth(void) {
    CGFloat width = [BCXPreferences()[BCX_HANDLE_SHADOW_WIDTH] doubleValue];
    return width >= 8 ? MIN(30, width) : 14;
}

CGFloat BCXHandleShadowPosition(void) {
    id value = BCXPreferences()[BCX_HANDLE_SHADOW_POSITION];
    return value ? MAX(-6, MIN(8, [value doubleValue])) : -1;
}

CGFloat BCXPanelMinimumWidth(void) {
    CGFloat width = [BCXPreferences()[BCX_PANEL_MIN_WIDTH] doubleValue];
    return width >= 40 ? MIN(220, width) : 104;
}

CGFloat BCXHandleTriggerDistance(void) {
    CGFloat distance = [BCXPreferences()[BCX_HANDLE_TRIGGER_DISTANCE] doubleValue];
    return distance >= 10 ? MIN(120, distance) : 40;
}

CGFloat BCXHandleFastDistance(void) {
    id value = BCXPreferences()[BCX_HANDLE_FAST_DISTANCE];
    CGFloat distance = [value doubleValue];
    return value && distance >= 10 ? MIN(120, distance) : BCXHandleTriggerDistance();
}

CGFloat BCXHandleFastVelocity(void) {
    CGFloat velocity = [BCXPreferences()[BCX_HANDLE_FAST_VELOCITY] doubleValue];
    return velocity >= 300 ? MIN(1800, velocity) : 600;
}

NSArray<NSDictionary *> *BCXBuiltinActions(void) {
    return @[
        @{@"kind":@"builtin", @"id":@"control", @"title":@"控制中心", @"symbol":@"switch.2"},
        @{@"kind":@"builtin", @"id":@"notification", @"title":@"通知中心", @"symbol":@"bell"},
        @{@"kind":@"builtin", @"id":@"screenshot", @"title":@"截图", @"symbol":@"camera.viewfinder"},
        @{@"kind":@"builtin", @"id":@"copyshot", @"title":@"截图仅复制", @"symbol":@"doc.on.clipboard"},
        @{@"kind":@"builtin", @"id":@"lock", @"title":@"锁屏", @"symbol":@"lock"},
        @{@"kind":@"builtin", @"id":@"respring", @"title":@"重启 SpringBoard", @"symbol":@"arrow.clockwise"},
        @{@"kind":@"builtin", @"id":@"closeapps", @"title":@"关闭后台应用", @"symbol":@"xmark.app"},
        @{@"kind":@"builtin", @"id":@"clearall", @"title":@"清理全部应用后台", @"symbol":@"square.stack.3d.up.slash"},
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
    if ([kind isEqualToString:@"app"]) return @"app";
    if ([kind isEqualToString:@"url"]) return @"link";
    return [item[@"symbol"] isKindOfClass:NSString.class] ? item[@"symbol"] : @"square.grid.2x2";
}

UIImage *BCXItemImage(NSDictionary *item, CGFloat size) {
    NSData *data = item[@"customImage"];
    UIImage *image = [data isKindOfClass:NSData.class] ? [UIImage imageWithData:data] : nil;
    if (image) return image;
    if ([item[@"kind"] isEqualToString:@"app"]) return BCXApplicationIcon(item[@"id"]);
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
    const char *query = "SELECT s.ZWORKFLOWID, s.ZNAME FROM ZSHORTCUT s "
        "WHERE s.ZNAME IS NOT NULL AND NOT EXISTS "
        "(SELECT 1 FROM ZTRIGGER t WHERE t.ZSHORTCUT = s.Z_PK) "
        "ORDER BY s.ZNAME COLLATE NOCASE";
    if (sqlite3_prepare_v2(db, query, -1, &stmt, NULL) == SQLITE_OK) {
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
        if ([iconView respondsToSelector:fetch]) ((void (*)(id, SEL))objc_msgSend)(iconView, fetch);
        NSMutableArray *items = [NSMutableArray array];
        for (NSString *name in @[@"effectiveApplicationShortcutItems", @"applicationShortcutItems"]) {
            SEL selector = NSSelectorFromString(name);
            if ([iconView respondsToSelector:selector])
                [items addObjectsFromArray:BCXArrayFromFetchResult(((id (*)(id, SEL))objc_msgSend)(iconView, selector))];
        }
        return items;
    } @catch (NSException *exception) { return @[]; }
}

static NSArray *BCXStaticQuickActions(NSString *bundleID) {
    dlopen("/System/Library/Frameworks/MobileCoreServices.framework/MobileCoreServices", RTLD_LAZY);
    Class proxyClass = NSClassFromString(@"LSApplicationProxy");
    SEL proxySelector = @selector(applicationProxyForIdentifier:);
    if (![proxyClass respondsToSelector:proxySelector]) return @[];
    @try {
        id proxy = ((id (*)(id, SEL, id))objc_msgSend)(proxyClass, proxySelector, bundleID);
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

static NSString *BCXLocalizedQuickActionTitle(NSString *bundleID, NSString *type, NSString *fallback) {
    if (!bundleID.length || !type.length) return fallback;
    @try {
    Class proxyClass = NSClassFromString(@"LSApplicationProxy");
    SEL proxySelector = @selector(applicationProxyForIdentifier:);
    if (![proxyClass respondsToSelector:proxySelector]) return fallback;
    id proxy = ((id (*)(id, SEL, id))objc_msgSend)(proxyClass, proxySelector, bundleID);
    NSURL *url = [proxy respondsToSelector:@selector(bundleURL)]
        ? ((id (*)(id, SEL))objc_msgSend)(proxy, @selector(bundleURL)) : nil;
    NSBundle *bundle = url ? [NSBundle bundleWithURL:url] : nil;
    id entries = bundle.infoDictionary[@"UIApplicationShortcutItems"];
    if (![entries isKindOfClass:NSArray.class]) return fallback;
    for (id entry in entries) {
        if (![entry isKindOfClass:NSDictionary.class]) continue;
        if (![entry[@"UIApplicationShortcutItemType"] isEqualToString:type]) continue;
        NSString *key = entry[@"UIApplicationShortcutItemTitle"];
        if (![key isKindOfClass:NSString.class] || !key.length) break;
        NSString *title = [bundle localizedStringForKey:key value:key table:@"InfoPlist"];
        return title.length ? title : fallback;
    }
    } @catch (NSException *exception) { return fallback; }
    return fallback;
}

static NSArray *BCXRawQuickActions(NSString *bundleID, id iconView) {
    NSMutableArray *actions = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];
    NSArray *cached = BCXQuickActionCache()[bundleID] ?: @[];
    for (NSArray *source in @[BCXIconQuickActions(iconView), cached, BCXApplicationQuickActions(bundleID), BCXServiceQuickActions(bundleID), BCXStaticQuickActions(bundleID)]) {
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
            if (type.length) title = BCXLocalizedQuickActionTitle(bundleID, type, title);
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
    // AppData and HomeScreenQuickActions build extra menu items in this setter.
    // The caller supplies a detached probe view, so the visible Home Screen is not changed.
    @try {
        SEL setter = @selector(setApplicationShortcutItems:);
        if ([iconView respondsToSelector:setter]) {
            NSMutableArray *proposed = [NSMutableArray arrayWithArray:BCXApplicationQuickActions(bundleID)];
            [proposed addObjectsFromArray:BCXServiceQuickActions(bundleID)];
            [proposed addObjectsFromArray:BCXStaticQuickActions(bundleID)];
            id delegate = [iconView respondsToSelector:@selector(shortcutsDelegate)]
                ? ((id (*)(id, SEL))objc_msgSend)(iconView, @selector(shortcutsDelegate)) : nil;
            SEL compose = @selector(iconView:applicationShortcutItemsWithProposedItems:);
            NSArray *composed = [delegate respondsToSelector:compose]
                ? BCXArrayFromFetchResult(((id (*)(id, SEL, id, id))objc_msgSend)(delegate, compose, iconView, proposed)) : proposed;
            ((void (*)(id, SEL, id))objc_msgSend)(iconView, setter, composed);
            BCXCacheQuickActions(bundleID, BCXIconQuickActions(iconView));
        }
    } @catch (NSException *exception) { }
    id service = BCXShortcutService();
    SEL fetch = @selector(fetchApplicationShortcutItemsOfTypes:forBundleIdentifier:withCompletionHandler:);
    if (![service respondsToSelector:fetch]) {
        completion(BCXQuickActionsForIconView(bundleID, iconView));
        return;
    }
    @try {
        ((void (*)(id, SEL, NSUInteger, id, id))objc_msgSend)(service, fetch, 3, bundleID, ^(id result) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSMutableArray *all = [BCXRawQuickActions(bundleID, iconView) mutableCopy];
                [all addObjectsFromArray:BCXArrayFromFetchResult(result)];
                completion(BCXQuickActionDictionaries(all, bundleID));
            });
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
