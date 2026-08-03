#import <Preferences/PSListController.h>
#import <Preferences/PSTableCell.h>

// The theos vendor Preferences headers are minimal; declare the inherited
// PSListController/PSTableCell methods we call (categories, so no
// -Wincomplete-implementation). All are real Preferences.framework methods.
// NOTE: setYellowTaps: was removed from PSTableCell on modern iOS — do not use it.

@interface PSListController (DottoPlusPlusCompat)
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath;
@end
