// Host-side regression harness for src/ApolloForYouFeed.m. The HTML fixtures keep
// the attribute order Reddit sent on 2026-10-31.
#import <Foundation/Foundation.h>
#import "ApolloForYouFeed.h"

static int gFailures = 0;

#define CHECK(condition, ...) do { \
    if (!(condition)) { \
        gFailures++; \
        NSLog(@"FAILED line %d: %@", __LINE__, [NSString stringWithFormat:__VA_ARGS__]); \
    } \
} while (0)

static NSData *UTF8(NSString *text) { return [text dataUsingEncoding:NSUTF8StringEncoding]; }

static NSDictionary *Child(NSString *fullname, BOOL hidden) {
    return @{ @"kind": @"t3", @"data": @{ @"name": fullname, @"hidden": @(hidden), @"title": fullname } };
}

static NSData *InfoJSON(NSArray *children, NSString *modhash) {
    NSDictionary *root = @{ @"kind": @"Listing",
                            @"data": @{ @"modhash": modhash, @"children": children, @"after": [NSNull null], @"before": [NSNull null] } };
    return [NSJSONSerialization dataWithJSONObject:root options:0 error:NULL];
}

static NSArray *ChildNames(NSDictionary *listing) {
    return [listing valueForKeyPath:@"data.children.data.name"];
}

static void TestHomeSort(void) {
    NSDictionary<NSString *, NSString *> *sorts = @{
        @"best.json": @"best", @"/best.json": @"best", @"hot": @"hot", @"/HOT.json?limit=25": @"hot",
        @".json": @"", @"/": @"", @"": @"", @"/.json": @"",
        @"new.json": @"new", @"top.json": @"top", @"rising": @"rising", @"controversial.json": @"controversial",
    };
    for (NSString *path in sorts) {
        CHECK([ApolloForYouFeedHomeSortFromPath(path) isEqualToString:sorts[path]], @"%@ -> %@", path, ApolloForYouFeedHomeSortFromPath(path));
    }
    for (NSString *path in @[ @"r/apple/best.json", @"/r/all/hot", @"r/Popular/best.json", @"user/x/submitted.json",
                              @"subreddits/mine/subscriber.json", @"api/info.json", @"comments/abc.json", @"bestest.json" ]) {
        CHECK(ApolloForYouFeedHomeSortFromPath(path) == nil, @"%@ isn't Home", path);
    }
    CHECK(ApolloForYouFeedHomeSortFromPath(nil) == nil, @"nil path");
    for (NSString *sort in @[ @"", @"best", @"hot" ]) CHECK(ApolloForYouFeedSortIsServed(sort), @"serves %@", sort);
    for (NSString *sort in @[ @"new", @"top", @"rising", @"controversial" ]) CHECK(!ApolloForYouFeedSortIsServed(sort), @"leaves %@", sort);
    CHECK(!ApolloForYouFeedSortIsServed(nil), @"nil sort");
}

static void TestPageURL(void) {
    NSString *first = @"https://www.reddit.com/svc/shreddit/feeds/interest-home-feed?feed=for-you";
    CHECK([ApolloForYouFeedPageURL(nil).absoluteString isEqualToString:first], @"%@", ApolloForYouFeedPageURL(nil));
    CHECK([ApolloForYouFeedPageURL(@"").absoluteString isEqualToString:first], @"empty after");
    // The cursor Reddit's own next link carried for t3_1xjffxx.
    NSString *next = [first stringByAppendingString:@"&after=dDNfMXhqZmZ4eA%3D%3D"];
    CHECK([ApolloForYouFeedPageURL(@"t3_1xjffxx").absoluteString isEqualToString:next], @"%@", ApolloForYouFeedPageURL(@"t3_1xjffxx"));
}

static void TestPostOrder(void) {
    NSString *html =
        @"<html><shreddit-ad-post id=\"t3_ad1\" class=\"promotedlink\"></shreddit-ad-post>"
        @"<shreddit-post data-ks-item class=\"a\" permalink=\"/r/a/comments/one/\" award-id=\"award_free_popcorn_2\" id=\"t3_one\" post-title=\"First\"></shreddit-post>"
        @"<shreddit-post-overflow-menu id=\"t3_menu\"></shreddit-post-overflow-menu>"
        @"<shreddit-post\n class=\"b\"\n id=\"t3_two\"\n post-title=\"Second\"></shreddit-post>"
        @"<shreddit-post class=\"c\" id=\"t3_one\" post-title=\"Repeat\"></shreddit-post>"
        @"<shreddit-post class=\"d\" post-title=\"No id\"></shreddit-post>"
        @"<shreddit-post class=\"e\" id=\"t3_three\"></shreddit-post></html>";
    NSArray *expected = @[ @"t3_one", @"t3_two", @"t3_three" ];
    NSArray *found = ApolloForYouFeedPostFullnamesFromHTML(UTF8(html));
    CHECK([found isEqualToArray:expected], @"%@", found);
    CHECK(ApolloForYouFeedPostFullnamesFromHTML(nil).count == 0, @"nil html");
    CHECK(ApolloForYouFeedPostFullnamesFromHTML(UTF8(@"<html>Blocked</html>")).count == 0, @"no posts");
    uint8_t notUTF8[] = { '<', 0xFF, '>' };
    CHECK(ApolloForYouFeedPostFullnamesFromHTML([NSData dataWithBytes:notUTF8 length:3]).count == 0, @"bad bytes");
}

