#import <Preferences/PSListController.h>

#import "DottoPlusPlusCreditsFooterView.h"
#import "DottoPlusPlusPreferences.h"

@interface DottoPlusPlusRootListController : PSListController {
    DottoPlusPlusPreferences *_preferences;
}

@property (nonatomic, strong) DottoPlusPlusPreferences *preferences;

- (void)switchToggled:(UISwitch *)sender;
- (void)setCellForRowAtIndexPath:(NSIndexPath *)indexPath enabled:(BOOL)enabled;
- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section;
- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section;

@end
