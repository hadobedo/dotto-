#import <UIKit/UIKit.h>

// Drop-in replacement for the original libdottoplus DottoPlusPlusPreferences singleton.
// Storage: NSUserDefaults suite "com.nicksworks.dottoplusplus.prefs".
FOUNDATION_EXPORT NSString *const DottoPlusPlusPreferenceSuite;
FOUNDATION_EXPORT NSString *const DottoPlusPlusReloadNotification;
FOUNDATION_EXPORT NSString *const DottoPlusPlusEnabledKey;
FOUNDATION_EXPORT NSString *const DottoPlusPlusAppearanceStyleKey;
FOUNDATION_EXPORT NSString *const DottoPlusPlusSelectedColorKey;
FOUNDATION_EXPORT NSString *const DottoPlusPlusAdaptiveColorKey;
FOUNDATION_EXPORT NSString *const DottoPlusPlusTransparencyKey;
FOUNDATION_EXPORT NSString *const DottoPlusPlusPastelColorKey;
FOUNDATION_EXPORT NSString *const DottoPlusPlusPerceptualPastelColorKey;

@interface DottoPlusPlusPreferences : NSObject

+ (instancetype)sharedInstance;

- (void)reloadPreferences;
- (void)writeValue:(id)value forKey:(NSString *)key;

- (BOOL)tweakEnabled;
- (BOOL)adaptiveColorEnabled;
- (BOOL)pastelColorsEnabled;
- (BOOL)perceptualPastelColorsEnabled;
- (UIColor *)dottoSelectedColour;
- (NSInteger)appearanceStyle;
- (CGFloat)transparency;

@end
