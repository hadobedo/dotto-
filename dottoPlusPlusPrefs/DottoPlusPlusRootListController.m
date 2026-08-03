#import "DottoPlusPlusRootListController.h"

#import "DottoPrefsCompat.h"

#import <Preferences/PSSpecifier.h>

static NSString *const kEnabled = @"kEnabled";
static NSString *const kAdaptiveColor = @"kAdaptiveColor";

@implementation DottoPlusPlusRootListController

- (instancetype)init {
    if ((self = [super init])) {
        self.preferences = [DottoPlusPlusPreferences sharedInstance];
        [self.preferences reloadPreferences];

        UISwitch *enabledSwitch = [[UISwitch alloc] init]; // intrinsic sizing
        [enabledSwitch setOn:[self.preferences tweakEnabled] animated:NO];
        [enabledSwitch addTarget:self action:@selector(switchToggled:)
                forControlEvents:UIControlEventValueChanged];
        self.navigationItem.rightBarButtonItem =
            [[UIBarButtonItem alloc] initWithCustomView:enabledSwitch];
    }
    return self;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    PSSpecifier *specifier = [self specifierAtIndexPath:indexPath];
    if ([[specifier propertyForKey:@"key"] isEqualToString:@"kOriginalLink"]) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://repo.dynastic.co/dotto"]
                                           options:@{} completionHandler:nil];
        return;
    }
    [super tableView:tableView didSelectRowAtIndexPath:indexPath];
}

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
        for (PSSpecifier *specifier in _specifiers) {
            NSString *key = [specifier propertyForKey:@"key"];
            if ([key isEqualToString:@"kByRow"]) {
                [specifier setProperty:[self symbolImageNamed:@"person.crop.circle"
                                                        color:[UIColor labelColor]]
                                forKey:PSIconImageKey];
            } else if ([key isEqualToString:@"kOriginalLink"]) {
                [specifier setProperty:[self symbolImageNamed:@"link"
                                                        color:[UIColor systemBlueColor]]
                                forKey:PSIconImageKey];
            }
        }
    }
    return _specifiers;
}

- (UIImage *)symbolImageNamed:(NSString *)name color:(UIColor *)color {
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:20
                                                                                        weight:UIImageSymbolWeightRegular];
    UIImage *image = [UIImage systemImageNamed:name withConfiguration:config];
    return [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

// Credits footer: rendered through the table delegate for the last section
// (PSListController's footerViewClass plist hook does not fire on iOS 17).
// The respring note renders directly beneath the Opacity rows with standard
// footer styling, then the compact credits block follows with no dead space.

- (void)switchToggled:(UISwitch *)sender {
    [self.preferences writeValue:@([sender isOn]) forKey:kEnabled];
}

- (void)setCellForRowAtIndexPath:(NSIndexPath *)indexPath enabled:(BOOL)enabled {
    UITableView *table = [self table];
    UITableViewCell *cell = [self tableView:table cellForRowAtIndexPath:indexPath];
    if (!cell) {
        return;
    }
    [cell setUserInteractionEnabled:enabled];
    [cell.contentView setAlpha:enabled ? 1.0 : 0.439216];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    if ([[specifier propertyForKey:@"key"] isEqualToString:kAdaptiveColor]) {
        // The swatch row (section 2, row 0 — section 0 is the respring note)
        // is greyed out while adaptive colouring is on; the selected colour
        // only matters when it is off.
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:2];
        [self setCellForRowAtIndexPath:indexPath enabled:![value boolValue]];
    }
    [super setPreferenceValue:value specifier:specifier];
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    if ([[specifier propertyForKey:@"key"] isEqualToString:kAdaptiveColor]) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:2];
        [self setCellForRowAtIndexPath:indexPath
                               enabled:![self.preferences adaptiveColorEnabled]];
    }
    return [super readPreferenceValue:specifier];
}

@end
