#import <Foundation/Foundation.h>

// Localized strings for the dotto++ preference bundle. Keys are the English
// source strings themselves; each .lproj/Localizable.strings holds the
// translation. Unmatched keys fall back to English automatically.
static inline NSString *DottoL(NSString *key) {
    static NSBundle *prefsBundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        prefsBundle = [NSBundle bundleForClass:NSClassFromString(@"DottoPlusPlusRootListController")];
    });
    return NSLocalizedStringFromTableInBundle(key, @"Localizable", prefsBundle, nil);
}
