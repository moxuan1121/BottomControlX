#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <Preferences/PSSwitchTableCell.h>
#import <Preferences/PSTableCell.h>
#import <Preferences/PSEditableTableCell.h>
#import <Preferences/PSListItemsController.h>
#import <Preferences/PSSliderTableCell.h>
#import <SafariServices/SafariServices.h>
#import <spawn.h>
#import "../Common.h"

static void easy_spawn(const char * args[]) {
    pid_t pid;
    int status;
    posix_spawn(&pid, args[0], NULL, NULL, (char * const*)args, NULL);
    waitpid(pid, &status, WEXITED);
}

@interface UIImage (SettingsKit)
+ (UIImage *)imageNamed:(NSString *)named inBundle:(NSBundle *)bundle;
@end

@interface PSSpecifier (ValuesAndTitles)
- (void)setValues:(NSArray *)values titles:(NSArray *)titles;
@end

@interface FixedSliderCell : PSSliderTableCell
@end

@implementation FixedSliderCell
- (void)layoutSubviews {
    [super layoutSubviews];
    
    BOOL isRTL = ([UIApplication sharedApplication].userInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft);
    // Fix issue where left and right were swapped for some reason on iOS 26
    if (!isRTL && [self.control respondsToSelector:@selector(setSemanticContentAttribute:)]) {
        self.control.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    }
}
@end

@interface PSSubtitleSwitchTableCell : PSSwitchTableCell
@end

@interface BCXSwitchTableCell : PSSubtitleSwitchTableCell
@end

@implementation BCXSwitchTableCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier specifier:(PSSpecifier *)specifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier specifier:specifier];
    if (self) {
        [((UISwitch *)[self control]) setOnTintColor:SettingsColor(1)];
    }
    return self;
}
@end

@interface BottomControlXController : PSListController
@end

@interface SBGestureSettingsListController : BottomControlXController
@end

@interface LockGestureSettingsListController : BottomControlXController
@end

@interface AppGestureSettingsListController : BottomControlXController
@end

