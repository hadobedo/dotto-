@import UIKit;

struct SBIconImageInfo {
    CGSize size;
    double scale;
    double continuousCornerRadius;
};

@class SBFolder;
@class SBIconListModel;

// Minimal SpringBoard/SpringBoardHome private declarations for the dotto+ rebuild.
// All selectors below are verified against iOS 17.1 runtime headers.

@interface SBIcon : NSObject
@property (nonatomic, readonly, copy) NSString *uniqueIdentifier;
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
@end
