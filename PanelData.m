#import "PanelData.h"
#import "Common.h"
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <sqlite3.h>
#import <dlfcn.h>

static NSDictionary *BCXPreferences(void) {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:PREF_PATH];
    return [prefs isKindOfClass:NSDictionary.class] ? prefs : @{};
}

NSArray<NSDictionary *> *BCXPanelItems(void) {
    return BCXPanelItemsForKey(BCX_CENTER_ITEMS);
}

NSArray<NSDictionary *> *BCXPanelItemsForKey(NSString *key) {
    NSDictionary *prefs = BCXPreferences();
    id items = prefs[key];
    if (!items && [key isEqualToString:BCX_CENTER_ITEMS]) items = prefs[BCX_PANEL_ITEMS];
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

void BCXSavePanelItems(NSArray<NSDictionary *> *items) {
    BCXSavePanelItemsForKey(BCX_CENTER_ITEMS, items);
}

void BCXSavePanelItemsForKey(NSString *key, NSArray<NSDictionary *> *items) {
    NSMutableDictionary *prefs = [BCXPreferences() mutableCopy];
    prefs[key] = items;
    if ([prefs writeToFile:PREF_PATH atomically:YES]) {
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
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR(Notify_Preferences), NULL, NULL, YES);
    }
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
    if (![workspace respondsToSelector:@selector(allApplications)]) return @[];
    id proxies = ((id (*)(id, SEL))objc_msgSend)(workspace, @selector(allApplications));
    if (![proxies isKindOfClass:NSArray.class]) return @[];
    NSMutableArray *apps = [NSMutableArray array];
    for (id proxy in proxies) {
        @try {
            NSString *identifier = [proxy respondsToSelector:@selector(applicationIdentifier)]
                ? ((id (*)(id, SEL))objc_msgSend)(proxy, @selector(applicationIdentifier)) : nil;
            NSString *name = [proxy respondsToSelector:@selector(localizedName)]
                ? ((id (*)(id, SEL))objc_msgSend)(proxy, @selector(localizedName)) : nil;
            if (identifier.length && name.length) [apps addObject:@{@"id":identifier, @"title":name}];
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

static NSArray *BCXRawQuickActions(NSString *bundleID, id iconView) {
    NSMutableArray *actions = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];
    for (NSArray *source in @[BCXIconQuickActions(iconView), BCXServiceQuickActions(bundleID), BCXStaticQuickActions(bundleID)]) {
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

NSArray<NSDictionary *> *BCXQuickActionsForIconView(NSString *bundleID, id iconView) {
    NSMutableArray *items = [NSMutableArray array];
    for (id action in BCXRawQuickActions(bundleID, iconView)) {
        @try {
            NSString *type = [action respondsToSelector:@selector(type)]
                ? ((id (*)(id, SEL))objc_msgSend)(action, @selector(type)) : nil;
            NSString *title = [action respondsToSelector:@selector(localizedTitle)]
                ? ((id (*)(id, SEL))objc_msgSend)(action, @selector(localizedTitle)) : nil;
            if (type.length && title.length) [items addObject:@{@"kind":@"quick", @"id":type, @"app":bundleID, @"title":title}];
        } @catch (NSException *exception) { }
    }
    return items;
}

NSArray<NSDictionary *> *BCXQuickActions(NSString *bundleID) {
    return BCXQuickActionsForIconView(bundleID, nil);
}

NSArray<NSDictionary *> *BCXRequestQuickActions(NSString *bundleID) {
    if (![bundleID isKindOfClass:NSString.class] || !bundleID.length) return @[];
    NSString *token = NSUUID.UUID.UUIDString;
    if (![@{@"token":token, @"app":bundleID} writeToFile:QUICK_IPC_PATH atomically:YES]) return BCXQuickActions(bundleID);
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR(Notify_QuickRequest), NULL, NULL, YES);
    for (NSInteger attempt = 0; attempt < 20; attempt++) {
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
