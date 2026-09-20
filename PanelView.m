#import "PanelView.h"
#import "PanelData.h"
#import <QuartzCore/QuartzCore.h>

static UIWindow *panelWindow;
static __weak UIWindow *previousKeyWindow;

@interface BCXPanelController : UIViewController
@property(nonatomic, copy) NSArray<NSDictionary *> *items;
@property(nonatomic, copy) void (^runAction)(NSDictionary *item);
@end

@implementation BCXPanelController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0 alpha:0.28];
    UIControl *shade = [[UIControl alloc] initWithFrame:self.view.bounds];
    shade.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [shade addTarget:self action:@selector(close) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:shade];

    CGFloat width = self.view.bounds.size.width;
    CGFloat safeBottom = self.view.safeAreaInsets.bottom ?: 24;
    NSInteger rows = MAX(1, (self.items.count + 3) / 4);
    CGFloat height = MIN(self.view.bounds.size.height * 0.68, 65 + rows * 102 + safeBottom);
    UIView *sheet = [[UIView alloc] initWithFrame:CGRectMake(0, self.view.bounds.size.height - height, width, height)];
    sheet.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    sheet.layer.cornerRadius = 26;
    sheet.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    sheet.clipsToBounds = YES;
    sheet.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [self.view addSubview:sheet];

    UILabel *heading = [[UILabel alloc] initWithFrame:CGRectMake(20, 18, width - 40, 30)];
    heading.text = @"快捷面板";
    heading.font = [UIFont boldSystemFontOfSize:18];
    [sheet addSubview:heading];

    UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 57, width, height - 57)];
    scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [sheet addSubview:scroll];
    CGFloat cellWidth = width / 4;
    CGFloat iconSize = [@[@32, @40, @48][BCXIconSize()] doubleValue];
    if (!self.items.count) {
        UILabel *empty = [[UILabel alloc] initWithFrame:CGRectMake(20, 40, width - 40, 100)];
        empty.text = @"请先在 BottomControlX 设置中添加面板项目";
        empty.numberOfLines = 0;
        empty.textAlignment = NSTextAlignmentCenter;
        empty.textColor = UIColor.secondaryLabelColor;
        [scroll addSubview:empty];
    }
    for (NSInteger i = 0; i < self.items.count; i++) {
        NSDictionary *item = self.items[i];
        UIControl *tile = [[UIControl alloc] initWithFrame:CGRectMake((i % 4) * cellWidth, (i / 4) * 102, cellWidth, 102)];
        tile.tag = i;
        [tile addTarget:self action:@selector(choose:) forControlEvents:UIControlEventTouchUpInside];
        tile.isAccessibilityElement = YES;
        tile.accessibilityTraits = UIAccessibilityTraitButton;
        tile.accessibilityLabel = item[@"title"];
        UIImage *symbol = [UIImage systemImageNamed:BCXSymbol(item)
                                withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:iconSize weight:UIImageSymbolWeightRegular]];
        UIImageView *icon = [[UIImageView alloc] initWithImage:symbol];
        icon.tintColor = UIColor.labelColor;
        icon.contentMode = UIViewContentModeScaleAspectFit;
        icon.frame = CGRectMake((cellWidth - iconSize) / 2, 8, iconSize, iconSize);
        [tile addSubview:icon];
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(4, 61, cellWidth - 8, 34)];
        label.text = item[@"title"];
        label.textAlignment = NSTextAlignmentCenter;
        label.numberOfLines = 2;
        label.font = [UIFont systemFontOfSize:12];
        [tile addSubview:label];
        [scroll addSubview:tile];
    }
    scroll.contentSize = CGSizeMake(width, rows * 102 + safeBottom);
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragDown:)];
    [sheet addGestureRecognizer:pan];
}

- (void)close { BCXHidePanel(); }

- (void)choose:(UIControl *)sender {
    NSDictionary *item = self.items[sender.tag];
    void (^run)(NSDictionary *) = self.runAction;
    BCXHidePanel();
    if (run) run(item);
}

- (void)dragDown:(UIPanGestureRecognizer *)pan {
    if (pan.state == UIGestureRecognizerStateEnded && [pan translationInView:self.view].y > 80) BCXHidePanel();
}

@end

BOOL BCXShowPanel(NSArray<NSDictionary *> *items, void (^runAction)(NSDictionary *item)) {
    if (panelWindow) return YES;
    UIApplication *application = UIApplication.sharedApplication;
    UIWindowScene *scene = nil;
    for (UIScene *candidate in application.connectedScenes) {
        if ([candidate isKindOfClass:UIWindowScene.class] && candidate.activationState == UISceneActivationStateForegroundActive) {
            scene = (UIWindowScene *)candidate;
            break;
        }
    }
    if (!scene) return NO;
    for (UIWindow *window in scene.windows) {
        if (window.isKeyWindow) { previousKeyWindow = window; break; }
    }
    panelWindow = [[UIWindow alloc] initWithWindowScene:scene];
    panelWindow.frame = scene.coordinateSpace.bounds;
    panelWindow.windowLevel = UIWindowLevelAlert + 1;
    BCXPanelController *controller = [BCXPanelController new];
    controller.items = items;
    controller.runAction = runAction;
    panelWindow.rootViewController = controller;
    [panelWindow makeKeyAndVisible];
    return YES;
}

void BCXHidePanel(void) {
    if (!panelWindow) return;
    panelWindow.hidden = YES;
    panelWindow.rootViewController = nil;
    panelWindow = nil;
    [previousKeyWindow makeKeyWindow];
    previousKeyWindow = nil;
}
