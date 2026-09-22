#import "PanelView.h"
#import "PanelData.h"
#import <QuartzCore/QuartzCore.h>

static UIWindow *panelWindow;
static UIWindow *handleWindow;
static __weak UIWindow *previousKeyWindow;
static void (^handleRunAction)(NSDictionary *item);

@interface BCXPanelController : UIViewController
@property(nonatomic, copy) NSArray<NSDictionary *> *items;
@property(nonatomic, copy) void (^runAction)(NSDictionary *item);
@property(nonatomic) BOOL fromLeft;
@property(nonatomic, strong) UIView *sheet;
@property(nonatomic, strong) UIControl *shade;
- (void)setRevealProgress:(CGFloat)progress;
@end

@interface BCXHandleController : UIViewController
@property(nonatomic, strong) UIView *leftHandle;
@property(nonatomic, strong) UIView *rightHandle;
- (void)reloadHandles;
@end

@interface BCXHandleWindow : UIWindow @end

@implementation BCXHandleWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    BCXHandleController *controller = (BCXHandleController *)self.rootViewController;
    for (UIView *handle in @[controller.leftHandle, controller.rightHandle]) {
        if (!handle.hidden && CGRectContainsPoint(handle.frame, point))
            return [handle hitTest:[handle convertPoint:point fromView:controller.view] withEvent:event];
    }
    return nil;
}
@end

@implementation BCXPanelController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.clearColor;
    UIControl *shade = [[UIControl alloc] initWithFrame:self.view.bounds];
    shade.backgroundColor = [UIColor colorWithWhite:0 alpha:0.24];
    shade.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [shade addTarget:self action:@selector(close) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:shade];
    self.shade = shade;

    UIFont *labelFont = [UIFont systemFontOfSize:11];
    CGFloat width = BCXPanelMinimumWidth();
    for (NSDictionary *item in self.items) {
        CGFloat titleWidth = [item[@"title"] sizeWithAttributes:@{NSFontAttributeName:labelFont}].width + 24;
        width = MAX(width, MIN(280, ceil(titleWidth)));
    }
    CGFloat iconSize = MIN(BCXIconSize(), 46);
    CGFloat cellHeight = iconSize + 42;
    CGFloat safeTop = self.view.safeAreaInsets.top + 12;
    CGFloat safeBottom = self.view.safeAreaInsets.bottom + 12;
    CGFloat height = MIN(24 + self.items.count * cellHeight, self.view.bounds.size.height - safeTop - safeBottom);
    CGFloat y = MAX(safeTop, (self.view.bounds.size.height - height) / 2);
    CGFloat x = self.fromLeft ? 0 : self.view.bounds.size.width - width;
    UIView *sheet = [[UIView alloc] initWithFrame:CGRectMake(x, y, width, height)];
    UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial]];
    blur.frame = sheet.bounds;
    blur.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [sheet addSubview:blur];
    sheet.layer.cornerRadius = 24;
    sheet.layer.maskedCorners = self.fromLeft ? (kCALayerMaxXMinYCorner | kCALayerMaxXMaxYCorner)
                                               : (kCALayerMinXMinYCorner | kCALayerMinXMaxYCorner);
    sheet.clipsToBounds = YES;
    [self.view addSubview:sheet];
    self.sheet = sheet;

    UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:sheet.bounds];
    scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    scroll.showsVerticalScrollIndicator = NO;
    [sheet addSubview:scroll];
    for (NSInteger i = 0; i < self.items.count; i++) {
        NSDictionary *item = self.items[i];
        UIControl *tile = [[UIControl alloc] initWithFrame:CGRectMake(0, 12 + i * cellHeight, width, cellHeight)];
        tile.tag = i;
        [tile addTarget:self action:@selector(choose:) forControlEvents:UIControlEventTouchUpInside];
        tile.isAccessibilityElement = YES;
        tile.accessibilityTraits = UIAccessibilityTraitButton;
        tile.accessibilityLabel = item[@"title"];
        UIImageView *icon = [[UIImageView alloc] initWithImage:BCXItemImage(item, iconSize)];
        icon.tintColor = UIColor.labelColor;
        icon.contentMode = UIViewContentModeScaleAspectFit;
        icon.frame = CGRectMake((width - iconSize) / 2, 2, iconSize, iconSize);
        [tile addSubview:icon];
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(4, iconSize + 6, width - 8, 28)];
        label.text = item[@"title"];
        label.textAlignment = NSTextAlignmentCenter;
        label.numberOfLines = 1;
        label.adjustsFontSizeToFitWidth = YES;
        label.minimumScaleFactor = 0.72;
        label.font = labelFont;
        [tile addSubview:label];
        [scroll addSubview:tile];
    }
    scroll.contentSize = CGSizeMake(width, 24 + self.items.count * cellHeight);
    [sheet addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragOut:)]];
    [self setRevealProgress:0];
}