@implementation BottomControlXController
- (NSArray *)specifiers {
    if (_specifiers == nil) {
        NSMutableArray *specifiers = [NSMutableArray array];
        PSSpecifier *spec;
        
        spec = [PSSpecifier preferenceSpecifierNamed:@"Enabled"
                                              target:self
                                                 set:@selector(setPreferenceValue:specifier:)
                                                 get:@selector(readPreferenceValue:)
                                              detail:Nil
                                                cell:PSSwitchCell
                                                edit:Nil];
        [spec setProperty:@"enable" forKey:@"key"];
        [spec setProperty:@YES forKey:@"default"];
        [spec setProperty:NSClassFromString(@"BCXSwitchTableCell") forKey:@"cellClass"];
        [spec setProperty:@"No respring is required" forKey:@"cellSubtitleText"];
        [specifiers addObject:spec];
        
        spec = [PSSpecifier preferenceSpecifierNamed:@"Custom Gesture"
                                              target:self
                                                 set:Nil
                                                 get:Nil
                                              detail:Nil
                                                cell:PSGroupCell
                                                edit:Nil];
        [spec setProperty:@"Custom the swipe up gesture from left/center/right bottom of the screen." forKey:@"footerText"];
        [specifiers addObject:spec];
        
        spec = [PSSpecifier preferenceSpecifierNamed:@"SpringBoard"
                                              target:self
                                                 set:NULL
                                                 get:NULL
                                              detail:SBGestureSettingsListController.class
                                                cell:PSLinkCell
                                                edit:Nil];
        [spec setProperty:@YES forKey:@"isController"];
        [specifiers addObject:spec];
        
        spec = [PSSpecifier preferenceSpecifierNamed:@"LockScreen"
                                              target:self
                                                 set:NULL
                                                 get:NULL
                                              detail:LockGestureSettingsListController.class
                                                cell:PSLinkCell
                                                edit:Nil];
        [spec setProperty:@YES forKey:@"isController"];
        [specifiers addObject:spec];
        
        spec = [PSSpecifier preferenceSpecifierNamed:@"In Apps"
                                              target:self
                                                 set:NULL
                                                 get:NULL
                                              detail:AppGestureSettingsListController.class
                                                cell:PSLinkCell
                                                edit:Nil];
        [spec setProperty:@YES forKey:@"isController"];
        [specifiers addObject:spec];
        
        spec = [PSSpecifier preferenceSpecifierNamed:@"Gesture Area"
                                              target:self
                                                 set:Nil
                                                 get:Nil
                                              detail:Nil
                                                cell:PSGroupCell
                                                edit:Nil];
        [spec setProperty:@"Custom Left & Right Gesture area's width." forKey:@"footerText"];
        [specifiers addObject:spec];
        
        spec = [PSSpecifier preferenceSpecifierNamed:@"Left Gesture Area"
                                              target:self
                                                 set:@selector(setPreferenceValue:specifier:)
                                                 get:@selector(readPreferenceValue:)
                                              detail:PSListItemsController.class
                                                cell:PSLinkListCell
                                                edit:Nil];
        [spec setProperty:@"leftValue" forKey:@"key"];
        [spec setProperty:@0.25 forKey:@"default"];
        [spec setValues:@[@0.0, @0.5, @0.1, @0.15, @0.2, @0.25, @0.3]
                 titles:@[@"0\%", @"5\%", @"10\%", @"15\%", @"20\%", @"25\%", @"30\%"]];
        [specifiers addObject:spec];
                
        spec = [PSSpecifier preferenceSpecifierNamed:@"Right Gesture Area"
                                              target:self
                                                 set:@selector(setPreferenceValue:specifier:)
                                                 get:@selector(readPreferenceValue:)
                                              detail:PSListItemsController.class
                                                cell:PSLinkListCell
                                                edit:Nil];
        [spec setProperty:@"rightValue" forKey:@"key"];
        [spec setProperty:@0.75 forKey:@"default"];
        [spec setValues:@[@0.7, @0.75, @0.8, @0.85, @0.9, @0.95, @1.10]
                 titles:@[@"70\%", @"75\%", @"80\%", @"85\%", @"90\%", @"95\%", @"100\%"]];
        [specifiers addObject:spec];
        
        spec = [PSSpecifier emptyGroupSpecifier];
        [spec setProperty:@"Custom the velocity value which is needed to trigger BottomControlX gesture when you have lower gesture sensibility enabled." forKey:@"footerText"];
        [specifiers addObject:spec];
        
        spec = [PSSpecifier preferenceSpecifierNamed:@"Lower gesture sensibility"
                                              target:self
                                                 set:@selector(setPreferenceValue:specifier:)
                                                 get:@selector(readPreferenceValue:)
                                              detail:Nil
                                                cell:PSSwitchCell
                                                edit:Nil];
        [spec setProperty:@"lowerSensibility" forKey:@"key"];
        [spec setProperty:@NO forKey:@"default"];
        [spec setProperty:NSClassFromString(@"BCXSwitchTableCell") forKey:@"cellClass"];
        [spec setProperty:@"No respring is required" forKey:@"cellSubtitleText"];
        [specifiers addObject:spec];
        
        spec = [PSSpecifier preferenceSpecifierNamed:@"velocityValue"
                                              target:self
                                                 set:@selector(setPreferenceValue:specifier:)
                                                 get:@selector(readPreferenceValue:)
                                              detail:Nil
                                                cell:PSSliderCell
                                                edit:Nil];
        if (@available(iOS 26.0, *)) {
            [spec setProperty:NSClassFromString(@"FixedSliderCell") forKey:@"cellClass"];
        }
        [spec setProperty:@"velocityValue" forKey:@"key"];
        [spec setProperty:@150.0 forKey:@"default"];
        [spec setProperty:@100.0 forKey:@"min"];
        [spec setProperty:@500.0 forKey:@"max"];
        [spec setProperty:@YES forKey:@"isSegmented"];
        [spec setProperty:@(40) forKey:@"segmentCount"];
        [spec setProperty:@YES forKey:@"showValue"];
        [specifiers addObject:spec];
        
        spec = [PSSpecifier emptyGroupSpecifier];
        [specifiers addObject:spec];

        spec = [PSSpecifier preferenceSpecifierNamed:@"Enable gestures in Landscape"
                                              target:self
                                                 set:@selector(setPreferenceValue:specifier:)
                                                 get:@selector(readPreferenceValue:)
                                              detail:Nil
                                                cell:PSSwitchCell
                                                edit:Nil];
        [spec setProperty:@"useLandscape" forKey:@"key"];
        [spec setProperty:@YES forKey:@"default"];
        [spec setProperty:NSClassFromString(@"BCXSwitchTableCell") forKey:@"cellClass"];
        [spec setProperty:@"No respring is required" forKey:@"cellSubtitleText"];
        [specifiers addObject:spec];
        
        spec = [PSSpecifier emptyGroupSpecifier];
        [specifiers addObject:spec];
        
        spec = [PSSpecifier preferenceSpecifierNamed:@"Reset Area & Slider"
                                              target:self
                                                 set:Nil
                                                 get:Nil
                                              detail:Nil
                                                cell:PSButtonCell
                                                edit:Nil];

        spec->action = @selector(resetSliders);
        [spec setProperty:@1 forKey:@"alignment"];
        [specifiers addObject:spec];
        
        spec = [PSSpecifier emptyGroupSpecifier];
        [specifiers addObject:spec];
        
        spec = [PSSpecifier preferenceSpecifierNamed:@"Reset Settings"
                                              target:self
                                                 set:Nil
                                                 get:Nil
                                              detail:Nil
                                                cell:PSButtonCell
                                                edit:Nil];

        spec->action = @selector(resetSettings);
        [spec setProperty:@1 forKey:@"alignment"];
        [specifiers addObject:spec];
        
        spec = [PSSpecifier preferenceSpecifierNamed:@"Respring"
                                              target:self
                                                 set:Nil
                                                 get:Nil
                                              detail:Nil
                                                cell:PSButtonCell
                                                edit:Nil];

        spec->action = @selector(respring);
        [spec setProperty:@1 forKey:@"alignment"];
        [specifiers addObject:spec];
        
        spec = [PSSpecifier emptyGroupSpecifier];
        [specifiers addObject:spec];
        
        spec = [PSSpecifier preferenceSpecifierNamed:@"Other Tweaks"
                                              target:self
                                                 set:NULL
                                                 get:NULL
                                              detail:Nil
                                                cell:PSLinkCell
                                                edit:Nil];
        
        spec->action = @selector(openDaonate);
        [specifiers addObject:spec];
        
        spec = [PSSpecifier emptyGroupSpecifier];
        [spec setProperty:@1 forKey:@"footerAlignment"];
        [spec setProperty:@"BottomControlX, by XCXiao." forKey:@"footerText"];
        [specifiers addObject:spec];
        
        spec = [PSSpecifier emptyGroupSpecifier];
        [spec setProperty:@1 forKey:@"footerAlignment"];
        [spec setProperty:CREDITS forKey:@"footerText"];
        [specifiers addObject:spec];
        
        _specifiers = [specifiers copy];
    }
    return _specifiers;
}
- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSMutableDictionary *prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:PREF_PATH]?:[NSMutableDictionary dictionary];
    [prefs setObject:value forKey:specifier.properties[@"key"]];
    [prefs writeToFile:PREF_PATH atomically:YES];
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR(Notify_Preferences), NULL, NULL, YES);
}
- (id)readPreferenceValue:(PSSpecifier*)specifier {
    NSDictionary *prefs = [[NSDictionary alloc] initWithContentsOfFile:PREF_PATH];
    return prefs[specifier.properties[@"key"]]?:[[specifier properties] objectForKey:@"default"];
}
- (void)resetSliders {
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithContentsOfFile:PREF_PATH]?:[NSMutableDictionary dictionary];
    [dict removeObjectForKey:@"leftValue"];
    [dict removeObjectForKey:@"rightValue"];
    [dict removeObjectForKey:@"velocityValue"];
    [dict writeToFile:PREF_PATH atomically:YES];
    [self reloadSpecifiers];
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR(Notify_Preferences), NULL, NULL, YES);
}
- (void)respring {
    easy_spawn((const char *[]){jbroot("/usr/bin/killall"), "backboardd", NULL});
}
- (void)resetSettings {
    UIAlertController *alertController =
    [UIAlertController alertControllerWithTitle:@"Reset Settings?"
                                        message:@"Delete the configuration file and reset the settings"
                                 preferredStyle:UIAlertControllerStyleAlert];

    [alertController addAction:[UIAlertAction actionWithTitle:@"YES"
                                                        style:UIAlertActionStyleDestructive
                                                      handler:^(UIAlertAction *action) {
        [[NSFileManager defaultManager] removeItemAtPath:PREF_PATH error:nil];
        [self reloadSpecifiers];
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR(Notify_Preferences), NULL, NULL, YES);
    }]];

    [alertController addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                                        style:UIAlertActionStyleDefault
                                                      handler:nil]];

    [self presentViewController:alertController animated:YES completion:nil];
}
- (void)openDaonate {
    [self openURLInBrowser:@"https://cydia.ichitaso.com/donation.html"];
}
- (void)openURLInBrowser:(NSString *)url {
    SFSafariViewController *safari = [[SFSafariViewController alloc] initWithURL:[NSURL URLWithString:url]];
    [self presentViewController:safari animated:YES completion:nil];
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if (self.class == BottomControlXController.class) {
        [self setupHeader];
    }
}
- (void)setupHeader {
    UINavigationItem *navigationItem = self.navigationItem;
    
    navigationItem.titleView =
    [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"Icon"
                                                  inBundle:[NSBundle bundleForClass:self.class]]];
    
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 60)];
    
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 17, header.frame.size.width, header.frame.size.height - 10)];
    label.text = @"BottomControlX";
    label.font = [UIFont fontWithName:@"PingFangSC-Thin" size:35];
    label.backgroundColor = [UIColor clearColor];
    label.textAlignment = NSTextAlignmentCenter;
    
    header.frame = CGRectMake(header.frame.origin.x, header.frame.origin.y, header.frame.size.width, header.frame.size.height + 35);
    label.frame = CGRectMake(label.frame.origin.x, 10, label.frame.size.width, label.frame.size.height - 5);
    [header addSubview:label];
    
    UILabel *subText = [[UILabel alloc] initWithFrame:CGRectMake(header.frame.origin.x, label.frame.origin.y + label.frame.size.height, header.frame.size.width, 20)];
    
    subText.text = @"Control your iPhone X series";
    subText.font = [UIFont fontWithName:@"PingFangSC-Thin" size:16];
    subText.backgroundColor = [UIColor clearColor];
    subText.textAlignment = NSTextAlignmentCenter;
    [header addSubview:subText];
    
    if (header) {
        header.backgroundColor = [UIColor clearColor];
        header.autoresizesSubviews = YES;
        header.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    }

    if (header) {
        [self.table setTableHeaderView:header];
    }
}

