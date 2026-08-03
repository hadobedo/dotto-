#import <UIKit/UIKit.h>

#import "RGBPixel.h"

// Faithful ports of the original libdottoplus color categories.
@interface UIColor (dotto)

- (UIColor *)lighterColor;
- (UIColor *)darkerColor;
- (UIColor *)pastelColor;

@end

@interface UIImage (dotto)

- (UIColor *)dottoAverageColor;
- (int)dottoColourDistance:(RGBPixel *)pixelA andB:(RGBPixel *)pixelB;

@end
