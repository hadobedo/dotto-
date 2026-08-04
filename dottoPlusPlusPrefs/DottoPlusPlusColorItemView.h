#import <UIKit/UIKit.h>
#import <UIKit/UIColorPickerViewController.h>

#import "DottoPlusPlusPreferences.h"

@class DottoPlusPlusColorRowStackView;

// 30x30 rounded color swatch with selection outline and tap handling.
@interface DottoPlusPlusColorItemView : UIView <UIColorPickerViewControllerDelegate>

@property (nonatomic, strong) UIColor *color;
@property (nonatomic, strong) UITapGestureRecognizer *tapGestureRecognizer;
@property (nonatomic, strong) DottoPlusPlusPreferences *preferences;
@property (nonatomic, strong) UIView *outlineView;
@property (nonatomic, weak) DottoPlusPlusColorRowStackView *hostController;
// 0 = standard color swatch, 1 = custom color picker swatch.
@property (nonatomic, assign) NSInteger type;

- (instancetype)initWithColor:(UIColor *)color
                  forController:(DottoPlusPlusColorRowStackView *)controller;
- (void)addOutlineView;
- (void)updateAdaptiveColorEnabled:(BOOL)adaptiveEnabled;
- (void)buttonTapped:(UITapGestureRecognizer *)sender;
- (void)showColorPicker:(UITapGestureRecognizer *)sender;

@end
