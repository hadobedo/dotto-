#import "DottoPreferences.h"

static NSString *const DottoPrefsSuite = @"me.conorthedev.dotto.prefs";
static NSString *const DottoReloadNotification = @"me.conorthedev.dotto/ReloadPrefs";

static NSString *const kEnabled = @"kEnabled";
static NSString *const kAppearanceStyle = @"kAppearanceStyle";
static NSString *const kSelectedColor = @"kSelectedColor";
static NSString *const kAdaptiveColor = @"kAdaptiveColor";
static NSString *const kTransparency = @"kTransparency";
static NSString *const kUsePastelColor = @"kUsePastelColor";

@implementation DottoPreferences

+ (instancetype)sharedInstance {
    static DottoPreferences *sharedInstance = nil;
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
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:DottoPrefsSuite];
    self.preferences = [defaults dictionaryRepresentation];
}

- (void)writeValue:(id)value forKey:(NSString *)key {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:DottoPrefsSuite];
    [defaults setObject:value forKey:key];
    [defaults synchronize];
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (CFStringRef)DottoReloadNotification,
                                         NULL, NULL,
                                         kCFNotificationDeliverImmediately |
                                         kCFNotificationPostToAllSessions);
    [self reloadPreferences];
}

- (id)_objectForKey:(NSString *)key {
    return [self.preferences objectForKey:key];
}

- (BOOL)tweakEnabled {
    id value = [self _objectForKey:kEnabled];
    return value ? [value boolValue] : YES;
}

- (BOOL)adaptiveColorEnabled {
    id value = [self _objectForKey:kAdaptiveColor];
    return value ? [value boolValue] : YES;
}

- (BOOL)pastelColorsEnabled {
    id value = [self _objectForKey:kUsePastelColor];
    return value ? [value boolValue] : NO;
}

- (NSInteger)appearanceStyle {
    id value = [self _objectForKey:kAppearanceStyle];
    return value ? [value intValue] : 0;
}

- (CGFloat)transparency {
    id value = [self _objectForKey:kTransparency];
    return (value ? [value floatValue] : 100.0f) * 0.01f;
}

- (UIColor *)dottoSelectedColour {
    id data = [self _objectForKey:kSelectedColor];
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