@end

@implementation SBGestureSettingsListController
- (NSArray *)specifiers {
    self.title = @"SpringBoard Gestures";
    
    if (_specifiers == nil) {
        NSMutableArray *specifiers = [NSMutableArray array];
        PSSpecifier *spec;
        
        spec = [PSSpecifier preferenceSpecifierNamed:@"Bottom Left"
                                              target:self
                                                 set:@selector(setPreferenceValue:specifier:)
                                                 get:@selector(readPreferenceValue:)
                                              detail:PSListItemsController.class
                                                cell:PSLinkListCell
                                                edit:Nil];
        [spec setProperty:@"SBBottomLeftGesture" forKey:@"key"];
        [spec setProperty:@1 forKey:@"default"];
        [spec setValues:@[@1, @2, @3, @9, @5, @6, @10]
                 titles:@[@"Home Gesture", @"ControlCenter", @"Lock Device", @"Cover Sheet", @"Take Screenshot", @"SecretShot", @"No Action"]];
        [specifiers addObject:spec];
        
        spec = [PSSpecifier preferenceSpecifierNamed:@"Bottom Center"
                                              target:self
                                                 set:@selector(setPreferenceValue:specifier:)
                                                 get:@selector(readPreferenceValue:)
                                              detail:PSListItemsController.class
                                                cell:PSLinkListCell
                                                edit:Nil];
        [spec setProperty:@"SBBottomCenterGesture" forKey:@"key"];
        [spec setProperty:@1 forKey:@"default"];
        [spec setValues:@[@1, @2, @3, @9, @5, @6, @10]
                 titles:@[@"Home Gesture", @"ControlCenter", @"Lock Device", @"Cover Sheet", @"Take Screenshot", @"SecretShot", @"No Action"]];
        [specifiers addObject:spec];
        
        spec = [PSSpecifier preferenceSpecifierNamed:@"Bottom Right"
                                              target:self
                                                 set:@selector(setPreferenceValue:specifier:)
                                                 get:@selector(readPreferenceValue:)
                                              detail:PSListItemsController.class
                                                cell:PSLinkListCell
                                                edit:Nil];
        [spec setProperty:@"SBBottomRightGesture" forKey:@"key"];
        [spec setProperty:@1 forKey:@"default"];
        [spec setValues:@[@1, @2, @3, @9, @5, @6, @10]
                 titles:@[@"Home Gesture", @"ControlCenter", @"Lock Device", @"Cover Sheet", @"Take Screenshot", @"SecretShot", @"No Action"]];
        [specifiers addObject:spec];
        
        _specifiers = [specifiers copy];
    }
    return _specifiers;
}
@end

