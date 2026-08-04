#import <UIKit/UIKit.h>

// Namespaced helpers avoid collisions with other injected UIKit categories.
@interface UIColor (DottoPlusPlus)

// Reproduces dotto+ 1.0.6's original lighterColor implementation.
- (UIColor *)dpp_faithfulPastelColor;

// Perceptual pastel transform using OKLab/OKLCH-style lightness/chroma
// adjustments, with sRGB gamut mapping.
- (UIColor *)dpp_oklabPastelColor;

@end

@interface UIImage (DottoPlusPlus)

// Returns nil when no drawable color can be extracted.
- (UIColor *)dottoAverageColor;

@end
