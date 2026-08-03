#import <Preferences/PSListController.h>
#import <Preferences/PSTableCell.h>

// The theos vendor Preferences headers are minimal; declare the inherited
// PSListController/PSTableCell methods we call (categories, so no
// -Wincomplete-implementation). All are real Preferences.framework methods.

@interface PSListController (Dotto17Compat)
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath;
@end

@interface PSTableCell (Dotto17Compat)
- (void)setYellowTaps:(BOOL)taps;
@end