@implementation LockGestureSettingsListController
- (NSArray *)specifiers {
    self.title = @"LockScreen Gestures";
    
    if (_specifiers == nil) {
        NSMutableArray *specifiers = [NSMutableArray array];
        PSSpecifier *spec;
        
        spec = [PSSpecifier preferenceSpecifierNamed:@"Bottom Left"
                                              target:self
                                                 set:@selector(setPreferenceValue:specifier:)
                                                 get:@selector(readPreferenceValue:)
                                              detail:PSListItemsController.class
                                                cell:PSLinkListCell
                                                edit:Nil];
        [spec setProperty:@"LBottomLeftGesture" forKey:@"key"];
        [spec setProperty:@1 forKey:@"default"];
        [spec setValues:@[@1, @2, @3, @5, @6]
                 titles:@[@"Home Gesture", @"ControlCenter", @"Lock Device", @"Take Screenshot", @"SecretShot"]];
        [specifiers addObject:spec];
        
        spec = [PSSpecifier preferenceSpecifierNamed:@"Bottom Center"
                                              target:self
                                                 set:@selector(setPreferenceValue:specifier:)
                                                 get:@selector(readPreferenceValue:)
                                              detail:PSListItemsController.class
                                                cell:PSLinkListCell
                                                edit:Nil];
        [spec setProperty:@"LBottomCenterGesture" forKey:@"key"];
        [spec setProperty:@1 forKey:@"default"];
        [spec setValues:@[@1, @2, @3, @5, @6]
                 titles:@[@"Home Gesture", @"ControlCenter", @"Lock Device", @"Take Screenshot", @"SecretShot"]];
        [specifiers addObject:spec];
        
        spec = [PSSpecifier preferenceSpecifierNamed:@"Bottom Right"
                                              target:self
                                                 set:@selector(setPreferenceValue:specifier:)
                                                 get:@selector(readPreferenceValue:)
                                              detail:PSListItemsController.class
                                                cell:PSLinkListCell
                                                edit:Nil];
        [spec setProperty:@"LBottomRightGesture" forKey:@"key"];
        [spec setProperty:@1 forKey:@"default"];
        [spec setValues:@[@1, @2, @3, @5, @6]
                 titles:@[@"Home Gesture", @"ControlCenter", @"Lock Device", @"Take Screenshot", @"SecretShot"]];
        [specifiers addObject:spec];
        
        spec = [PSSpecifier emptyGroupSpecifier];
        [spec setProperty:@"Allow works while passcode locked?" forKey:@"footerText"];
        [specifiers addObject:spec];
        
        spec = [PSSpecifier preferenceSpecifierNamed:@"Enabled when passcode locked"
                                              target:self
                                                 set:@selector(setPreferenceValue:specifier:)
                                                 get:@selector(readPreferenceValue:)
                                              detail:Nil
                                                cell:PSSwitchCell
                                                edit:Nil];
        [spec setProperty:@"passcode" forKey:@"key"];
        [spec setProperty:@NO forKey:@"default"];
        [spec setProperty:NSClassFromString(@"BCXSwitchTableCell") forKey:@"cellClass"];
        [spec setProperty:@"No respring is required" forKey:@"cellSubtitleText"];
        [specifiers addObject:spec];
        
        _specifiers = [specifiers copy];
    }
    return _specifiers;
}
@end

