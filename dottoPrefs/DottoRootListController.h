#import <Preferences/PSListController.h>

#import "DottoPreferences.h"

@interface DottoRootListController : PSListController {
    DottoPreferences *_preferences;
}

@property (nonatomic, strong) DottoPreferences *preferences;

- (void)switchToggled:(UISwitch *)sender;
- (void)setCellForRowAtIndexPath:(NSIndexPath *)indexPath enabled:(BOOL)enabled;

@end
