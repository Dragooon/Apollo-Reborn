// ApolloForYouFeed — the Foundation-only half of Home's For You feed for
// API-Key-Free accounts. No network and no tweak state, so
// tests/run_for_you_feed_tests.sh can compile it straight into a host harness.
// See docs/for-you-feed.md for what Reddit answers and why it works this way.
//
// Reddit's API only serves subscribed subreddits at /best and /hot. Reddit's
// website gets its For You tab from an HTML endpoint, which answers the session
// cookie. This reads the post order from that HTML, and the posts themselves
// come from /api/info, so Apollo parses the same JSON it always does.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#ifdef __cplusplus
extern "C" {
#endif

// The sort when `path` is Home's own listing ("best.json", "/hot", ".json"),
// lowercased, and @"" for the bare path. nil for any other path. A query is
// ignored.
NSString *_Nullable ApolloForYouFeedHomeSortFromPath(NSString *_Nullable path);

// YES when For You replaces this Home sort: Best, Hot and the bare path. For
// You has no sort of its own, so New, Top, Rising and Controversial keep showing
// subscriptions.
BOOL ApolloForYouFeedSortIsServed(NSString *_Nullable sort);

// A page of the feed. `afterFullname` is Apollo's `after` value ("t3_abc"); the
// endpoint's cursor is that value in base64, so nothing else needs keeping
// between pages. nil or empty asks for the first page.
NSURL *ApolloForYouFeedPageURL(NSString *_Nullable afterFullname);

// Post fullnames in feed order, without repeats. Ads are <shreddit-ad-post>
// tags, so they aren't included. Empty for HTML with no posts.
NSArray<NSString *> *ApolloForYouFeedPostFullnamesFromHTML(NSData *_Nullable html);

// The query for reading `fullnames` from /api/info.
NSString *ApolloForYouFeedInfoQuery(NSArray<NSString *> *fullnames);

// Apollo's listing for one page, built from an /api/info answer: its posts in
// `orderedFullnames` order, leaving out posts Reddit no longer returns and posts
// the account has hidden. `after` is the next page's cursor, which is the last
// post of the feed page whether or not that post was left out. nil when `infoData`
// isn't a signed-in listing: a signed-out answer has no modhash.
NSDictionary *_Nullable ApolloForYouFeedListing(NSData *_Nullable infoData,
                                                NSArray<NSString *> *orderedFullnames,
                                                NSString *_Nullable after);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
