// ApolloForYouMenu.xm — the Home ••• row that switches between For You and
// Subscriptions, on both of the action menu's rendering paths. Registered with
// ApolloActionMenu like every other injected row, so Interface → Action Menus
// can move or hide it (ApolloActionMenuLayout.m has its catalogue entry).

#import <UIKit/UIKit.h>

#import "ApolloActionMenu.h"
#import "ApolloCommon.h"
#import "ApolloForYouMenu.h"
#import "ApolloGalleryMenu.h"
#import "ApolloState.h"
#import "ApolloSwiftRuntime.h"
#import "ApolloToast.h"
#import "ApolloWebJSON.h"
#import "UserDefaultConstants.h"

NSNotificationName const ApolloForYouHomeFeedDidChangeNotification = @"ApolloForYouHomeFeedDidChangeNotification";

// Set when the user switches to For You, until Home's next request shows whether
// its sort is one For You replaces.
static BOOL sApolloForYouAwaitingHomeRequest = NO;

void ApolloForYouHomeFeedSetEnabled(BOOL enabled) {
    sForYouHomeFeed = enabled;
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:UDKeyForYouHomeFeed];
    sApolloForYouAwaitingHomeRequest = enabled;
    ApolloLog(@"[ForYou] Home feed set to %@", enabled ? @"For You" : @"Subscriptions");
    [[NSNotificationCenter defaultCenter] postNotificationName:ApolloForYouHomeFeedDidChangeNotification object:nil];
}

void ApolloForYouNoteUnservedHomeSort(void) {
    if (!sApolloForYouAwaitingHomeRequest) return;
    sApolloForYouAwaitingHomeRequest = NO;
    ApolloShowToastWithStyle(@"For You Is On", @"Sort Home by Best or Hot to see it.", ApolloToastStyleInfo, nil);
}

void ApolloForYouNoteServedHomeSort(void) {
    sApolloForYouAwaitingHomeRequest = NO;
}

// Pull to refresh, driven programmatically: a fresh first page. The same way
// ApolloHiddenContentNative.xm reloads its PostsViewController lists.
static void ApolloForYouReloadHome(UIViewController *home) {
    UIRefreshControl *refreshControl = ApolloObjectIvar(home, "refreshControl");
    if (![refreshControl isKindOfClass:[UIRefreshControl class]]) {
        ApolloLogError(@"[ForYou] Home has no refresh control to reload with");
        ApolloShowToastWithStyle(@"Pull to Refresh", @"Home will switch on its next refresh.", ApolloToastStyleInfo, nil);
        return;
    }
    [refreshControl beginRefreshing];
    [refreshControl sendActionsForControlEvents:UIControlEventValueChanged];
}

%ctor {
    ApolloActionMenuSpec *spec = [ApolloActionMenuSpec new];
    spec.identifier = @"ForYouFeed";
    spec.placement = ApolloActionMenuPlacementAfterLeadingSubmitAffordance;
    spec.inlineSection = YES;
    spec.legacyDismissesSheet = YES;

    spec.matches = ^BOOL(id actionController, NSString *menuTitle) {
        (void)menuTitle;
        return sWebJSONEnabled && ApolloWebJSONHasUsableSession()
            && ApolloGalleryMenuHomeOwnerForActionController(actionController) != nil;
    };
    spec.title = ^NSString *(id actionController, UITableViewCell *donor) {
        (void)actionController; (void)donor;
        return sForYouHomeFeed ? @"Show Subscriptions" : @"Show For You";
    };
    spec.image = ^UIImage *(id actionController, UITableViewCell *donor) {
        (void)actionController; (void)donor;
        NSString *symbol = sForYouHomeFeed ? @"rectangle.stack" : @"sparkles";
        return ApolloActionMenuSymbolIcon(symbol) ?: [UIImage systemImageNamed:symbol];
    };
    spec.perform = ^(id actionController) {
        UIViewController *home = ApolloGalleryMenuHomeOwnerForActionController(actionController);
        ApolloForYouHomeFeedSetEnabled(!sForYouHomeFeed);
        if (home) ApolloForYouReloadHome(home);
    };

    ApolloActionMenuRegister(spec);
}
