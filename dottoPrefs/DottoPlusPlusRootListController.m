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

// Credits footer: rendered through the table delegate for the last section
// (PSListController's footerViewClass plist hook does not fire on iOS 17).
// The respring note renders directly beneath the Opacity rows with standard
// footer styling, then the compact credits block follows with no dead space.
- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    if (section == tableView.numberOfSections - 1) {
        static UIView *combinedFooter = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            UILabel *note = [[UILabel alloc] init];
            note.text = @"A respring is recommended after disabling.";
            note.font = [UIFont systemFontOfSize:13];
            note.textColor = [UIColor secondaryLabelColor];
            note.textAlignment = NSTextAlignmentCenter;
            note.numberOfLines = 0;
            note.translatesAutoresizingMaskIntoConstraints = NO;

            UIView *credits = (UIView *)[[DottoPlusPlusCreditsFooterView alloc] initWithSpecifier:nil];
            credits.translatesAutoresizingMaskIntoConstraints = NO;

            UIView *container = [[UIView alloc] init];
            [container addSubview:note];
            [container addSubview:credits];
            [NSLayoutConstraint activateConstraints:@[
                [note.topAnchor constraintEqualToAnchor:container.topAnchor],
                [note.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:16],
                [note.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-16],
                [credits.topAnchor constraintEqualToAnchor:note.bottomAnchor constant:8],
                [credits.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
                [credits.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
                [credits.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
            ]];
            combinedFooter = container;
        });
        return combinedFooter;
    }
    if ([super respondsToSelector:@selector(tableView:viewForFooterInSection:)]) {
        return [super tableView:tableView viewForFooterInSection:section];
    }
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    if (section == tableView.numberOfSections - 1) {
        return 174 + 22 + 8;
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
