#import "DottoPlusPlusPreferences.h"

NSString *const DottoPlusPlusPreferenceSuite = @"com.nicksworks.dottoplusplus.prefs";
NSString *const DottoPlusPlusReloadNotification = @"com.nicksworks.dottoplusplus/ReloadPrefs";
NSString *const DottoPlusPlusEnabledKey = @"kEnabled";
NSString *const DottoPlusPlusAppearanceStyleKey = @"kAppearanceStyle";
NSString *const DottoPlusPlusSelectedColorKey = @"kSelectedColor";
NSString *const DottoPlusPlusAdaptiveColorKey = @"kAdaptiveColor";
NSString *const DottoPlusPlusTransparencyKey = @"kTransparency";
NSString *const DottoPlusPlusPastelColorKey = @"kUsePastelColor";
NSString *const DottoPlusPlusPerceptualPastelColorKey = @"kPerceptualPastelColor";

@interface DottoPlusPlusPreferences ()
@property (nonatomic, copy) NSDictionary *preferences;
@end

@implementation DottoPlusPlusPreferences

+ (instancetype)sharedInstance {
    static DottoPlusPlusPreferences *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    if ((self = [super init])) {
        [self reloadPreferences];
    }
    return self;
}

- (void)reloadPreferences {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:DottoPlusPlusPreferenceSuite];
    self.preferences = [defaults dictionaryRepresentation];
}

- (void)writeValue:(id)value forKey:(NSString *)key {
    if (!key.length || !value) {
        return;
    }
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:DottoPlusPlusPreferenceSuite];
    [defaults setObject:value forKey:key];
    // Flush this suite through cfprefsd before notifying SpringBoard; unlike
    // NSUserDefaults -synchronize, this is the supported CFPreferences API.
    CFPreferencesAppSynchronize((CFStringRef)DottoPlusPlusPreferenceSuite);
    [self reloadPreferences];
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (CFStringRef)DottoPlusPlusReloadNotification,
                                         NULL, NULL,
                                         kCFNotificationDeliverImmediately |
                                         kCFNotificationPostToAllSessions);
}

- (id)_objectForKey:(NSString *)key {
    return [self.preferences objectForKey:key];
}

- (BOOL)tweakEnabled {
    id value = [self _objectForKey:DottoPlusPlusEnabledKey];
    return value ? [value boolValue] : YES;
}

- (BOOL)adaptiveColorEnabled {
    id value = [self _objectForKey:DottoPlusPlusAdaptiveColorKey];
    return value ? [value boolValue] : YES;
}

- (BOOL)pastelColorsEnabled {
    id value = [self _objectForKey:DottoPlusPlusPastelColorKey];
    return value ? [value boolValue] : NO;
}

- (BOOL)perceptualPastelColorsEnabled {
    id value = [self _objectForKey:DottoPlusPlusPerceptualPastelColorKey];
    return value ? [value boolValue] : NO;
}

- (NSInteger)appearanceStyle {
    id value = [self _objectForKey:DottoPlusPlusAppearanceStyleKey];
    return value ? [value intValue] : 0;
}

- (CGFloat)transparency {
    id value = [self _objectForKey:DottoPlusPlusTransparencyKey];
    CGFloat percentage = value ? [value doubleValue] : 100.0;
    return MIN(MAX(percentage * 0.01, 0.0), 1.0);
}

- (UIColor *)dottoSelectedColour {
    id data = [self _objectForKey:DottoPlusPlusSelectedColorKey];
    if (!data) {
        // Default: #E83553 (232/255, 53/255, 83/255) — the original's constants.
        return [UIColor colorWithRed:232.0 / 255.0 green:53.0 / 255.0 blue:83.0 / 255.0 alpha:1.0];
    }
    UIColor *colour = nil;
    if ([data isKindOfClass:[NSData class]]) {
        // Decodes both our archives and legacy archives written by the 2020 build.
        colour = [NSKeyedUnarchiver unarchivedObjectOfClass:[UIColor class] fromData:data error:NULL];
    }
    return colour ?: [UIColor colorWithRed:232.0 / 255.0 green:53.0 / 255.0 blue:83.0 / 255.0 alpha:1.0];
}

@end
