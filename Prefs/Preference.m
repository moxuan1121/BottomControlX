#import <UIKit/UIKit.h>
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <Preferences/PSListItemsController.h>
#import <Preferences/PSSliderTableCell.h>
#import <SafariServices/SafariServices.h>
#import <spawn.h>
#import "../Common.h"
#import "../PanelData.h"

@interface PSSpecifier (BCXChoices)
- (void)setValues:(NSArray *)values titles:(NSArray *)titles;
@end

@interface UIImage (BCXSettingsIcon)
+ (UIImage *)imageNamed:(NSString *)name inBundle:(NSBundle *)bundle;
@end

@interface BCXPanelSettingsController : UITableViewController
@end

@interface BottomControlXController : PSListController
@end

@implementation BottomControlXController

- (PSSpecifier *)choiceNamed:(NSString *)name key:(NSString *)key defaultValue:(id)defaultValue values:(NSArray *)values titles:(NSArray *)titles {
    PSSpecifier *item = [PSSpecifier preferenceSpecifierNamed:name target:self
        set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:)
        detail:PSListItemsController.class cell:PSLinkListCell edit:Nil];
    [item setProperty:key forKey:@"key"];
    [item setProperty:defaultValue forKey:@"default"];
    [item setValues:values titles:titles];
    return item;
}

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
    self.title = @"BottomControlX";
    NSMutableArray *items = [NSMutableArray array];
    PSSpecifier *item = [PSSpecifier preferenceSpecifierNamed:@"启用插件" target:self
        set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:)
        detail:Nil cell:PSSwitchCell edit:Nil];
    [item setProperty:@"enable" forKey:@"key"];
    [item setProperty:@YES forKey:@"default"];
    [items addObject:item];

    [items addObject:[self groupNamed:@"全局上滑动作"
        footer:@"竖屏解锁后，从屏幕底部任意位置上滑。只选一项时直接运行；选两项或更多时显示快捷面板。向下划回可取消。没有选择项目时使用系统上滑手势。"]];
    [items addObject:[self buttonNamed:@"选择与排序动作" action:@selector(openPanelSettings)]];

    [items addObject:[self groupNamed:@"维护" footer:nil]];
    [items addObject:[self buttonNamed:@"重置全部设置" action:@selector(resetSettings)]];
    [items addObject:[self buttonNamed:@"重启 SpringBoard" action:@selector(respring)]];
    [items addObject:[self buttonNamed:@"作者的其他插件" action:@selector(openDonation)]];
    [items addObject:[self groupNamed:nil footer:CREDITS]];
    _specifiers = [items copy];
    return _specifiers;
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = specifier.properties[@"key"];
    if (!key || !value) return;
    NSMutableDictionary *prefs = [NSMutableDictionary dictionaryWithContentsOfFile:PREF_PATH] ?: [NSMutableDictionary dictionary];
    prefs[key] = value;
    if ([prefs writeToFile:PREF_PATH atomically:YES])
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR(Notify_Preferences), NULL, NULL, YES);
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSString *key = specifier.properties[@"key"];
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:PREF_PATH];
    if (prefs[key]) return prefs[key];
    return specifier.properties[@"default"];
}

- (void)openPanelSettings {
    [self.navigationController pushViewController:[BCXPanelSettingsController new] animated:YES];
}

- (void)resetSettings {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"重置全部设置？"
        message:@"这会移除已选择的所有动作。" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"重置" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [[NSFileManager defaultManager] removeItemAtPath:PREF_PATH error:nil];
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

- (void)openDonation {
    SFSafariViewController *browser = [[SFSafariViewController alloc] initWithURL:
        [NSURL URLWithString:@"https://cydia.ichitaso.com/donation.html"]];
    [self presentViewController:browser animated:YES completion:nil];
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
