#import <UIKit/UIKit.h>

#import "DottoPlusPlusPreferences.h"

@class DottoPlusPlusColorSelectionTableCell;

@interface DottoPlusPlusColorRowStackView : UIStackView

// The 11 standard palette colors (shared across rows/cells).
+ (NSArray<UIColor *> *)standardColors;

@property (nonatomic, weak) DottoPlusPlusColorSelectionTableCell *hostController;

- (instancetype)initWithColors:(NSArray<UIColor *> *)colors
                  forController:(DottoPlusPlusColorSelectionTableCell *)controller;
- (void)updateCircles;

@end