- (void)setRevealProgress:(CGFloat)progress {
    progress = MAX(0, MIN(1, progress));
    self.shade.alpha = progress;
    CGFloat offset = self.sheet.bounds.size.width * (1 - progress) * (self.fromLeft ? -1 : 1);
    self.sheet.transform = CGAffineTransformMakeTranslation(offset, 0);
}

- (void)close { BCXHidePanel(); }
- (void)choose:(UIControl *)sender {
    NSDictionary *item = self.items[sender.tag];
    void (^run)(NSDictionary *) = self.runAction;
    BCXHidePanel();
    if (run) dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 260 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{ run(item); });
}

- (void)dragOut:(UIPanGestureRecognizer *)pan {
    CGFloat distance = MAX(0, [pan translationInView:self.view].x * (self.fromLeft ? -1 : 1));
    if (pan.state == UIGestureRecognizerStateBegan || pan.state == UIGestureRecognizerStateChanged) {
        [self setRevealProgress:1 - distance / self.sheet.bounds.size.width];
    } else if (pan.state == UIGestureRecognizerStateEnded) {
        CGFloat velocity = [pan velocityInView:self.view].x * (self.fromLeft ? -1 : 1);
        if (distance > 42 || velocity > 600) BCXHidePanel(); else BCXFinishPanel(YES);
    } else if (pan.state == UIGestureRecognizerStateCancelled || pan.state == UIGestureRecognizerStateFailed) {
        BCXFinishPanel(YES);
    }
}
@end

@implementation BCXHandleController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.clearColor;
    self.leftHandle = [self handleFromLeft:YES];
    self.rightHandle = [self handleFromLeft:NO];
    [self.view addSubview:self.leftHandle];
    [self.view addSubview:self.rightHandle];
    [self reloadHandles];
}

