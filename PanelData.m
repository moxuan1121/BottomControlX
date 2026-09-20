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
    id items = BCXPreferences()[BCX_PANEL_ITEMS];
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
    NSMutableDictionary *prefs = [BCXPreferences() mutableCopy];
    prefs[BCX_PANEL_ITEMS] = items;
    if ([prefs writeToFile:PREF_PATH atomically:YES]) {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR(Notify_Preferences), NULL, NULL, YES);
    }
}

NSInteger BCXIconSize(void) {
    NSInteger size = [BCXPreferences()[BCX_ICON_SIZE] integerValue];
    return MAX(0, MIN(2, size));
}

void BCXSetIconSize(NSInteger size) {
    NSMutableDictionary *prefs = [BCXPreferences() mutableCopy];
    prefs[BCX_ICON_SIZE] = @(MAX(0, MIN(2, size)));
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
    NSString *kind = item[@"kind"];
    if ([kind isEqualToString:@"shortcut"]) return @"square.stack.3d.up";
    if ([kind isEqualToString:@"quick"]) return @"app.badge";
    return [item[@"symbol"] isKindOfClass:NSString.class] ? item[@"symbol"] : @"square.grid.2x2";
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

NSString *BCXShortcutName(NSString *identifier) {
    if (![identifier isKindOfClass:NSString.class] || !identifier.length) return nil;
    sqlite3 *db = BCXOpenShortcuts();
    if (!db) return nil;
    sqlite3_stmt *stmt = NULL;
    NSString *name = nil;
    if (sqlite3_prepare_v2(db, "SELECT ZNAME FROM ZSHORTCUT WHERE ZWORKFLOWID = ? LIMIT 1", -1, &stmt, NULL) == SQLITE_OK) {
        sqlite3_bind_text(stmt, 1, identifier.UTF8String, -1, SQLITE_TRANSIENT);
        if (sqlite3_step(stmt) == SQLITE_ROW) {
            const char *value = (const char *)sqlite3_column_text(stmt, 0);
            if (value) name = [NSString stringWithUTF8String:value];
        }
    }
    if (stmt) sqlite3_finalize(stmt);
    sqlite3_close(db);
    return name;
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
            NSString *identifier = [proxy applicationIdentifier];
            NSString *name = [proxy localizedName];
            if (identifier.length && name.length) [apps addObject:@{@"id":identifier, @"title":name}];
        } @catch (NSException *exception) { }
    }
    return [apps sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [a[@"title"] localizedStandardCompare:b[@"title"]];
    }];
}

static id BCXShortcutService(void) {
    dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", RTLD_LAZY);
    Class serviceClass = NSClassFromString(@"SBSApplicationShortcutService");
    @try { return serviceClass ? [[serviceClass alloc] init] : nil; }
    @catch (NSException *exception) { return nil; }
}

static NSArray *BCXRawQuickActions(NSString *bundleID) {
    if (![bundleID isKindOfClass:NSString.class] || !bundleID.length) return @[];
    id service = BCXShortcutService();
    SEL selector = @selector(applicationShortcutItemsOfTypes:forBundleIdentifier:);
    if (![service respondsToSelector:selector]) return @[];
    @try {
        id result = ((id (*)(id, SEL, NSUInteger, id))objc_msgSend)(service, selector, NSUIntegerMax, bundleID);
        if ([result respondsToSelector:@selector(composedApplicationShortcutItems)]) result = [result composedApplicationShortcutItems];
        return [result isKindOfClass:NSArray.class] ? result : @[];
    } @catch (NSException *exception) {
        return @[];
    }
}

NSArray<NSDictionary *> *BCXQuickActions(NSString *bundleID) {
    NSMutableArray *items = [NSMutableArray array];
    for (id action in BCXRawQuickActions(bundleID)) {
        @try {
            NSString *type = [action type];
            NSString *title = [action localizedTitle];
            if (type.length && title.length) [items addObject:@{@"kind":@"quick", @"id":type, @"app":bundleID, @"title":title}];
        } @catch (NSException *exception) { }
    }
    return items;
}

id BCXQuickActionItem(NSString *bundleID, NSString *type) {
    for (id action in BCXRawQuickActions(bundleID)) {
        @try {
            if ([[action type] isEqualToString:type]) return action;
        } @catch (NSException *exception) { }
    }
    return nil;
}
