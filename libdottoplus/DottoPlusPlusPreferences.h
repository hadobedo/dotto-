#import <UIKit/UIKit.h>

// Drop-in replacement for the original libdottoplus DottoPlusPlusPreferences singleton.
// Storage: NSUserDefaults suite "com.nicksworks.dottoplusplus.prefs".
@interface DottoPlusPlusPreferences : NSObject

@property (nonatomic, strong) NSDictionary *preferences;

+ (instancetype)sharedInstance;

- (void)reloadPreferences;
- (void)writeValue:(id)value forKey:(NSString *)key;

- (BOOL)tweakEnabled;
- (BOOL)adaptiveColorEnabled;
- (BOOL)pastelColorsEnabled;
- (UIColor *)dottoSelectedColour;
- (NSInteger)appearanceStyle;
- (CGFloat)transparency;

@end