- (UIView *)handleFromLeft:(BOOL)fromLeft {
    UIView *touchView = [UIView new];
    touchView.tag = fromLeft ? 1 : 2;
    UIView *pill = [UIView new];
    pill.tag = 10;
    pill.backgroundColor = [UIColor colorWithWhite:0.18 alpha:0.72];
    pill.layer.cornerRadius = 8;
    pill.layer.shadowColor = UIColor.blackColor.CGColor;
    pill.layer.shadowOpacity = 0.22;
    pill.layer.shadowRadius = 3;
    pill.layer.shadowOffset = CGSizeMake(0, 1);
    [touchView addSubview:pill];
    UIView *line = [UIView new];
    line.tag = 11;
    line.backgroundColor = [UIColor colorWithWhite:1 alpha:0.86];
    line.layer.cornerRadius = 1.5;
    [pill addSubview:line];
    [touchView addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragHandle:)]];
    return touchView;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat pillHeight = BCXHandleHeight();
    CGFloat lineWidth = MAX(4, MIN(8, pillHeight * 0.055));
    CGFloat pillWidth = BCXHandleShadowWidth();
    CGFloat touchHeight = pillHeight + 20;
    CGFloat touchWidth = pillWidth + 12;
    CGFloat y = floor(self.view.bounds.size.height * BCXHandlePosition() - touchHeight / 2);
    y = MAX(0, MIN(self.view.bounds.size.height - touchHeight, y));
    self.leftHandle.frame = CGRectMake(0, y, touchWidth, touchHeight);
    self.rightHandle.frame = CGRectMake(self.view.bounds.size.width - touchWidth, y, touchWidth, touchHeight);
    for (UIView *handle in @[self.leftHandle, self.rightHandle]) {
        BOOL left = handle.tag == 1;
        UIView *pill = [handle viewWithTag:10];
        CGFloat shadowPosition = BCXHandleShadowPosition();
        pill.frame = CGRectMake(left ? shadowPosition : touchWidth - pillWidth - shadowPosition, 10, pillWidth, pillHeight);
        pill.layer.cornerRadius = pillWidth / 2;
        UIView *line = [pill viewWithTag:11];
        CGFloat lineHeight = pillHeight * 0.9;
        CGFloat indicatorPosition = BCXHandleIndicatorPosition();
        CGFloat lineX = (pillWidth - lineWidth) / 2 + (left ? indicatorPosition : -indicatorPosition);
        line.frame = CGRectMake(lineX, (pillHeight - lineHeight) / 2, lineWidth, lineHeight);
        line.layer.cornerRadius = lineWidth / 2;
    }
    [self reloadHandles];
}

- (void)reloadHandles {
    BOOL portrait = self.view.bounds.size.height > self.view.bounds.size.width;
    self.leftHandle.hidden = !portrait || BCXPanelItemsForKey(BCX_LEFT_ITEMS).count == 0;
    self.rightHandle.hidden = !portrait || BCXPanelItemsForKey(BCX_RIGHT_ITEMS).count == 0;
}

- (void)dragHandle:(UIPanGestureRecognizer *)pan {
    BOOL fromLeft = pan.view.tag == 1;
    CGFloat distance = [pan translationInView:self.view].x * (fromLeft ? 1 : -1);
    if (pan.state == UIGestureRecognizerStateBegan) {
        NSArray *items = BCXPanelItemsForKey(fromLeft ? BCX_LEFT_ITEMS : BCX_RIGHT_ITEMS);
        if (!items.count || !BCXBeginSidePanel(items, fromLeft, handleRunAction)) { pan.enabled = NO; pan.enabled = YES; return; }
    }
    if (pan.state == UIGestureRecognizerStateBegan || pan.state == UIGestureRecognizerStateChanged) {
        BCXUpdatePanel(MAX(0, distance));
    } else if (pan.state == UIGestureRecognizerStateEnded) {
        CGFloat velocity = [pan velocityInView:self.view].x * (fromLeft ? 1 : -1);
        BCXFinishPanel(distance >= 40 || velocity >= 600);
    } else if (pan.state == UIGestureRecognizerStateCancelled || pan.state == UIGestureRecognizerStateFailed) {
        BCXFinishPanel(NO);
    }
}
@end

void BCXConfigureSideHandles(BOOL enabled, void (^runAction)(NSDictionary *item)) {
    handleRunAction = [runAction copy];
    if (!enabled) { BCXHidePanel(); handleWindow.hidden = YES; handleWindow = nil; return; }
    UIWindowScene *scene = nil;
    for (UIScene *candidate in UIApplication.sharedApplication.connectedScenes) {
        if ([candidate isKindOfClass:UIWindowScene.class] && candidate.activationState == UISceneActivationStateForegroundActive) { scene = (UIWindowScene *)candidate; break; }
    }
    if (!scene) return;
    if (!handleWindow) {
        handleWindow = [[BCXHandleWindow alloc] initWithWindowScene:scene];
        handleWindow.frame = scene.coordinateSpace.bounds;
        handleWindow.windowLevel = UIWindowLevelStatusBar + 1;
        handleWindow.backgroundColor = UIColor.clearColor;
        handleWindow.rootViewController = [BCXHandleController new];
    }
    (void)handleWindow.rootViewController.view;
    BCXHandleController *controller = (BCXHandleController *)handleWindow.rootViewController;
    [controller.view setNeedsLayout];
    [controller.view layoutIfNeeded];
    [controller reloadHandles];
    handleWindow.hidden = NO;
}

