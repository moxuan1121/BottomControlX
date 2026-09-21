#import <UIKit/UIKit.h>
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <Preferences/PSSliderTableCell.h>
#import <spawn.h>
#import <objc/runtime.h>
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

static const void *BCXSliderLabelKey = &BCXSliderLabelKey;
static const void *BCXSliderSpecifierKey = &BCXSliderSpecifierKey;

static void BCXCollectViews(UIView *view, Class type, NSMutableArray *result) {
    if ([view isKindOfClass:type]) [result addObject:view];
    for (UIView *child in view.subviews) BCXCollectViews(child, type, result);
}

static NSString *BCXDecimal(CGFloat value) {
    return [NSString stringWithFormat:@"%.2f", round(value * 100) / 100];
}

@implementation BottomControlXController

- (PSSpecifier *)sliderForKey:(NSString *)key defaultValue:(CGFloat)defaultValue minimum:(CGFloat)minimum maximum:(CGFloat)maximum {
    PSSpecifier *item = [PSSpecifier preferenceSpecifierNamed:nil target:self
        set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:)
        detail:Nil cell:PSSliderCell edit:Nil];
    [item setProperty:key forKey:@"key"];
    [item setProperty:@(defaultValue) forKey:@"default"];
    [item setProperty:@(minimum) forKey:@"min"];
    [item setProperty:@(maximum) forKey:@"max"];
    [item setProperty:@YES forKey:@"showValue"];
    [item setProperty:@(0.01) forKey:@"increment"];
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
        footer:@"配置动作后显示对应的圆角手柄。按住手柄向屏幕内拖动呼出面板，往回拖可取消。"]];
    [items addObject:[self buttonNamed:@"左侧手柄动作" action:@selector(openLeftSettings)]];
    [items addObject:[self buttonNamed:@"右侧手柄动作" action:@selector(openRightSettings)]];
    [items addObject:[self groupNamed:@"手柄高度" footer:@"调节圆角手柄的可见高度。"]];
    [items addObject:[self sliderForKey:BCX_HANDLE_HEIGHT defaultValue:84 minimum:48 maximum:160]];
    [items addObject:[self groupNamed:@"垂直位置" footer:@"数值表示手柄中心在屏幕高度中的位置。"]];
    [items addObject:[self sliderForKey:BCX_HANDLE_POSITION defaultValue:0.58 minimum:0.10 maximum:0.90]];
    [items addObject:[self groupNamed:@"白条位置" footer:@"正数向屏幕内侧移动，负数向屏幕边缘移动。"]];
    [items addObject:[self sliderForKey:BCX_HANDLE_INDICATOR_POSITION defaultValue:2 minimum:-6 maximum:6]];
    [items addObject:[self groupNamed:@"阴影宽度" footer:@"调节手柄深色背景的宽度。"]];
    [items addObject:[self sliderForKey:BCX_HANDLE_SHADOW_WIDTH defaultValue:14 minimum:8 maximum:30]];
    [items addObject:[self groupNamed:@"阴影位置" footer:@"正数向屏幕内侧移动，负数向屏幕外侧延伸。"]];
    [items addObject:[self sliderForKey:BCX_HANDLE_SHADOW_POSITION defaultValue:-1 minimum:-6 maximum:8]];
    [items addObject:[self groupNamed:@"面板最小宽度" footer:@"长动作名称仍会自动拓宽面板。"]];
    [items addObject:[self sliderForKey:BCX_PANEL_MIN_WIDTH defaultValue:104 minimum:80 maximum:220]];

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

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    [super tableView:tableView willDisplayCell:cell forRowAtIndexPath:indexPath];
    NSMutableArray *sliders = [NSMutableArray array];
    BCXCollectViews(cell, UISlider.class, sliders);
    if (!sliders.count) return;
    UISlider *slider = sliders.firstObject;
    PSSpecifier *specifier = [self specifierAtIndexPath:indexPath];
    NSMutableArray *labels = [NSMutableArray array];
    BCXCollectViews(cell, UILabel.class, labels);
    UILabel *valueLabel = labels.lastObject;
    if (!valueLabel || valueLabel == cell.textLabel) return;
    valueLabel.userInteractionEnabled = YES;
    valueLabel.font = [UIFont monospacedDigitSystemFontOfSize:17 weight:UIFontWeightRegular];
    valueLabel.text = BCXDecimal(slider.value);
    objc_setAssociatedObject(slider, BCXSliderLabelKey, valueLabel, OBJC_ASSOCIATION_ASSIGN);
    objc_setAssociatedObject(slider, BCXSliderSpecifierKey, specifier, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(valueLabel, BCXSliderSpecifierKey, specifier, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [slider addTarget:self action:@selector(precisionSliderChanged:) forControlEvents:UIControlEventValueChanged];
    [slider addTarget:self action:@selector(precisionSliderEnded:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
    if (!valueLabel.gestureRecognizers.count)
        [valueLabel addGestureRecognizer:[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(editSliderValue:)]];
}

- (void)precisionSliderChanged:(UISlider *)slider {
    ((UILabel *)objc_getAssociatedObject(slider, BCXSliderLabelKey)).text = BCXDecimal(slider.value);
}

- (void)precisionSliderEnded:(UISlider *)slider {
    CGFloat value = round(slider.value * 100) / 100;
    slider.value = value;
    [self setPreferenceValue:@(value) specifier:objc_getAssociatedObject(slider, BCXSliderSpecifierKey)];
    [self precisionSliderChanged:slider];
}

- (void)editSliderValue:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    PSSpecifier *specifier = objc_getAssociatedObject(gesture.view, BCXSliderSpecifierKey);
    CGFloat current = [[self readPreferenceValue:specifier] doubleValue];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"输入数值" message:@"最多保留两位小数" preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.keyboardType = UIKeyboardTypeDecimalPad;
        field.text = BCXDecimal(current);
        [field selectAll:nil];
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *text = [alert.textFields.firstObject.text stringByReplacingOccurrencesOfString:@"," withString:@"."];
        NSScanner *scanner = [NSScanner scannerWithString:text];
        double entered = 0;
        if (![scanner scanDouble:&entered] || !scanner.isAtEnd) return;
        CGFloat minimum = [specifier.properties[@"min"] doubleValue];
        CGFloat maximum = [specifier.properties[@"max"] doubleValue];
        CGFloat value = round(MAX(minimum, MIN(maximum, entered)) * 100) / 100;
        [self setPreferenceValue:@(value) specifier:specifier];
        [self reloadSpecifier:specifier animated:NO];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
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
