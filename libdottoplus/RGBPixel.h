#import <Foundation/Foundation.h>

// Pixel cluster used by [UIImage dottoAverageColor] (original RGBPixel class).
@interface RGBPixel : NSObject

@property (nonatomic, assign) int r;
@property (nonatomic, assign) int g;
@property (nonatomic, assign) int b;
// Dominance count (number of source pixels represented by this cluster).
// Every created cluster starts at one; merged clusters increment from there.
@property (nonatomic, assign) int d;

@end
