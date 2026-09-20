#import <UIKit/UIKit.h>
#import "../PanelData.h"

typedef NS_ENUM(NSInteger, BCXPickerMode) {
    BCXPickerModePanel,
    BCXPickerModeShortcuts,
    BCXPickerModeApps,
    BCXPickerModeQuickActions,
    BCXPickerModeBuiltins
};

@interface BCXPanelSettingsController : UITableViewController
@property(nonatomic) BCXPickerMode mode;
@property(nonatomic, copy) NSString *bundleID;
@property(nonatomic, copy) NSArray<NSDictionary *> *choices;
- (instancetype)initWithMode:(BCXPickerMode)mode bundleID:(NSString *)bundleID title:(NSString *)title;
@end

@implementation BCXPanelSettingsController

- (instancetype)init {
    return [self initWithMode:BCXPickerModePanel bundleID:nil title:@"快捷面板"];
}

- (instancetype)initWithMode:(BCXPickerMode)mode bundleID:(NSString *)bundleID title:(NSString *)title {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) {
        _mode = mode;
        _bundleID = [bundleID copy];
        self.title = title;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.rowHeight = 52;
    if (self.mode == BCXPickerModePanel) {
        self.navigationItem.rightBarButtonItem = self.editButtonItem;
        return;
    }
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    [spinner startAnimating];
    self.tableView.backgroundView = spinner;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSArray *items = @[];
        switch (self.mode) {
            case BCXPickerModeShortcuts: items = BCXShortcuts(); break;
            case BCXPickerModeApps: items = BCXInstalledApps(); break;
            case BCXPickerModeQuickActions: items = BCXQuickActions(self.bundleID); break;
            case BCXPickerModeBuiltins: items = BCXBuiltinActions(); break;
            default: break;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            self.choices = items;
            UILabel *empty = [[UILabel alloc] initWithFrame:CGRectZero];
            empty.textAlignment = NSTextAlignmentCenter;
            empty.numberOfLines = 0;
            empty.textColor = UIColor.secondaryLabelColor;
            empty.text = self.mode == BCXPickerModeShortcuts
                ? @"未读取到快捷指令。请确认“快捷指令”App 中已有指令。"
                : self.mode == BCXPickerModeQuickActions
                    ? @"此应用暂无可读取的图标快捷操作。"
                    : @"没有可用项目";
            self.tableView.backgroundView = items.count ? nil : empty;
            [self.tableView reloadData];
        });
    });
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.mode == BCXPickerModePanel ? 3 : 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.mode != BCXPickerModePanel) return self.choices.count;
    if (section == 0) return BCXPanelItems().count;
    return section == 1 ? 3 : 3;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (self.mode != BCXPickerModePanel) return nil;
    return @[@"面板项目：拖动排序，左滑移除", @"添加项目", @"图标尺寸"][section];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (self.mode != BCXPickerModePanel || section != 0) return nil;
    return @"在桌面或应用内设置一个底部区域为“快捷面板”后，上滑即可打开。锁屏和横屏不显示面板。";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"BCXItem"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"BCXItem"];
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    cell.detailTextLabel.text = nil;
    cell.imageView.image = nil;
    cell.imageView.tintColor = UIColor.systemBlueColor;
    NSInteger smallIcon = [@[@18, @24, @30][BCXIconSize()] integerValue];
    if (self.mode == BCXPickerModePanel && path.section == 1) {
        cell.textLabel.text = @[@"快捷指令", @"应用图标快捷操作", @"系统与越狱动作"][path.row];
        cell.imageView.image = [UIImage systemImageNamed:@[@"square.stack.3d.up", @"app.badge", @"gearshape"][path.row]
                                           withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:smallIcon]];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else if (self.mode == BCXPickerModePanel && path.section == 2) {
        cell.textLabel.text = @[@"小", @"中", @"大"][path.row];
        cell.accessoryType = BCXIconSize() == path.row ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    } else {
        NSDictionary *item = self.mode == BCXPickerModePanel ? BCXPanelItems()[path.row] : self.choices[path.row];
        cell.textLabel.text = item[@"title"];
        cell.imageView.image = [UIImage systemImageNamed:self.mode == BCXPickerModeApps ? @"app" : BCXSymbol(item)
                                           withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:smallIcon]];
        if (self.mode == BCXPickerModeApps) cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        if (self.mode == BCXPickerModePanel && [item[@"kind"] isEqualToString:@"quick"]) cell.detailTextLabel.text = item[@"app"];
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
    [tableView deselectRowAtIndexPath:path animated:YES];
    if (self.mode == BCXPickerModePanel) {
        if (path.section == 2) {
            BCXSetIconSize(path.row);
            [tableView reloadSections:[NSIndexSet indexSetWithIndex:2] withRowAnimation:UITableViewRowAnimationNone];
            [tableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationNone];
            return;
        }
        if (path.section != 1) return;
        BCXPickerMode mode = [@[@(BCXPickerModeShortcuts), @(BCXPickerModeApps), @(BCXPickerModeBuiltins)][path.row] integerValue];
        NSString *title = @[@"选择快捷指令", @"选择应用", @"选择动作"][path.row];
        [self.navigationController pushViewController:[[BCXPanelSettingsController alloc] initWithMode:mode bundleID:nil title:title] animated:YES];
        return;
    }
    NSDictionary *item = self.choices[path.row];
    if (self.mode == BCXPickerModeApps) {
        [self.navigationController pushViewController:[[BCXPanelSettingsController alloc] initWithMode:BCXPickerModeQuickActions bundleID:item[@"id"] title:item[@"title"]] animated:YES];
        return;
    }
    NSMutableArray *items = [BCXPanelItems() mutableCopy];
    BOOL exists = NO;
    for (NSDictionary *saved in items) {
        if ([saved[@"kind"] isEqualToString:item[@"kind"]] && [saved[@"id"] isEqualToString:item[@"id"]] &&
            [(saved[@"app"] ?: @"") isEqualToString:(item[@"app"] ?: @"")]) {
            exists = YES;
            break;
        }
    }
    if (!exists) {
        [items addObject:item];
        BCXSavePanelItems(items);
    }
    for (UIViewController *controller in self.navigationController.viewControllers.reverseObjectEnumerator) {
        if ([controller isKindOfClass:BCXPanelSettingsController.class] &&
            ((BCXPanelSettingsController *)controller).mode == BCXPickerModePanel) {
            [self.navigationController popToViewController:controller animated:YES];
            break;
        }
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)path {
    return self.mode == BCXPickerModePanel && path.section == 0;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)style forRowAtIndexPath:(NSIndexPath *)path {
    if (style != UITableViewCellEditingStyleDelete) return;
    NSMutableArray *items = [BCXPanelItems() mutableCopy];
    if (path.row >= items.count) return;
    [items removeObjectAtIndex:path.row];
    BCXSavePanelItems(items);
    [tableView deleteRowsAtIndexPaths:@[path] withRowAnimation:UITableViewRowAnimationAutomatic];
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)path {
    return self.mode == BCXPickerModePanel && path.section == 0;
}

- (NSIndexPath *)tableView:(UITableView *)tableView targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)source toProposedIndexPath:(NSIndexPath *)target {
    return target.section == 0 ? target : source;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)source toIndexPath:(NSIndexPath *)target {
    NSMutableArray *items = [BCXPanelItems() mutableCopy];
    if (source.row >= items.count || target.row >= items.count) return;
    id item = items[source.row];
    [items removeObjectAtIndex:source.row];
    [items insertObject:item atIndex:target.row];
    BCXSavePanelItems(items);
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (self.mode == BCXPickerModePanel) [self.tableView reloadData];
}

@end
