#import "DottoPlusPlusRootListController.h"

#import "DottoPlusPlusLocalization.h"
#import "DottoPlusPlusColorSelectionTableCell.h"

#import <Preferences/PSSpecifier.h>

@interface DottoPlusPlusRootListController ()
@property (nonatomic, strong) PSSpecifier *pastelSpecifier;
@property (nonatomic, strong) PSSpecifier *perceptualPastelSpecifier;
@end

@implementation DottoPlusPlusRootListController

- (instancetype)init {
    if ((self = [super init])) {
        self.preferences = [DottoPlusPlusPreferences sharedInstance];
        [self.preferences reloadPreferences];

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
            [self localizeSpecifier:specifier];
            NSString *key = [specifier propertyForKey:@"key"];
            if ([key isEqualToString:@"kByRow"]) {
                [specifier setProperty:[self symbolImageNamed:@"person.crop.circle"]
                                forKey:PSIconImageKey];
            } else if ([key isEqualToString:@"kOriginalLink"]) {
                [specifier setProperty:[self symbolImageNamed:@"link"]
                                forKey:PSIconImageKey];
            } else if ([key isEqualToString:DottoPlusPlusPastelColorKey]) {
                self.pastelSpecifier = specifier;
            } else if ([key isEqualToString:DottoPlusPlusPerceptualPastelColorKey]) {
                self.perceptualPastelSpecifier = specifier;
            }
        }
        if (![self.preferences pastelColorsEnabled] && self.perceptualPastelSpecifier) {
            [_specifiers removeObject:self.perceptualPastelSpecifier];
        }
    }
    return _specifiers;
}

- (void)updatePerceptualPastelSpecifierVisibilityAnimated:(BOOL)animated {
    if (!self.perceptualPastelSpecifier || !self.specifiers) {
        return;
    }

    BOOL shouldShow = [self.preferences pastelColorsEnabled];
    BOOL isShown = [self.specifiers containsObject:self.perceptualPastelSpecifier];
    if (shouldShow && !isShown && self.pastelSpecifier) {
        [self insertSpecifier:self.perceptualPastelSpecifier
          afterSpecifier:self.pastelSpecifier
                  animated:animated];
    } else if (!shouldShow && isShown) {
        [self removeSpecifier:self.perceptualPastelSpecifier animated:animated];
    }
}

// Replace plist-driven labels with the bundle's localized strings. Group
// headers/footers and row subtitles ride along as specifier properties.
- (void)localizeSpecifier:(PSSpecifier *)specifier {
    NSString *name = [specifier name];
    if (name.length > 0) {
        [specifier setName:DottoL(name)];
    }
    NSString *subtitle = [specifier propertyForKey:@"subtitle"];
    if (subtitle.length > 0) {
        [specifier setProperty:DottoL(subtitle) forKey:@"subtitle"];
    }
    NSString *footer = [specifier propertyForKey:PSFooterTextGroupKey];
    if (footer.length > 0) {
        [specifier setProperty:DottoL(footer) forKey:PSFooterTextGroupKey];
    }
}

- (UIImage *)symbolImageNamed:(NSString *)name {
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:20
                                                                                        weight:UIImageSymbolWeightRegular];
    UIImage *image = [UIImage systemImageNamed:name withConfiguration:config];
    return [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

// Credits footer: rendered through the table delegate for the last section
// (PSListController's footerViewClass plist hook does not fire on iOS 17).

- (void)updateVisibleColorCellsWithAdaptiveEnabled:(BOOL)adaptiveEnabled {
    UITableView *table = self.table;
    if (!table) {
        return;
    }
    for (NSIndexPath *indexPath in table.indexPathsForVisibleRows) {
        UITableViewCell *cell = [table cellForRowAtIndexPath:indexPath];
        if ([cell isKindOfClass:[DottoPlusPlusColorSelectionTableCell class]]) {
            [(DottoPlusPlusColorSelectionTableCell *)cell updateAdaptiveColorEnabled:adaptiveEnabled];
        }
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.preferences reloadPreferences];
    [self updatePerceptualPastelSpecifierVisibilityAnimated:NO];
    [self updateVisibleColorCellsWithAdaptiveEnabled:[self.preferences adaptiveColorEnabled]];
}

- (void)tableView:(UITableView *)tableView
 willDisplayCell:(UITableViewCell *)cell
forRowAtIndexPath:(NSIndexPath *)indexPath {
    (void)tableView;
    (void)indexPath;
    if ([cell isKindOfClass:[DottoPlusPlusColorSelectionTableCell class]]) {
        [self.preferences reloadPreferences];
        [(DottoPlusPlusColorSelectionTableCell *)cell
            updateAdaptiveColorEnabled:[self.preferences adaptiveColorEnabled]];
    }
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    [super setPreferenceValue:value specifier:specifier];
    if ([key isEqualToString:DottoPlusPlusPastelColorKey]) {
        [self.preferences reloadPreferences];
        [self updatePerceptualPastelSpecifierVisibilityAnimated:YES];
    } else if ([key isEqualToString:DottoPlusPlusAdaptiveColorKey]) {
        [self.preferences reloadPreferences];
        [self updateVisibleColorCellsWithAdaptiveEnabled:[self.preferences adaptiveColorEnabled]];
    }
}

@end
