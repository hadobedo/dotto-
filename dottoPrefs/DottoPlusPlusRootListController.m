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

        UISwitch *enabledSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(0, 0, 51, 30)];
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

// Credits footer: PSListController's footerViewClass plist hook did not render
// on iOS 17, so install the footer through the table delegate instead.
- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    if (section == tableView.numberOfSections - 1) {
        static UIView *creditsView = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            creditsView = [[DottoPlusPlusCreditsFooterView alloc] initWithSpecifier:nil];
        });
        return creditsView;
    }
    if ([super respondsToSelector:@selector(tableView:viewForFooterInSection:)]) {
        return [super tableView:tableView viewForFooterInSection:section];
    }
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    if (section == tableView.numberOfSections - 1) {
        return 292;
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
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:2 inSection:0];
        [self setCellForRowAtIndexPath:indexPath enabled:![value boolValue]];
    }
    [super setPreferenceValue:value specifier:specifier];
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    if ([[specifier propertyForKey:@"key"] isEqualToString:kAdaptiveColor]) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:2 inSection:0];
        [self setCellForRowAtIndexPath:indexPath
                               enabled:![self.preferences adaptiveColorEnabled]];
    }
    return [super readPreferenceValue:specifier];
}

@end
