#import "DottoColorItemView.h"

#import "DottoColorRowStackView.h"

#import <UIKit/UIColorPickerViewController.h>
#import <math.h>

static NSString *const kSelectedColor = @"kSelectedColor";
static NSString *const kColourPickerImagePath =
    @"/Library/PreferenceBundles/dottoPrefs.bundle/colourpicker.png";

// Native replacement for libcolorpicker's hexFromColor:/LCPParseColorString:
// round-trips a color through #RRGGBB so dynamic/system colors become concrete.
static NSString *DottoHexStringFromColor(UIColor *color) {
    CGFloat red, green, blue, alpha;
    if (![color getRed:&red green:&green blue:&blue alpha:&alpha]) {
        return nil;
    }
    return [NSString stringWithFormat:@"#%02X%02X%02X",
            (int)lround(red * 255.0), (int)lround(green * 255.0), (int)lround(blue * 255.0)];
}

static UIColor *DottoColorFromHexString(NSString *hexString) {
    NSString *hex = [hexString stringByTrimmingCharactersInSet:
                     [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([hex hasPrefix:@"#"]) {
        hex = [hex substringFromIndex:1];
    }
    if (hex.length != 6) {
        return nil;
    }
    unsigned int value = 0;
    NSScanner *scanner = [NSScanner scannerWithString:hex];
    if (![scanner scanHexInt:&value] || ![scanner isAtEnd]) {
        return nil;
    }
    return [UIColor colorWithRed:((value >> 16) & 0xFF) / 255.0
                           green:((value >> 8) & 0xFF) / 255.0
                            blue:(value & 0xFF) / 255.0
                           alpha:1.0];
}

@implementation DottoColorItemView

- (instancetype)initWithColor:(UIColor *)color forController:(id)controller {
    if ((self = [super initWithFrame:CGRectMake(0, 0, 30, 30)])) {
        self.hostController = controller;
        self.layer.cornerRadius = 15.0;

        self.preferences = [DottoPreferences sharedInstance];
        [self.preferences reloadPreferences];
        UIColor *selectedColour = [self.preferences dottoSelectedColour];

        if (![color isEqual:[UIColor clearColor]]) {
            self.backgroundColor = color;
            self.color = color;

            if (![selectedColour isEqual:self.color]) {
                [self.outlineView removeFromSuperview];
            } else {
                [self addOutlineView];
            }

            // Main border.
            UIColor *borderColor = [UIColor.systemBackgroundColor colorWithAlphaComponent:0.2];
            self.layer.borderColor = borderColor.CGColor;
            self.layer.borderWidth = 0.75;

            self.tapGestureRecognizer = [[UITapGestureRecognizer alloc]
                                         initWithTarget:self action:@selector(buttonTapped:)];
            [self addGestureRecognizer:self.tapGestureRecognizer];
            self.type = 0;
        } else {
            // Custom color picker swatch.
            UIImageView *imageView = [[UIImageView alloc]
                                      initWithImage:[UIImage imageWithContentsOfFile:kColourPickerImagePath]];
            [imageView setFrame:CGRectMake(0, 0, 30, 30)];
            [imageView setContentMode:UIViewContentModeScaleAspectFit];
            [self addSubview:imageView];
            [self sendSubviewToBack:imageView];

            self.tapGestureRecognizer = [[UITapGestureRecognizer alloc]
                                         initWithTarget:self action:@selector(showColorPicker:)];
            [self addGestureRecognizer:self.tapGestureRecognizer];

            if (![[DottoColorRowStackView standardColors] containsObject:selectedColour]) {
                [self addOutlineView];
            } else {
                [self.outlineView removeFromSuperview];
            }
            self.type = 1;
        }
    }
    return self;
}

- (void)addOutlineView {
    self.outlineView = [[UIView alloc] initWithFrame:CGRectMake(2.5, 2.5, 25, 25)];
    self.outlineView.layer.cornerRadius = 12.5;
    self.outlineView.layer.borderWidth = 2.5;

    UIColor *outlineColor = [UIColor systemBackgroundColor];
    if ([self.color isEqual:[UIColor colorWithRed:17.0 / 255.0 green:17.0 / 255.0
                                             blue:17.0 / 255.0 alpha:1.0]]) {
        outlineColor = [UIColor whiteColor];
    } else if ([self.color isEqual:[UIColor whiteColor]]) {
        outlineColor = [UIColor colorWithRed:20.0 / 255.0 green:20.0 / 255.0
                                        blue:20.0 / 255.0 alpha:1.0];
    }
    self.outlineView.layer.borderColor = outlineColor.CGColor;
    [self addSubview:self.outlineView];
}

- (void)buttonTapped:(UITapGestureRecognizer *)sender {
    NSData *archivedColour = [NSKeyedArchiver archivedDataWithRootObject:self.color
                                                  requiringSecureCoding:NO error:NULL];
    [self.preferences writeValue:archivedColour forKey:kSelectedColor];
    [DottoColorRowStackView setSelectedColor:self.color];
    [self.hostController updateCircles];
}

- (void)showColorPicker:(UITapGestureRecognizer *)sender {
    UIColorPickerViewController *picker = self.hostController.colorPicker;
    picker.delegate = self;
    picker.selectedColor = [self.preferences dottoSelectedColour];

    UIViewController *presenter = nil;
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]] &&
            scene.activationState == UISceneActivationStateForegroundActive) {
            presenter = [(UIWindowScene *)scene keyWindow].rootViewController;
            if (presenter) {
                break;
            }
        }
    }
    while (presenter.presentedViewController) {
        presenter = presenter.presentedViewController;
    }
    [presenter presentViewController:picker animated:YES completion:nil];
}

#pragma mark - UIColorPickerViewControllerDelegate

- (void)colorPickerViewControllerDidSelectColor:(UIColorPickerViewController *)viewController {
    [self didApplyiOS14ColorPicker:viewController];
}

- (void)colorPickerViewControllerDidFinish:(UIColorPickerViewController *)viewController {
    [self didApplyiOS14ColorPicker:viewController];
}

- (void)didApplyiOS14ColorPicker:(UIColorPickerViewController *)viewController {
    UIColor *pickedColor = viewController.selectedColor;
    NSString *hex = DottoHexStringFromColor(pickedColor);
    UIColor *normalized = hex ? DottoColorFromHexString(hex) : pickedColor;
    NSData *archivedColour = [NSKeyedArchiver archivedDataWithRootObject:normalized
                                                  requiringSecureCoding:NO error:NULL];
    [self.preferences writeValue:archivedColour forKey:kSelectedColor];
    [DottoColorRowStackView setSelectedColor:pickedColor];
    [self.hostController updateCircles];
}

@end