BOOL BCXBeginSidePanel(NSArray<NSDictionary *> *items, BOOL fromLeft, void (^runAction)(NSDictionary *item)) {
    if (panelWindow || !items.count || !handleWindow.windowScene) return NO;
    UIWindowScene *scene = handleWindow.windowScene;
    for (UIWindow *window in scene.windows) if (window.isKeyWindow) { previousKeyWindow = window; break; }
    panelWindow = [[UIWindow alloc] initWithWindowScene:scene];
    panelWindow.frame = scene.coordinateSpace.bounds;
    panelWindow.windowLevel = UIWindowLevelAlert + 1;
    BCXPanelController *controller = [BCXPanelController new];
    controller.items = items;
    controller.runAction = runAction;
    controller.fromLeft = fromLeft;
    panelWindow.rootViewController = controller;
    (void)controller.view;
    panelWindow.hidden = NO;
    panelWindow.userInteractionEnabled = NO;
    [handleWindow.rootViewController.view.layer removeAllAnimations];
    handleWindow.rootViewController.view.alpha = 1;
    BCXHandleController *handles = (BCXHandleController *)handleWindow.rootViewController;
    for (UIView *handle in @[handles.leftHandle, handles.rightHandle]) {
        UIView *pill = [handle viewWithTag:10];
        [pill.layer removeAllAnimations];
        pill.transform = CGAffineTransformIdentity;
    }
    return YES;
}

void BCXUpdatePanel(CGFloat dragDistance) {
    if (!panelWindow) return;
    BCXPanelController *controller = (BCXPanelController *)panelWindow.rootViewController;
    [controller setRevealProgress:dragDistance / controller.sheet.bounds.size.width];
}

void BCXFinishPanel(BOOL show) {
    if (!panelWindow) return;
    UIWindow *window = panelWindow;
    if (show) {
        handleWindow.hidden = YES;
        [window makeKeyWindow];
        window.userInteractionEnabled = YES;
    }
    void (^animations)(void) = ^{ [(BCXPanelController *)window.rootViewController setRevealProgress:show ? 1 : 0]; };
    void (^completion)(BOOL) = ^(BOOL finished) {
        if (!show && panelWindow == window) {
            panelWindow.hidden = YES;
            panelWindow.rootViewController = nil;
            panelWindow = nil;
            [previousKeyWindow makeKeyWindow];
            previousKeyWindow = nil;
            BCXHandleController *handles = (BCXHandleController *)handleWindow.rootViewController;
            [handles reloadHandles];
            [handles.view layoutIfNeeded];
            for (UIView *handle in @[handles.leftHandle, handles.rightHandle]) {
                UIView *pill = [handle viewWithTag:10];
                CGFloat distance = handle.bounds.size.width + pill.bounds.size.width + 12;
                pill.transform = CGAffineTransformMakeTranslation(handle.tag == 1 ? -distance : distance, 0);
            }
            handleWindow.hidden = NO;
            [UIView animateWithDuration:UIAccessibilityIsReduceMotionEnabled() ? 0 : 0.28
                delay:0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                animations:^{
                    [handles.leftHandle viewWithTag:10].transform = CGAffineTransformIdentity;
                    [handles.rightHandle viewWithTag:10].transform = CGAffineTransformIdentity;
                } completion:nil];
        }
    };
    [UIView animateWithDuration:show ? 0.34 : 0.24 delay:0 usingSpringWithDamping:show ? 0.86 : 1
        initialSpringVelocity:0 options:UIViewAnimationOptionBeginFromCurrentState animations:animations completion:completion];
}

void BCXHidePanel(void) { if (panelWindow) BCXFinishPanel(NO); }
