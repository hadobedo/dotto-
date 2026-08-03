#import <Preferences/PSListController.h>

#import "DottoPlusPlusPreferences.h"

@interface DottoPlusPlusRootListController : PSListController {
    DottoPlusPlusPreferences *_preferences;
}

@property (nonatomic, strong) DottoPlusPlusPreferences *preferences;

- (void)switchToggled:(UISwitch *)sender;
- (void)setCellForRowAtIndexPath:(NSIndexPath *)indexPath enabled:(BOOL)enabled;

@end
