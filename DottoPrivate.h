@import UIKit;

// Minimal SpringBoard/SpringBoardHome private declarations for the dotto+ rebuild.
// All selectors below are verified against iOS 17.1 runtime headers.

@interface SBApplicationIcon : NSObject
@end

@interface SBFolderIcon : SBApplicationIcon
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