@implementation AppGestureSettingsListController
- (NSArray *)specifiers {
    self.title = @"In Apps Gestures";
    
    if (_specifiers == nil) {
        NSMutableArray *specifiers = [NSMutableArray array];
        PSSpecifier *spec;
        
        spec = [PSSpecifier preferenceSpecifierNamed:@"Bottom Left"
                                              target:self
                                                 set:@selector(setPreferenceValue:specifier:)
                                                 get:@selector(readPreferenceValue:)
                                              detail:PSListItemsController.class
                                                cell:PSLinkListCell
                                                edit:Nil];
        [spec setProperty:@"AppBottomLeftGesture" forKey:@"key"];
        [spec setProperty:@1 forKey:@"default"];
        [spec setValues:@[@1, @2, @3, @9, @5, @6, @10]
                 titles:@[@"Home Gesture", @"ControlCenter", @"Lock Device", @"Cover Sheet", @"Take Screenshot", @"SecretShot", @"No Action"]];
        [specifiers addObject:spec];
        
        spec = [PSSpecifier preferenceSpecifierNamed:@"Bottom Center"
                                              target:self
                                                 set:@selector(setPreferenceValue:specifier:)
                                                 get:@selector(readPreferenceValue:)
                                              detail:PSListItemsController.class
                                                cell:PSLinkListCell
                                                edit:Nil];
        [spec setProperty:@"AppBottomCenterGesture" forKey:@"key"];
        [spec setProperty:@1 forKey:@"default"];
        [spec setValues:@[@1, @2, @3, @9, @5, @6, @10]
                 titles:@[@"Home Gesture", @"ControlCenter", @"Lock Device", @"Cover Sheet", @"Take Screenshot", @"SecretShot", @"No Action"]];
        [specifiers addObject:spec];
        
        spec = [PSSpecifier preferenceSpecifierNamed:@"Bottom Right"
                                              target:self
                                                 set:@selector(setPreferenceValue:specifier:)
                                                 get:@selector(readPreferenceValue:)
                                              detail:PSListItemsController.class
                                                cell:PSLinkListCell
                                                edit:Nil];
        [spec setProperty:@"AppBottomRightGesture" forKey:@"key"];
        [spec setProperty:@1 forKey:@"default"];
        [spec setValues:@[@1, @2, @3, @9, @5, @6, @10]
                 titles:@[@"Home Gesture", @"ControlCenter", @"Lock Device", @"Cover Sheet", @"Take Screenshot", @"SecretShot", @"No Action"]];
        [specifiers addObject:spec];
        
        _specifiers = [specifiers copy];
    }
    return _specifiers;
}
@end
