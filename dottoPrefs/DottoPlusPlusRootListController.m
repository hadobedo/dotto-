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

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

// Credits footer: rendered through the table delegate for the last section
// (PSListController's footerViewClass plist hook does not fire on iOS 17).
// The respring note renders directly beneath the Opacity rows with standard
// footer styling, then the compact credits block follows with no dead space.
- (DottoPlusPlusCreditsFooterView *)combinedCreditsFooter {
    static DottoPlusPlusCreditsFooterView *credits = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        credits = (DottoPlusPlusCreditsFooterView *)[[DottoPlusPlusCreditsFooterView alloc] initWithSpecifier:nil];
    });
    return credits;
}

// Credits footer: rendered through the table delegate for the last section
// (PSListController's footerViewClass plist hook does not fire on iOS 17).
// The respring note lives at the top of the page as the first group's footer.
- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    if (section == tableView.numberOfSections - 1) {
        DottoPlusPlusCreditsFooterView *footer = [self combinedCreditsFooter];
        [footer setCardInset:tableView.layoutMargins.left];
        return footer;
    }
    if ([super respondsToSelector:@selector(tableView:viewForFooterInSection:)]) {
        return [super tableView:tableView viewForFooterInSection:section];
    }
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    if (section == tableView.numberOfSections - 1) {
        return [[self combinedCreditsFooter] preferredHeightForWidth:CGRectGetWidth(tableView.bounds)];
    }
    if ([super respondsToSelector:@selector(tableView:heightForFooterInSection:)]) {
        return [super tableView:tableView heightForFooterInSection:section];
    }
    return UITableViewAutomaticDimension;
}

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
