#import <UIKit/UIKit.h>
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <Preferences/PSSliderTableCell.h>
#import <spawn.h>
#import "../Common.h"
#import "../PanelData.h"

@interface UIImage (BCXSettingsIcon)
+ (UIImage *)imageNamed:(NSString *)name inBundle:(NSBundle *)bundle;
@end

@interface BCXPanelSettingsController : UITableViewController
- (instancetype)initWithZoneKey:(NSString *)zoneKey title:(NSString *)title;
@end

@interface BottomControlXController : PSListController
@end

@implementation BottomControlXController

- (PSSpecifier *)groupNamed:(NSString *)name footer:(NSString *)footer {
    PSSpecifier *item = name
        ? [PSSpecifier preferenceSpecifierNamed:name target:self set:Nil get:Nil detail:Nil cell:PSGroupCell edit:Nil]
        : [PSSpecifier emptyGroupSpecifier];
    if (footer) [item setProperty:footer forKey:@"footerText"];
    return item;
}

- (PSSpecifier *)buttonNamed:(NSString *)name action:(SEL)action {
    PSSpecifier *item = [PSSpecifier preferenceSpecifierNamed:name target:self set:Nil get:Nil
        detail:Nil cell:PSButtonCell edit:Nil];
    item->action = action;
    return item;
}

- (NSArray *)specifiers {
    if (_specifiers) return _specifiers;
    self.title = @"ShortcutPanel";
    NSMutableArray *items = [NSMutableArray array];
    PSSpecifier *item = [PSSpecifier preferenceSpecifierNamed:@"启用插件" target:self
        set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:)
        detail:Nil cell:PSSwitchCell edit:Nil];
    [item setProperty:@"enable" forKey:@"key"];
    [item setProperty:@YES forKey:@"default"];
    [items addObject:item];

    [items addObject:[self groupNamed:@"侧边手柄"
        footer:@"配置动作后显示对应的圆角手柄。按住手柄向屏幕内拖动呼出面板，往回拖可取消。"]];
    [items addObject:[self buttonNamed:@"左侧手柄动作" action:@selector(openLeftSettings)]];
    [items addObject:[self buttonNamed:@"右侧手柄动作" action:@selector(openRightSettings)]];

    [items addObject:[self groupNamed:@"维护" footer:nil]];
    [items addObject:[self buttonNamed:@"重置全部设置" action:@selector(resetSettings)]];
    [items addObject:[self buttonNamed:@"重启 SpringBoard" action:@selector(respring)]];
    _specifiers = [items copy];
    return _specifiers;
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = specifier.properties[@"key"];
    if (!key || !value) return;
    NSMutableDictionary *prefs = [NSMutableDictionary dictionaryWithContentsOfFile:PREF_PATH]
        ?: [[NSDictionary dictionaryWithContentsOfFile:LEGACY_PREF_PATH] mutableCopy]
        ?: [NSMutableDictionary dictionary];
    prefs[key] = value;
    if ([prefs writeToFile:PREF_PATH atomically:YES]) {
        [[NSFileManager defaultManager] removeItemAtPath:LEGACY_PREF_PATH error:nil];
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR(Notify_Preferences), NULL, NULL, YES);
    }
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSString *key = specifier.properties[@"key"];
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:PREF_PATH]
        ?: [NSDictionary dictionaryWithContentsOfFile:LEGACY_PREF_PATH];
    if (prefs[key]) return prefs[key];
    return specifier.properties[@"default"];
}

- (void)openLeftSettings { [self openZone:BCX_LEFT_ITEMS title:@"左侧手柄动作"]; }
- (void)openRightSettings { [self openZone:BCX_RIGHT_ITEMS title:@"右侧手柄动作"]; }
- (void)openZone:(NSString *)key title:(NSString *)title {
    [self.navigationController pushViewController:[[BCXPanelSettingsController alloc] initWithZoneKey:key title:title] animated:YES];
}

- (void)resetSettings {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"重置全部设置？"
        message:@"这会移除已选择的所有动作。" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"重置" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [[NSFileManager defaultManager] removeItemAtPath:PREF_PATH error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:LEGACY_PREF_PATH error:nil];
        [self reloadSpecifiers];
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR(Notify_Preferences), NULL, NULL, YES);
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)respring {
    const char *path = jbroot("/usr/bin/sbreload");
    pid_t pid = 0;
    char *args[] = {(char *)path, NULL};
    extern char **environ;
    posix_spawn(&pid, path, NULL, NULL, args, environ);
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    UIImage *icon = [UIImage imageNamed:@"Icon" inBundle:[NSBundle bundleForClass:self.class]];
    UIImageView *view = [[UIImageView alloc] initWithImage:icon];
    view.contentMode = UIViewContentModeScaleAspectFit;
    view.frame = CGRectMake(0, 0, 28, 28);
    self.navigationItem.titleView = view;
}

@end
