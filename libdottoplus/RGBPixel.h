#import <Foundation/Foundation.h>

// Pixel cluster used by [UIImage dottoAverageColor] (original RGBPixel class).
@interface RGBPixel : NSObject

@property (nonatomic, assign) int r;
@property (nonatomic, assign) int g;
@property (nonatomic, assign) int b;
// Dominance count (number of merged source pixels).
@property (nonatomic, assign) int d;

@end
