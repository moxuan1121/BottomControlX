#import <UIKit/UIKit.h>
#import "../PanelData.h"

typedef NS_ENUM(NSInteger, BCXPickerMode) {
    BCXPickerModePanel,
    BCXPickerModeShortcuts,
    BCXPickerModeApps,
    BCXPickerModeQuickActions,
    BCXPickerModeBuiltins
};

@interface BCXPanelSettingsController : UITableViewController <UIDocumentPickerDelegate>
@property(nonatomic) BCXPickerMode mode;
@property(nonatomic, copy) NSString *bundleID;
@property(nonatomic, copy) NSArray<NSDictionary *> *choices;
@property(nonatomic, copy) NSString *zoneKey;
@property(nonatomic) NSInteger editingIndex;
- (instancetype)initWithMode:(BCXPickerMode)mode bundleID:(NSString *)bundleID title:(NSString *)title;
- (instancetype)initWithZoneKey:(NSString *)zoneKey title:(NSString *)title;
@end

@implementation BCXPanelSettingsController

- (instancetype)init {
    return [self initWithZoneKey:BCX_CENTER_ITEMS title:@"中间区域动作"];
}

- (instancetype)initWithZoneKey:(NSString *)zoneKey title:(NSString *)title {
    self = [self initWithMode:BCXPickerModePanel bundleID:nil title:title];
    if (self) _zoneKey = [zoneKey copy];
    return self;
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
            case BCXPickerModeQuickActions: items = BCXRequestQuickActions(self.bundleID); break;
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
                    ? @"此应用没有可读取的图标快捷操作。请确认 SpringBoard 已运行插件，并尝试长按应用图标查看系统菜单。"
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
    if (section == 0) return BCXPanelItemsForKey(self.zoneKey).count;
    return section == 1 ? 3 : 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (self.mode != BCXPickerModePanel) return nil;
    return @[@"已选动作：拖动排序，左滑移除", @"添加动作", @"面板图标尺寸"][section];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (self.mode != BCXPickerModePanel || section != 0) return nil;
    return @"一项直接运行；两项或更多自动显示面板。";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"BCXItem"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"BCXItem"];
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    cell.detailTextLabel.text = nil;
    cell.imageView.image = nil;
    cell.imageView.tintColor = UIColor.systemBlueColor;
    NSInteger smallIcon = MIN(30, MAX(18, BCXIconSize() * 0.6));
    if (self.mode == BCXPickerModePanel && path.section == 1) {
        cell.textLabel.text = @[@"系统与越狱动作", @"快捷指令", @"应用快捷方式"][path.row];
        cell.imageView.image = [UIImage systemImageNamed:@[@"gearshape", @"square.stack.3d.up", @"app.badge"][path.row]
                                           withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:smallIcon]];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else if (!(self.mode == BCXPickerModePanel && path.section == 2)) {
        NSDictionary *item = self.mode == BCXPickerModePanel ? BCXPanelItemsForKey(self.zoneKey)[path.row] : self.choices[path.row];
        cell.textLabel.text = item[@"title"];
        cell.imageView.image = self.mode == BCXPickerModeApps ? BCXApplicationIcon(item[@"id"]) : BCXItemImage(item, smallIcon);
        if (self.mode == BCXPickerModeApps) cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        if (self.mode == BCXPickerModePanel && [item[@"kind"] isEqualToString:@"quick"]) cell.detailTextLabel.text = item[@"app"];
    }
    if (self.mode == BCXPickerModePanel && path.section == 2) {
        cell.textLabel.text = [NSString stringWithFormat:@"图标大小 %.0f", BCXIconSize()];
        UISlider *slider = [[UISlider alloc] initWithFrame:CGRectMake(0, 0, 170, 32)];
        slider.minimumValue = 20; slider.maximumValue = 64; slider.value = BCXIconSize();
        [slider addTarget:self action:@selector(iconSizeChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = slider;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    } else cell.accessoryView = nil;
    return cell;
}

- (void)iconSizeChanged:(UISlider *)slider {
    BCXSetIconSize(round(slider.value));
    [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:2]] withRowAnimation:UITableViewRowAnimationNone];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
    [tableView deselectRowAtIndexPath:path animated:YES];
    if (self.mode == BCXPickerModePanel) {
        if (path.section == 0) { [self editItemAtIndex:path.row]; return; }
        if (path.section == 2) return;
        if (path.section != 1) return;
        BCXPickerMode mode = [@[@(BCXPickerModeBuiltins), @(BCXPickerModeShortcuts), @(BCXPickerModeApps)][path.row] integerValue];
        NSString *title = @[@"系统与越狱动作", @"快捷指令", @"应用快捷方式"][path.row];
        BCXPanelSettingsController *picker = [[BCXPanelSettingsController alloc] initWithMode:mode bundleID:nil title:title];
        picker.zoneKey = self.zoneKey;
        [self.navigationController pushViewController:picker animated:YES];
        return;
    }
    NSDictionary *item = self.choices[path.row];
    if (self.mode == BCXPickerModeApps) {
        BCXPanelSettingsController *picker = [[BCXPanelSettingsController alloc] initWithMode:BCXPickerModeQuickActions bundleID:item[@"id"] title:item[@"title"]];
        picker.zoneKey = self.zoneKey;
        [self.navigationController pushViewController:picker animated:YES];
        return;
    }
    NSMutableArray *items = [BCXPanelItemsForKey(self.zoneKey) mutableCopy];
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
        BCXSavePanelItemsForKey(self.zoneKey, items);
    }
    for (UIViewController *controller in self.navigationController.viewControllers.reverseObjectEnumerator) {
        if ([controller isKindOfClass:BCXPanelSettingsController.class] &&
            ((BCXPanelSettingsController *)controller).mode == BCXPickerModePanel &&
            [((BCXPanelSettingsController *)controller).zoneKey isEqualToString:self.zoneKey]) {
            [self.navigationController popToViewController:controller animated:YES];
            break;
        }
    }
}

