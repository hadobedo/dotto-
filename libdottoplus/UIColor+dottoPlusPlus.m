#import "UIColor+dottoPlusPlus.h"

#import "RGBPixel.h"

#import <CoreGraphics/CoreGraphics.h>
#import <math.h>
#import <stdint.h>

typedef struct {
    CGFloat L;
    CGFloat a;
    CGFloat b;
} DPPOKLab;

static CGFloat DPPLinearSRGB(CGFloat value) {
    return value <= 0.04045 ? value / 12.92
                            : pow((value + 0.055) / 1.055, 2.4);
}

static CGFloat DPPSRGBFromLinear(CGFloat value) {
    return value <= 0.0031308 ? value * 12.92
                              : 1.055 * pow(value, 1.0 / 2.4) - 0.055;
}

static DPPOKLab DPPOKLabFromRGB(CGFloat red, CGFloat green, CGFloat blue) {
    red = DPPLinearSRGB(red);
    green = DPPLinearSRGB(green);
    blue = DPPLinearSRGB(blue);

    CGFloat l = cbrt(0.4122214708 * red + 0.5363325363 * green + 0.0514459929 * blue);
    CGFloat m = cbrt(0.2119034982 * red + 0.6806995451 * green + 0.1073969566 * blue);
    CGFloat s = cbrt(0.0883024619 * red + 0.2817188376 * green + 0.6299787005 * blue);

    return (DPPOKLab){
        .L = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
        .a = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
        .b = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s,
    };
}

static void DPPLinearRGBFromOKLab(DPPOKLab colour,
                                   CGFloat *red,
                                   CGFloat *green,
                                   CGFloat *blue) {
    CGFloat l = colour.L + 0.3963377774 * colour.a + 0.2158037573 * colour.b;
    CGFloat m = colour.L - 0.1055613458 * colour.a - 0.0638541728 * colour.b;
    CGFloat s = colour.L - 0.0894841775 * colour.a - 1.2914855480 * colour.b;
    l = l * l * l;
    m = m * m * m;
    s = s * s * s;

    *red = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s;
    *green = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s;
    *blue = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s;
}

static BOOL DPPLinearRGBIsInGamut(CGFloat red, CGFloat green, CGFloat blue) {
    const CGFloat epsilon = 0.00001;
    return red >= -epsilon && red <= 1.0 + epsilon &&
           green >= -epsilon && green <= 1.0 + epsilon &&
           blue >= -epsilon && blue <= 1.0 + epsilon;
}

@implementation UIColor (DottoPlusPlus)

- (UIColor *)dpp_faithfulPastelColor {
    CGFloat hue, saturation, brightness, alpha;
    if (![self getHue:&hue saturation:&saturation brightness:&brightness alpha:&alpha]) {
        return nil;
    }
    return [UIColor colorWithHue:hue
                       saturation:saturation
                       brightness:MIN(brightness * 2.0, 1.0)
                            alpha:alpha];
}

- (UIColor *)dpp_oklabPastelColor {
    CGFloat red, green, blue, alpha;
    if (![self getRed:&red green:&green blue:&blue alpha:&alpha]) {
        return nil;
    }

    // Pastel colours are lighter and less chromatic. Scaling a/b together is
    // equivalent to reducing OKLCH chroma while preserving hue. The binary
    // search keeps the result inside sRGB instead of clipping one channel.
    DPPOKLab source = DPPOKLabFromRGB(red, green, blue);
    CGFloat chroma = hypot(source.a, source.b);
    CGFloat hue = atan2(source.b, source.a);
    CGFloat targetLightness = MIN(MAX(source.L + (1.0 - source.L) * 0.35, 0.0), 1.0);
    CGFloat targetChroma = chroma * 0.55;

    DPPOKLab candidate = {
        .L = targetLightness,
        .a = targetChroma * cos(hue),
        .b = targetChroma * sin(hue),
    };
    CGFloat linearRed, linearGreen, linearBlue;
    DPPLinearRGBFromOKLab(candidate, &linearRed, &linearGreen, &linearBlue);

    if (!DPPLinearRGBIsInGamut(linearRed, linearGreen, linearBlue)) {
        CGFloat low = 0.0;
        CGFloat high = targetChroma;
        for (NSUInteger iteration = 0; iteration < 20; iteration++) {
            CGFloat middle = (low + high) * 0.5;
            candidate.a = middle * cos(hue);
            candidate.b = middle * sin(hue);
            DPPLinearRGBFromOKLab(candidate, &linearRed, &linearGreen, &linearBlue);
            if (DPPLinearRGBIsInGamut(linearRed, linearGreen, linearBlue)) {
                low = middle;
            } else {
                high = middle;
            }
        }
        candidate.a = low * cos(hue);
        candidate.b = low * sin(hue);
        DPPLinearRGBFromOKLab(candidate, &linearRed, &linearGreen, &linearBlue);
    }

    if (!DPPLinearRGBIsInGamut(linearRed, linearGreen, linearBlue)) {
        return nil;
    }
    return [UIColor colorWithRed:DPPSRGBFromLinear(MIN(MAX(linearRed, 0.0), 1.0))
                           green:DPPSRGBFromLinear(MIN(MAX(linearGreen, 0.0), 1.0))
                            blue:DPPSRGBFromLinear(MIN(MAX(linearBlue, 0.0), 1.0))
                           alpha:alpha];
}

