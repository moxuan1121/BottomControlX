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

    [items addObject:[self groupNamed:@"全局上滑手势"
        footer:@"左、中、右三个区域在桌面和应用内通用。竖屏生效；锁屏保留系统解锁手势。选用插件动作或快捷面板时，该区域的系统上滑动作由插件接管。"]];
    NSArray *actions = @[@1, @2, @3, @9, @5, @6, @10, @11];
    NSArray *names = @[@"系统上滑", @"控制中心", @"锁屏", @"通知中心", @"截图", @"静默截图", @"不执行动作", @"快捷面板"];
    [items addObject:[self choiceNamed:@"左侧区域" key:@"BottomLeftGesture" defaultValue:@1 values:actions titles:names]];
    [items addObject:[self choiceNamed:@"中间区域" key:@"BottomCenterGesture" defaultValue:@1 values:actions titles:names]];
    [items addObject:[self choiceNamed:@"右侧区域" key:@"BottomRightGesture" defaultValue:@1 values:actions titles:names]];
    [items addObject:[self buttonNamed:@"快捷面板项目与图标尺寸" action:@selector(openPanelSettings)]];

    [items addObject:[self groupNamed:@"手势范围与灵敏度" footer:@"调整左右区域宽度；中间区域使用剩余宽度。"]];
    [items addObject:[self choiceNamed:@"左侧区域宽度" key:@"leftValue" defaultValue:@0.25
        values:@[@0.0, @0.05, @0.1, @0.15, @0.2, @0.25, @0.3]
        titles:@[@"0%", @"5%", @"10%", @"15%", @"20%", @"25%", @"30%"]]];
    [items addObject:[self choiceNamed:@"右侧区域起点" key:@"rightValue" defaultValue:@0.75
        values:@[@0.7, @0.75, @0.8, @0.85, @0.9, @0.95, @1.0]
        titles:@[@"70%", @"75%", @"80%", @"85%", @"90%", @"95%", @"100%"]]];
    PSSpecifier *sensitivity = [PSSpecifier preferenceSpecifierNamed:@"降低手势灵敏度" target:self
        set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:)
        detail:Nil cell:PSSwitchCell edit:Nil];
    [sensitivity setProperty:@"lowerSensibility" forKey:@"key"];
    [sensitivity setProperty:@NO forKey:@"default"];
    [items addObject:sensitivity];
    PSSpecifier *velocity = [PSSpecifier preferenceSpecifierNamed:@"触发速度阈值" target:self
        set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:)
        detail:Nil cell:PSSliderCell edit:Nil];
    [velocity setProperty:@"velocityValue" forKey:@"key"];
    [velocity setProperty:@150.0 forKey:@"default"];
    [velocity setProperty:@100.0 forKey:@"min"];
    [velocity setProperty:@500.0 forKey:@"max"];
    [velocity setProperty:@YES forKey:@"showValue"];
    [items addObject:velocity];

    [items addObject:[self groupNamed:@"维护" footer:nil]];
    [items addObject:[self buttonNamed:@"重置手势范围与灵敏度" action:@selector(resetSliders)]];
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
    if ([key hasPrefix:@"Bottom"] && [key hasSuffix:@"Gesture"]) {
        NSString *suffix = [key substringFromIndex:@"Bottom".length];
        id home = prefs[[ @"SBBottom" stringByAppendingString:suffix]];
        id app = prefs[[ @"AppBottom" stringByAppendingString:suffix]];
        return ([home integerValue] != 1 ? home : ([app integerValue] != 1 ? app : (home ?: app ?: @1)));
    }
    return specifier.properties[@"default"];
}

- (void)openPanelSettings {
    [self.navigationController pushViewController:[BCXPanelSettingsController new] animated:YES];
}

- (void)resetSliders {
    NSMutableDictionary *prefs = [NSMutableDictionary dictionaryWithContentsOfFile:PREF_PATH] ?: [NSMutableDictionary dictionary];
    for (NSString *key in @[@"leftValue", @"rightValue", @"velocityValue", @"lowerSensibility"]) [prefs removeObjectForKey:key];
    [prefs writeToFile:PREF_PATH atomically:YES];
    [self reloadSpecifiers];
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR(Notify_Preferences), NULL, NULL, YES);
}

- (void)resetSettings {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"重置全部设置？"
        message:@"这会移除手势设置和快捷面板项目。" preferredStyle:UIAlertControllerStyleAlert];
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
