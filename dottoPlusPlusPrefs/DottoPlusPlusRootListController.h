#import <Preferences/PSListController.h>

#import "DottoPlusPlusPreferences.h"

@interface DottoPlusPlusRootListController : PSListController {
    DottoPlusPlusPreferences *_preferences;
}

@property (nonatomic, strong) DottoPlusPlusPreferences *preferences;

- (UIImage *)symbolImageNamed:(NSString *)name;

@end
