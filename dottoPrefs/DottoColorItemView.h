#import <UIKit/UIKit.h>
#import <UIKit/UIColorPickerViewController.h>

#import "DottoPreferences.h"

@class DottoColorRowStackView;

// 30x30 rounded color swatch with selection outline and tap handling.
@interface DottoColorItemView : UIView <UIColorPickerViewControllerDelegate>

@property (nonatomic, strong) UIColor *color;
@property (nonatomic, strong) UITapGestureRecognizer *tapGestureRecognizer;
@property (nonatomic, strong) DottoPreferences *preferences;
@property (nonatomic, strong) UIView *outlineView;
@property (nonatomic, weak) DottoColorRowStackView *hostController;
// 0 = standard color swatch, 1 = custom color picker swatch.
@property (nonatomic, assign) NSInteger type;

- (instancetype)initWithColor:(UIColor *)color forController:(id)controller;
- (void)addOutlineView;
- (void)buttonTapped:(UITapGestureRecognizer *)sender;
- (void)showColorPicker:(UITapGestureRecognizer *)sender;

@end
