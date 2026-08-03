#import <UIKit/UIKit.h>

#import "DottoPreferences.h"

@class DottoColorSelectionTableCell;

@interface DottoColorRowStackView : UIStackView

// The 11 standard palette colors (shared across rows/cells).
+ (NSArray<UIColor *> *)standardColors;
// The currently selected color (updated by the swatches).
+ (UIColor *)selectedColor;
+ (void)setSelectedColor:(UIColor *)color;

@property (nonatomic, strong) UIColorPickerViewController *colorPicker; // iOS 14+
@property (nonatomic, strong) NSArray<UIColor *> *colors;
@property (nonatomic, weak) DottoColorSelectionTableCell *hostController;
@property (nonatomic, assign) NSInteger indexOfSelected;

- (instancetype)initWithColors:(NSArray<UIColor *> *)colors forController:(id)controller;
- (void)updateCircles;

@end
