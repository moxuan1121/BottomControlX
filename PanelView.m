#import "PanelView.h"
#import "PanelData.h"
#import <QuartzCore/QuartzCore.h>

static UIWindow *panelWindow;
static __weak UIWindow *previousKeyWindow;

@interface BCXPanelController : UIViewController
@property(nonatomic, copy) NSArray<NSDictionary *> *items;
@property(nonatomic, copy) void (^runAction)(NSDictionary *item);
@property(nonatomic, strong) UIView *sheet;
@property(nonatomic, strong) UIControl *shade;
- (void)setRevealProgress:(CGFloat)progress;
@end

@implementation BCXPanelController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.clearColor;
    UIControl *shade = [[UIControl alloc] initWithFrame:self.view.bounds];
    shade.backgroundColor = [UIColor colorWithWhite:0 alpha:0.28];
    shade.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [shade addTarget:self action:@selector(close) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:shade];
    self.shade = shade;

    CGFloat width = self.view.bounds.size.width;
    CGFloat safeBottom = self.view.safeAreaInsets.bottom ?: 24;
    CGFloat iconSize = BCXIconSize();
    CGFloat cellHeight = iconSize + 58;
    NSInteger rows = MAX(1, (self.items.count + 3) / 4);
    CGFloat height = MIN(self.view.bounds.size.height * 0.68, 65 + rows * cellHeight + safeBottom);
    UIView *sheet = [[UIView alloc] initWithFrame:CGRectMake(0, self.view.bounds.size.height - height, width, height)];
    UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial]];
    blur.frame = sheet.bounds;
    blur.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [sheet addSubview:blur];
    sheet.layer.cornerRadius = 26;
    sheet.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    sheet.clipsToBounds = YES;
    sheet.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [self.view addSubview:sheet];
    self.sheet = sheet;

    UILabel *heading = [[UILabel alloc] initWithFrame:CGRectMake(20, 18, width - 40, 30)];
    heading.text = @"快捷面板";
    heading.font = [UIFont boldSystemFontOfSize:18];
    [sheet addSubview:heading];

    UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 57, width, height - 57)];
    scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [sheet addSubview:scroll];
    CGFloat cellWidth = width / 4;
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
        UIControl *tile = [[UIControl alloc] initWithFrame:CGRectMake((i % 4) * cellWidth, (i / 4) * cellHeight, cellWidth, cellHeight)];
        tile.tag = i;
        [tile addTarget:self action:@selector(choose:) forControlEvents:UIControlEventTouchUpInside];
        tile.isAccessibilityElement = YES;
        tile.accessibilityTraits = UIAccessibilityTraitButton;
        tile.accessibilityLabel = item[@"title"];
        UIImage *symbol = BCXItemImage(item, iconSize);
        UIImageView *icon = [[UIImageView alloc] initWithImage:symbol];
        icon.tintColor = UIColor.labelColor;
        icon.contentMode = UIViewContentModeScaleAspectFit;
        icon.frame = CGRectMake((cellWidth - iconSize) / 2, 8, iconSize, iconSize);
        [tile addSubview:icon];
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(4, 14 + iconSize, cellWidth - 8, 38)];
        label.text = item[@"title"];
        label.textAlignment = NSTextAlignmentCenter;
        label.numberOfLines = 2;
        label.font = [UIFont systemFontOfSize:12];
        [tile addSubview:label];
        [scroll addSubview:tile];
    }
    scroll.contentSize = CGSizeMake(width, rows * cellHeight + safeBottom);
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragDown:)];
    [sheet addGestureRecognizer:pan];
    [self setRevealProgress:0];
}

- (void)setRevealProgress:(CGFloat)progress {
    progress = MAX(0, MIN(1, progress));
    self.shade.alpha = progress;
    self.sheet.transform = CGAffineTransformMakeTranslation(0, self.sheet.bounds.size.height * (1 - progress));
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

BOOL BCXBeginPanel(NSArray<NSDictionary *> *items, void (^runAction)(NSDictionary *item)) {
    if (panelWindow) return NO;
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
    panelWindow.hidden = NO;
    panelWindow.userInteractionEnabled = NO;
    return YES;
}

void BCXUpdatePanel(CGFloat dragDistance) {
    if (!panelWindow) return;
    BCXPanelController *controller = (BCXPanelController *)panelWindow.rootViewController;
    [controller setRevealProgress:dragDistance / controller.sheet.bounds.size.height];
}

void BCXFinishPanel(BOOL show) {
    if (!panelWindow) return;
    UIWindow *window = panelWindow;
    if (show) {
        [panelWindow makeKeyWindow];
        panelWindow.userInteractionEnabled = YES;
    }
    [UIView animateWithDuration:0.38 delay:0 usingSpringWithDamping:0.84 initialSpringVelocity:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
        [(BCXPanelController *)window.rootViewController setRevealProgress:show ? 1 : 0];
    } completion:^(BOOL finished) {
        if (!show && panelWindow == window) BCXHidePanel();
    }];
}

void BCXHidePanel(void) {
    if (!panelWindow) return;
    panelWindow.hidden = YES;
    panelWindow.rootViewController = nil;
    panelWindow = nil;
    [previousKeyWindow makeKeyWindow];
    previousKeyWindow = nil;
}
