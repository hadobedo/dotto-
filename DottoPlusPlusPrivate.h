@import UIKit;

struct SBIconImageInfo {
    CGSize size;
    double scale;
    double continuousCornerRadius;
};

@class SBFolder;
@class SBIconListModel;

// Minimal SpringBoard/SpringBoardHome private declarations for the dotto+ rebuild.
// The common selectors were checked against the iOS 17.1 runtime-header dump;
// that does not prove availability on every iOS 15/16 point release. The
// accessoryCenterForIconBounds: declaration is iOS 17-only and is installed
// conditionally in Tweak.x.

@interface SBIcon : NSObject
@property (nonatomic, readonly, copy) NSString *uniqueIdentifier;
@property (nonatomic, readonly) long long badgeValue;
- (UIImage *)iconImageWithInfo:(struct SBIconImageInfo)info;
@end

@interface SBApplicationIcon : SBIcon
@end

@interface SBFolderIcon : SBApplicationIcon
@property (nonatomic, readonly, strong) SBFolder *folder;
@end

@interface SBFolder : NSObject
@property (nonatomic, readonly, copy) NSArray<SBIconListModel *> *lists;
@end

@interface SBIconListModel : NSObject
@property (nonatomic, copy) NSArray<SBIcon *> *icons;
@end

@interface SBForceTouchAppIconInfoProvider : NSObject
@end

@interface SBIconImageView : UIImageView
- (UIImage *)contentsImage;
@end

@interface SBIconBadgeView : UIView
@end

@interface SBIconView : UIView
- (CGPoint)_centerForAccessoryView;
- (CGPoint)accessoryCenterForIconBounds:(CGRect)iconBounds API_AVAILABLE(ios(17.0));
@end