- (void)changeItemAtIndex:(NSInteger)index value:(id)value key:(NSString *)key {
    NSMutableArray *items = [BCXPanelItemsForKey(self.zoneKey) mutableCopy];
    if (index < 0 || index >= items.count) return;
    NSMutableDictionary *item = [items[index] mutableCopy];
    if (!item[@"originalTitle"]) item[@"originalTitle"] = item[@"title"] ?: @"";
    if (value) item[key] = value; else [item removeObjectForKey:key];
    items[index] = item;
    BCXSavePanelItemsForKey(self.zoneKey, items);
    [self.tableView reloadData];
}

- (void)editItemAtIndex:(NSInteger)index {
    self.editingIndex = index;
    UIAlertController *menu = [UIAlertController alertControllerWithTitle:@"自定义动作" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [menu addAction:[UIAlertAction actionWithTitle:@"修改名称" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { [self editName]; }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"使用 SF Symbol" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { [self editSymbol]; }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"选择图片" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { [self pickImage]; }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"恢复默认名称和图标" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        NSMutableArray *items = [BCXPanelItemsForKey(self.zoneKey) mutableCopy];
        if (index >= items.count) return;
        NSMutableDictionary *item = [items[index] mutableCopy];
        if (item[@"originalTitle"]) item[@"title"] = item[@"originalTitle"];
        [item removeObjectsForKeys:@[@"originalTitle", @"customSymbol", @"customImage"]];
        items[index] = item;
        BCXSavePanelItemsForKey(self.zoneKey, items);
        [self.tableView reloadData];
    }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    menu.popoverPresentationController.sourceView = self.view;
    menu.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2, 1, 1);
    [self presentViewController:menu animated:YES completion:nil];
}

- (void)editName {
    NSArray *items = BCXPanelItemsForKey(self.zoneKey);
    if (self.editingIndex >= items.count) return;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"动作名称" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) { field.text = items[self.editingIndex][@"title"]; }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *name = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (name.length) [self changeItemAtIndex:self.editingIndex value:name key:@"title"];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)editSymbol {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"SF Symbol 名称" message:@"例如 bolt.fill、camera.fill、heart.fill" preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) { field.placeholder = @"SF Symbol"; }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *symbol = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (symbol.length && [UIImage systemImageNamed:symbol]) {
            [self changeItemAtIndex:self.editingIndex value:symbol key:@"customSymbol"];
            [self changeItemAtIndex:self.editingIndex value:nil key:@"customImage"];
        }
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)pickImage {
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.image"] inMode:UIDocumentPickerModeImport];
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    UIImage *image = [UIImage imageWithData:[NSData dataWithContentsOfURL:urls.firstObject]];
    if (!image) return;
    CGFloat scale = MIN(1, 256.0 / MAX(image.size.width, image.size.height));
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(image.size.width * scale, image.size.height * scale), NO, 1);
    [image drawInRect:CGRectMake(0, 0, image.size.width * scale, image.size.height * scale)];
    NSData *data = UIImagePNGRepresentation(UIGraphicsGetImageFromCurrentImageContext());
    UIGraphicsEndImageContext();
    [self changeItemAtIndex:self.editingIndex value:data key:@"customImage"];
    [self changeItemAtIndex:self.editingIndex value:nil key:@"customSymbol"];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)path {
    return self.mode == BCXPickerModePanel && path.section == 0;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)style forRowAtIndexPath:(NSIndexPath *)path {
    if (style != UITableViewCellEditingStyleDelete) return;
    NSMutableArray *items = [BCXPanelItemsForKey(self.zoneKey) mutableCopy];
    if (path.row >= items.count) return;
    [items removeObjectAtIndex:path.row];
    BCXSavePanelItemsForKey(self.zoneKey, items);
    [tableView deleteRowsAtIndexPaths:@[path] withRowAnimation:UITableViewRowAnimationAutomatic];
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)path {
    return self.mode == BCXPickerModePanel && path.section == 0;
}

- (NSIndexPath *)tableView:(UITableView *)tableView targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)source toProposedIndexPath:(NSIndexPath *)target {
    return target.section == 0 ? target : source;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)source toIndexPath:(NSIndexPath *)target {
    NSMutableArray *items = [BCXPanelItemsForKey(self.zoneKey) mutableCopy];
    if (source.row >= items.count || target.row >= items.count) return;
    id item = items[source.row];
    [items removeObjectAtIndex:source.row];
    [items insertObject:item atIndex:target.row];
    BCXSavePanelItemsForKey(self.zoneKey, items);
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (self.mode == BCXPickerModePanel) [self.tableView reloadData];
}

@end
