#import "BCXSliderCell.h"
#import <Preferences/PSSpecifier.h>

@implementation BCXSliderCell {
    UISlider *_slider;
    UILabel *_valueLabel;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier specifier:(PSSpecifier *)specifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier specifier:specifier];
    if (!self) return nil;

    _slider = [UISlider new];
    _slider.translatesAutoresizingMaskIntoConstraints = NO;
    [_slider addTarget:self action:@selector(valueChanged:) forControlEvents:UIControlEventValueChanged];
    [self.contentView addSubview:_slider];

    _valueLabel = [UILabel new];
    _valueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _valueLabel.textAlignment = NSTextAlignmentRight;
    _valueLabel.font = [UIFont monospacedDigitSystemFontOfSize:17 weight:UIFontWeightRegular];
    _valueLabel.textColor = UIColor.secondaryLabelColor;
    _valueLabel.userInteractionEnabled = YES;
    [_valueLabel addGestureRecognizer:[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(editValue:)]];
    [self.contentView addSubview:_valueLabel];

    UILayoutGuide *margins = self.layoutMarginsGuide;
    [NSLayoutConstraint activateConstraints:@[
        [_slider.leadingAnchor constraintEqualToAnchor:margins.leadingAnchor],
        [_slider.trailingAnchor constraintEqualToAnchor:_valueLabel.leadingAnchor constant:-12],
        [_slider.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [_valueLabel.trailingAnchor constraintEqualToAnchor:margins.trailingAnchor],
        [_valueLabel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [_valueLabel.widthAnchor constraintEqualToConstant:64],
        [self.contentView.heightAnchor constraintGreaterThanOrEqualToConstant:44],
    ]];
    [self sync];
    return self;
}

- (void)setSpecifier:(PSSpecifier *)specifier {
    [super setSpecifier:specifier];
    [self sync];
}

- (void)refreshCellContentsWithSpecifier:(PSSpecifier *)specifier {
    [super refreshCellContentsWithSpecifier:specifier];
    [self sync];
}

- (void)sync {
    PSSpecifier *specifier = self.specifier;
    if (!specifier || !_slider) return;
    _slider.minimumValue = [[specifier propertyForKey:@"min"] floatValue];
    _slider.maximumValue = [[specifier propertyForKey:@"max"] floatValue];
    id value = [specifier performGetter] ?: [specifier propertyForKey:@"default"];
    _slider.value = [value floatValue];
    [self updateLabel];
}

- (void)updateLabel {
    _valueLabel.text = [NSString stringWithFormat:@"%.2f", round(_slider.value * 100) / 100];
}

- (void)valueChanged:(UISlider *)slider {
    CGFloat value = round(slider.value * 100) / 100;
    slider.value = value;
    [self updateLabel];
    [self.specifier performSetterWithValue:@(value)];
}

- (UIViewController *)presenter {
    UIResponder *responder = self;
    while ((responder = responder.nextResponder))
        if ([responder isKindOfClass:UIViewController.class]) return (UIViewController *)responder;
    return nil;
}

- (void)editValue:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"输入数值" message:@"最多保留两位小数" preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.keyboardType = UIKeyboardTypeDecimalPad;
        field.text = self->_valueLabel.text;
        [field selectAll:nil];
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *text = [alert.textFields.firstObject.text stringByReplacingOccurrencesOfString:@"," withString:@"."];
        NSScanner *scanner = [NSScanner scannerWithString:text];
        double entered = 0;
        if (![scanner scanDouble:&entered] || !scanner.isAtEnd) return;
        self->_slider.value = round(MAX(self->_slider.minimumValue, MIN(self->_slider.maximumValue, entered)) * 100) / 100;
        [self valueChanged:self->_slider];
    }]];
    [[self presenter] presentViewController:alert animated:YES completion:nil];
}

@end
