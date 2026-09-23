#import <UIKit/UIKit.h>
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <spawn.h>
#import "BCXSliderCell.h"
#import "../Common.h"
#import "../PanelData.h"

@interface BCXPanelSettingsController : PSViewController
@end

@interface BottomControlXController : PSListController
- (PSSpecifier *)sliderForKey:(NSString *)key defaultValue:(CGFloat)defaultValue minimum:(CGFloat)minimum maximum:(CGFloat)maximum;
- (PSSpecifier *)groupNamed:(NSString *)name footer:(NSString *)footer;
- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier;
- (id)readPreferenceValue:(PSSpecifier *)specifier;
@end

@interface BCXHandleAppearanceController : BottomControlXController
@end

@implementation BottomControlXController

- (PSSpecifier *)sliderForKey:(NSString *)key defaultValue:(CGFloat)defaultValue minimum:(CGFloat)minimum maximum:(CGFloat)maximum {
    PSSpecifier *item = [PSSpecifier preferenceSpecifierNamed:nil target:self
        set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:)
        detail:Nil cell:PSStaticTextCell edit:Nil];
    [item setProperty:key forKey:@"key"];
    [item setProperty:@(defaultValue) forKey:@"default"];
    [item setProperty:@(minimum) forKey:@"min"];
    [item setProperty:@(maximum) forKey:@"max"];
    [item setProperty:@YES forKey:@"showValue"];
    [item setProperty:@(0.01) forKey:@"increment"];
    [item setProperty:BCXSliderCell.class forKey:@"cellClass"];
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
    self.title = @"ShortcutPanel";
    NSMutableArray *items = [NSMutableArray array];
    PSSpecifier *item = [PSSpecifier preferenceSpecifierNamed:@"启用插件" target:self
        set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:)
        detail:Nil cell:PSSwitchCell edit:Nil];
    [item setProperty:@"enable" forKey:@"key"];
    [item setProperty:@YES forKey:@"default"];
    [items addObject:item];

    [items addObject:[self groupNamed:@"侧边手柄"
        footer:@"选择显示的一侧，按住手柄向屏幕内拖动呼出面板，往回拖可取消。"]];
    [items addObject:[PSSpecifier preferenceSpecifierNamed:@"手柄位置" target:self set:Nil get:Nil
        detail:Nil cell:PSButtonCell edit:Nil]];
    PSSpecifier *link = [PSSpecifier preferenceSpecifierNamed:@"手柄动作" target:self set:Nil get:Nil
        detail:BCXPanelSettingsController.class cell:PSLinkCell edit:Nil];
    [link setProperty:BCX_LEFT_ITEMS forKey:@"zoneKey"];
    [link setProperty:BCX_LEFT_ITEMS forKey:@"id"];
    [items addObject:link];
    [items addObject:[PSSpecifier preferenceSpecifierNamed:@"手柄外观" target:self set:Nil get:Nil
        detail:BCXHandleAppearanceController.class cell:PSLinkCell edit:Nil]];

    [items addObject:[self groupNamed:@"手势触发距离" footer:@"向屏幕内滑动达到设定距离即可呼出；快速滑动仍可触发。"]];
    [items addObject:[self sliderForKey:BCX_HANDLE_TRIGGER_DISTANCE defaultValue:40 minimum:10 maximum:120]];

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

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:path];
    if ([cell.textLabel.text isEqualToString:@"手柄位置"]) {
        cell.userInteractionEnabled = YES;
        cell.contentView.userInteractionEnabled = YES;
        cell.textLabel.textColor = UIColor.blackColor;
        UISegmentedControl *side = [[UISegmentedControl alloc] initWithItems:@[@"左", @"右"]];
        side.frame = CGRectMake(0, 0, 120, 34);
        side.userInteractionEnabled = YES;
        side.selectedSegmentIndex = BCXHandleOnRight() ? 1 : 0;
        [side addTarget:self action:@selector(handleSideChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = side;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    return cell;
}

- (void)handleSideChanged:(UISegmentedControl *)control {
    PSSpecifier *specifier = [PSSpecifier preferenceSpecifierNamed:nil target:self set:Nil get:Nil detail:Nil cell:PSStaticTextCell edit:Nil];
    [specifier setProperty:BCX_HANDLE_SIDE forKey:@"key"];
    [self setPreferenceValue:control.selectedSegmentIndex == 1 ? @"right" : @"left" specifier:specifier];
    control.selectedSegmentIndex = BCXHandleOnRight() ? 1 : 0;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationItem.titleView = nil;
    self.title = @"ShortcutPanel";
}

@end

@implementation BCXHandleAppearanceController

- (NSArray *)specifiers {
    if (_specifiers) return _specifiers;
    self.title = @"手柄外观";
    _specifiers = [@[
        [self groupNamed:@"手柄高度" footer:@"调节圆角手柄的可见高度。"],
        [self sliderForKey:BCX_HANDLE_HEIGHT defaultValue:84 minimum:48 maximum:160],
        [self groupNamed:@"垂直位置" footer:@"数值表示手柄中心在屏幕高度中的位置。"],
        [self sliderForKey:BCX_HANDLE_POSITION defaultValue:0.58 minimum:0.10 maximum:0.90],
        [self groupNamed:@"白条位置" footer:@"正数向屏幕内侧移动，负数向屏幕边缘移动。"],
        [self sliderForKey:BCX_HANDLE_INDICATOR_POSITION defaultValue:2 minimum:-6 maximum:6],
        [self groupNamed:@"阴影宽度" footer:@"调节手柄深色背景的宽度。"],
        [self sliderForKey:BCX_HANDLE_SHADOW_WIDTH defaultValue:14 minimum:8 maximum:30],
        [self groupNamed:@"阴影位置" footer:@"正数向屏幕内侧移动，负数向屏幕外侧延伸。"],
        [self sliderForKey:BCX_HANDLE_SHADOW_POSITION defaultValue:-1 minimum:-6 maximum:8],
        [self groupNamed:@"面板最小宽度" footer:@"长动作名称仍会自动拓宽面板。"],
        [self sliderForKey:BCX_PANEL_MIN_WIDTH defaultValue:104 minimum:40 maximum:220]
    ] mutableCopy];
    return _specifiers;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationItem.titleView = nil;
    self.title = @"手柄外观";
}

@end
