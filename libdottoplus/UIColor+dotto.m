#import "UIColor+dotto.h"

#import <CoreGraphics/CoreGraphics.h>
#import <math.h>

@implementation UIColor (dotto)

- (UIColor *)lighterColor {
    CGFloat hue, saturation, brightness, alpha;
    if (![self getHue:&hue saturation:&saturation brightness:&brightness alpha:&alpha]) {
        return nil;
    }
    return [UIColor colorWithHue:hue saturation:saturation
                       brightness:MIN(brightness * 2.0, 1.0) alpha:alpha];
}

- (UIColor *)darkerColor {
    CGFloat hue, saturation, brightness, alpha;
    if (![self getHue:&hue saturation:&saturation brightness:&brightness alpha:&alpha]) {
        return nil;
    }
    return [UIColor colorWithHue:hue saturation:saturation
                       brightness:brightness * 0.75 alpha:alpha];
}

- (UIColor *)pastelColor {
    CGFloat red, green, blue, alpha;
    if (![self getRed:&red green:&green blue:&blue alpha:&alpha]) {
        return nil;
    }
    return [UIColor colorWithRed:(red + 1.0) / 3.0
                           green:(green + 1.0) / 3.0
                            blue:(blue + 1.0) / 3.0
                           alpha:alpha];
}

@end

@implementation UIImage (dotto)

- (int)dottoColourDistance:(RGBPixel *)pixelA andB:(RGBPixel *)pixelB {
    int dr = pixelA.r - pixelB.r;
    int dg = pixelA.g - pixelB.g;
    int db = pixelA.b - pixelB.b;
    return (dr < 0 ? -dr : dr) + (dg < 0 ? -dg : dg) + (db < 0 ? -db : db);
}

- (UIColor *)dottoAverageColor {
    NSInteger width = (NSInteger)self.size.width;
    NSInteger height = (NSInteger)self.size.height;

    // Downsample to at most ~2000 pixels, preserving aspect ratio (original math:
    // width = sqrt(ratio * 2000), height = 2000 / width, ratio = width / height).
    if (2000 < width * height) {
        NSInteger ratio = height ? width / height : 1;
        width = (NSInteger)sqrt((double)ratio * 2000.0);
        height = (NSInteger)(2000.0 / sqrt((double)ratio * 2000.0));
    }

    CGImageRef cgImage = self.CGImage;
    if (!cgImage || width <= 0 || height <= 0) {
        return [UIColor redColor];
    }

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    unsigned char *pixels = calloc((size_t)width * (size_t)height * 4, sizeof(unsigned char));
    if (!pixels) {
        CGColorSpaceRelease(colorSpace);
        return [UIColor redColor];
    }
    CGContextRef context = CGBitmapContextCreate(pixels, (size_t)width, (size_t)height, 8,
                                                 (size_t)width * 4, colorSpace,
                                                 kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(colorSpace);
    if (!context) {
        free(pixels);
        return [UIColor redColor];
    }
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), cgImage);
    CGContextRelease(context);

    NSMutableArray<RGBPixel *> *clusters = [NSMutableArray array];
    for (NSInteger y = 0; y < height; y++) {
        for (NSInteger x = 0; x < width; x++) {
            NSUInteger offset = ((NSUInteger)y * (NSUInteger)width + (NSUInteger)x) * 4;
            // Opaque pixels only (alpha >= 128; the original tests the signed byte < 0).
            if ((char)pixels[offset + 3] < 0) {
                RGBPixel *pixel = [RGBPixel new];
                pixel.r = pixels[offset];
                pixel.g = pixels[offset + 1];
                pixel.b = pixels[offset + 2];
                BOOL merged = NO;
                for (RGBPixel *cluster in clusters) {
                    if ([self dottoColourDistance:pixel andB:cluster] < 27) {
                        // Original: (existing + pixel) >> 1 (floor half).
                        cluster.r = (cluster.r + pixel.r) / 2;
                        cluster.g = (cluster.g + pixel.g) / 2;
                        cluster.b = (cluster.b + pixel.b) / 2;
                        cluster.d += 1;
                        merged = YES;
                        break;
                    }
                }
                if (!merged) {
                    [clusters addObject:pixel];
                }
            }
        }
    }
    free(pixels);

    if (clusters.count < 2) {
        return [UIColor redColor];
    }

    NSArray<RGBPixel *> *sorted = [clusters sortedArrayUsingDescriptors:@[
        [NSSortDescriptor sortDescriptorWithKey:@"d" ascending:NO]
    ]];
    RGBPixel *first = sorted[0];
    RGBPixel *second = sorted[1];

    UIColor *firstColour = [UIColor colorWithRed:first.r / 255.0 green:first.g / 255.0
                                            blue:first.b / 255.0 alpha:1.0];
    CGFloat firstSaturation, firstBrightness;
    [firstColour getHue:NULL saturation:&firstSaturation brightness:&firstBrightness alpha:NULL];

    UIColor *result = firstColour;
    if (first.d * 0.125 < second.d) {
        UIColor *secondColour = [UIColor colorWithRed:second.r / 255.0 green:second.g / 255.0
                                                 blue:second.b / 255.0 alpha:1.0];
        CGFloat secondSaturation, secondBrightness;
        [secondColour getHue:NULL saturation:&secondSaturation brightness:&secondBrightness alpha:NULL];
        if (firstSaturation + firstBrightness * 0.5 < secondSaturation + secondBrightness * 0.5) {
            result = secondColour;
        }
    }
    return result;
}

@end
