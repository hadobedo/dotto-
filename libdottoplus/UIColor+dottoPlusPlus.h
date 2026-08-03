#import <UIKit/UIKit.h>

#import "RGBPixel.h"

// Faithful ports of the original libdottoplus color categories.
@interface UIColor (dottoPlusPlus)

- (UIColor *)lighterColor;
- (UIColor *)darkerColor;
- (UIColor *)pastelColor;

@end

@interface UIImage (dottoPlusPlus)

- (UIColor *)dottoAverageColor;
- (int)dottoColourDistance:(RGBPixel *)pixelA andB:(RGBPixel *)pixelB;

@end
