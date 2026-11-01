#import <UIKit/UIKit.h>

__BEGIN_DECLS
void ApolloDuoInstallBackSwipe(UINavigationController *navigation);
BOOL ApolloDuoHasBackSwipe(UINavigationController *navigation);
/// Whether a touch may start a right swipe in this pane, by Apollo's gesture settings.
BOOL ApolloDuoBackSwipeAcceptsTouch(UINavigationController *navigation, UITouch *touch);
/// The same for a left swipe: the pane's trailing edge, or anywhere with Disable Right Swipes.
BOOL ApolloDuoPaneLeftSwipeAcceptsTouch(UINavigationController *navigation, UITouch *touch);
__END_DECLS
