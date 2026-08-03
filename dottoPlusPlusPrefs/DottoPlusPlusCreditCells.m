#import "DottoPlusPlusCreditCells.h"

@implementation DottoPlusPlusProfileLinkCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier
                    specifier:(PSSpecifier *)specifier {
    if ((self = [super initWithStyle:UITableViewCellStyleDefault
                     reuseIdentifier:reuseIdentifier
                           specifier:specifier])) {
        // Icon comes from the specifier's PSIconImageKey (native path).
        // Blue signals tappability, matching the link row.
        self.imageView.tintColor = [UIColor systemBlueColor];
        self.imageView.contentMode = UIViewContentModeScaleAspectFit;
        self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    return self;
}

@end

@implementation DottoPlusPlusOriginalLinkCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier
                    specifier:(PSSpecifier *)specifier {
    if ((self = [super initWithStyle:UITableViewCellStyleSubtitle
                     reuseIdentifier:reuseIdentifier
                           specifier:specifier])) {
        // Blue link-style title.
        self.textLabel.textColor = [UIColor systemBlueColor];

        // Icon comes from the specifier's PSIconImageKey (native path).
        self.imageView.tintColor = [UIColor systemBlueColor];
        self.imageView.contentMode = UIViewContentModeScaleAspectFit;
        self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

        // Author subtitle (PSTableCell may not map the specifier's "subtitle").
        self.detailTextLabel.text = [specifier propertyForKey:@"subtitle"];
        self.detailTextLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
        self.detailTextLabel.textColor = [UIColor secondaryLabelColor];
        self.detailTextLabel.numberOfLines = 2;
    }
    return self;
}

@end