static void TestInfoQuery(void) {
    NSString *query = ApolloForYouFeedInfoQuery(@[ @"t3_a", @"t3_b" ]);
    CHECK([query isEqualToString:@"id=t3_a,t3_b&limit=100&raw_json=1"], @"%@", query);
}

static void TestListing(void) {
    // /api/info answers in its own order; the feed's order wins.
    NSData *info = InfoJSON(@[ Child(@"t3_c", NO), Child(@"t3_a", NO), Child(@"t3_hidden", YES), Child(@"t3_extra", NO) ], @"hash");
    NSArray *feed = @[ @"t3_a", @"t3_gone", @"t3_hidden", @"t3_c" ];
    NSDictionary *listing = ApolloForYouFeedListing(info, feed, @"t3_c");
    NSArray *expected = @[ @"t3_a", @"t3_c" ];
    CHECK([ChildNames(listing) isEqualToArray:expected], @"%@", ChildNames(listing));
    CHECK([listing[@"kind"] isEqual:@"Listing"], @"kind");
    CHECK([listing[@"data"][@"after"] isEqual:@"t3_c"], @"after");
    CHECK([listing[@"data"][@"before"] isEqual:[NSNull null]], @"before");
    CHECK([listing[@"data"][@"modhash"] isEqual:@"hash"], @"modhash");
    CHECK([listing[@"data"][@"dist"] isEqual:@2], @"dist");

    // The cursor is the feed page's last post even when that post was left out.
    NSDictionary *lastHidden = ApolloForYouFeedListing(InfoJSON(@[ Child(@"t3_a", NO), Child(@"t3_b", YES) ], @"hash"), @[ @"t3_a", @"t3_b" ], @"t3_b");
    CHECK([lastHidden[@"data"][@"after"] isEqual:@"t3_b"], @"after past a hidden post");
    CHECK([ChildNames(lastHidden) isEqualToArray:@[ @"t3_a" ]], @"hidden post left out");

    NSDictionary *allHidden = ApolloForYouFeedListing(InfoJSON(@[ Child(@"t3_a", YES) ], @"hash"), @[ @"t3_a" ], @"t3_a");
    CHECK([allHidden[@"data"][@"children"] count] == 0 && [allHidden[@"data"][@"after"] isEqual:@"t3_a"], @"an all-hidden page still has a next page");

    NSDictionary *noAfter = ApolloForYouFeedListing(info, feed, nil);
    CHECK([noAfter[@"data"][@"after"] isEqual:[NSNull null]], @"no after");

    // Not a signed-in listing.
    CHECK(ApolloForYouFeedListing(InfoJSON(@[ Child(@"t3_a", NO) ], @""), @[ @"t3_a" ], @"t3_a") == nil, @"no modhash");
    CHECK(ApolloForYouFeedListing(UTF8(@"<html>Blocked</html>"), @[ @"t3_a" ], @"t3_a") == nil, @"block page");
    CHECK(ApolloForYouFeedListing(UTF8(@"[]"), @[ @"t3_a" ], @"t3_a") == nil, @"array root");
    CHECK(ApolloForYouFeedListing(UTF8(@"{\"kind\":\"Listing\",\"data\":{\"modhash\":\"hash\"}}"), @[ @"t3_a" ], @"t3_a") == nil, @"no children");
    CHECK(ApolloForYouFeedListing(nil, @[ @"t3_a" ], @"t3_a") == nil, @"no data");
}

int main(void) {
    @autoreleasepool {
        TestHomeSort();
        TestPageURL();
        TestPostOrder();
        TestInfoQuery();
        TestListing();
    }
    if (gFailures > 0) {
        NSLog(@"for_you_feed_tests: %d check(s) failed", gFailures);
        return 1;
    }
    printf("for_you_feed_tests: passed\n");
    return 0;
}
