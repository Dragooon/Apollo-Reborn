// Home's For You feed: the setting, and the ••• menu row that switches it.
// API-Key-Free accounts only. The feed itself is ApolloForYouFeed.h and
// ApolloWebJSONFetchForYouPage. See docs/for-you-feed.md.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#ifdef __cplusplus
extern "C" {
#endif

// Posted on the main thread when the setting changes, so a Settings screen
// that's already showing the switch can catch up.
extern NSNotificationName const ApolloForYouHomeFeedDidChangeNotification;

// Saves the setting. Main thread.
void ApolloForYouHomeFeedSetEnabled(BOOL enabled);

// Called when Home asks for a sort For You doesn't replace. If the user just
// switched to For You, says why Home still shows subscriptions. Main thread.
void ApolloForYouNoteUnservedHomeSort(void);

// Called when Home asks for a sort For You replaces. Main thread.
void ApolloForYouNoteServedHomeSort(void);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