@end

static int DottoColourDistance(RGBPixel *pixelA, RGBPixel *pixelB) {
    int dr = pixelA.r - pixelB.r;
    int dg = pixelA.g - pixelB.g;
    int db = pixelA.b - pixelB.b;
    return (dr < 0 ? -dr : dr) + (dg < 0 ? -dg : dg) + (db < 0 ? -db : db);
}

static NSArray<RGBPixel *> *DottoClustersFromPixels(const unsigned char *pixels,
                                                      size_t width,
                                                      size_t height,
                                                      BOOL skipExtremes) {
    NSMutableArray<RGBPixel *> *clusters = [NSMutableArray array];
    for (size_t y = 0; y < height; y++) {
        for (size_t x = 0; x < width; x++) {
            size_t offset = (y * width + x) * 4;
            unsigned char alpha = pixels[offset + 3];
            if (alpha < 128) {
                continue;
            }

            unsigned int red = pixels[offset];
            unsigned int green = pixels[offset + 1];
            unsigned int blue = pixels[offset + 2];
            if (skipExtremes) {
                double brightness = (red + green + blue) / (3.0 * 255.0);
                if (brightness < 0.12 || brightness > 0.92) {
                    continue;
                }
            }

            RGBPixel *pixel = [RGBPixel new];
            pixel.r = (int)red;
            pixel.g = (int)green;
            pixel.b = (int)blue;
            pixel.d = 1;

            BOOL merged = NO;
            for (RGBPixel *cluster in clusters) {
                if (DottoColourDistance(pixel, cluster) < 27) {
                    // Preserve the original clustering behavior while keeping
                    // the first source pixel represented by d == 1.
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
    return clusters;
}

static UIColor *DottoColorFromPixel(RGBPixel *pixel) {
    return [UIColor colorWithRed:pixel.r / 255.0
                           green:pixel.g / 255.0
                            blue:pixel.b / 255.0
                           alpha:1.0];
}

@implementation UIImage (DottoPlusPlus)

- (UIColor *)dottoAverageColor {
    CGImageRef cgImage = self.CGImage;
    if (!cgImage) {
        return nil;
    }

    size_t sourceWidth = CGImageGetWidth(cgImage);
    size_t sourceHeight = CGImageGetHeight(cgImage);
    if (sourceWidth == 0 || sourceHeight == 0) {
        return nil;
    }

    size_t width = sourceWidth;
    size_t height = sourceHeight;
    double sourcePixelCount = (double)sourceWidth * (double)sourceHeight;
    if (sourcePixelCount > 2000.0) {
        double scale = sqrt(2000.0 / sourcePixelCount);
        width = MAX((size_t)1, (size_t)floor((double)sourceWidth * scale));
        height = MAX((size_t)1, (size_t)floor((double)sourceHeight * scale));
        while ((double)width * (double)height > 2000.0) {
            if (width >= height && width > 1) {
                width--;
            } else if (height > 1) {
                height--;
            } else {
                break;
            }
        }
    }

    if (height > 0 && width > SIZE_MAX / height / 4) {
        return nil;
    }
    size_t pixelCount = width * height;
    if (pixelCount == 0 || pixelCount > SIZE_MAX / 4) {
        return nil;
    }
    size_t bytesPerRow = width * 4;
    unsigned char *pixels = calloc(pixelCount, 4);
    if (!pixels) {
        return nil;
    }

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pixels,
                                                  width,
                                                  height,
                                                  8,
                                                  bytesPerRow,
                                                  colorSpace,
                                                  kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(colorSpace);
    if (!context) {
        free(pixels);
        return nil;
    }
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), cgImage);
    CGContextRelease(context);

    NSArray<RGBPixel *> *clusters = DottoClustersFromPixels(pixels, width, height, YES);
    if (clusters.count == 0) {
        clusters = DottoClustersFromPixels(pixels, width, height, NO);
    }
    free(pixels);

    if (clusters.count == 0) {
        return nil;
    }
    if (clusters.count == 1) {
        return DottoColorFromPixel(clusters.firstObject);
    }

    NSArray<RGBPixel *> *sorted = [clusters sortedArrayUsingDescriptors:@[
        [NSSortDescriptor sortDescriptorWithKey:@"d" ascending:NO]
    ]];
    RGBPixel *first = sorted.firstObject;
    RGBPixel *second = sorted[1];
    UIColor *firstColor = DottoColorFromPixel(first);
    CGFloat firstSaturation = 0.0;
    CGFloat firstBrightness = 0.0;
    [firstColor getHue:NULL saturation:&firstSaturation brightness:&firstBrightness alpha:NULL];

    UIColor *result = firstColor;
    if (first.d * 0.125 < second.d) {
        UIColor *secondColor = DottoColorFromPixel(second);
        CGFloat secondSaturation = 0.0;
        CGFloat secondBrightness = 0.0;
        [secondColor getHue:NULL saturation:&secondSaturation brightness:&secondBrightness alpha:NULL];
        if (firstSaturation + firstBrightness * 0.5 <
            secondSaturation + secondBrightness * 0.5) {
            result = secondColor;
        }
    }
    return result;
}

@end
