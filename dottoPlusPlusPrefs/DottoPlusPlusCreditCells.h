#import <Preferences/PSTableCell.h>
#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>

// Profile-style row for "By: Nick's Works": default headshot icon, chevron.
@interface DottoPlusPlusProfileLinkCell : PSTableCell
@end

// Blue link-style row for "Original tweak (dotto+)": link icon, blue title,
// author subtitle, chevron.
@interface DottoPlusPlusOriginalLinkCell : PSTableCell
@end

// Generic blue subtitle link row (title + footnote subtitle + icon + chevron),
// used for the Ko-fi cell in the Links subview.
@interface DottoPlusPlusSubtitleLinkCell : PSTableCell
@end
