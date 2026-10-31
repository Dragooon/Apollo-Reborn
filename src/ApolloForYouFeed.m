#import "ApolloForYouFeed.h"

NSString *ApolloForYouFeedHomeSortFromPath(NSString *path) {
    if (![path isKindOfClass:[NSString class]]) return nil;
    NSString *bare = [path.lowercaseString componentsSeparatedByString:@"?"].firstObject ?: @"";
    while ([bare hasPrefix:@"/"]) bare = [bare substringFromIndex:1];
    while ([bare hasSuffix:@"/"]) bare = [bare substringToIndex:bare.length - 1];
    if ([bare hasSuffix:@".json"]) bare = [bare substringToIndex:bare.length - 5];
    while ([bare hasSuffix:@"/"]) bare = [bare substringToIndex:bare.length - 1];

    static NSSet<NSString *> *sorts;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        sorts = [NSSet setWithArray:@[@"", @"best", @"hot", @"new", @"top", @"rising", @"controversial"]];
    });
    return [sorts containsObject:bare] ? bare : nil;
}

BOOL ApolloForYouFeedSortIsServed(NSString *sort) {
    return [sort isEqualToString:@""] || [sort isEqualToString:@"best"] || [sort isEqualToString:@"hot"];
}

NSURL *ApolloForYouFeedPageURL(NSString *afterFullname) {
    NSString *urlString = @"https://www.reddit.com/svc/shreddit/feeds/interest-home-feed?feed=for-you";
    if (afterFullname.length > 0) {
        NSData *bytes = [afterFullname dataUsingEncoding:NSUTF8StringEncoding];
        NSString *cursor = [bytes base64EncodedStringWithOptions:0];
        // Base64's "+" would otherwise reach Reddit as a space.
        NSString *escaped = [cursor stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet alphanumericCharacterSet]];
        urlString = [urlString stringByAppendingFormat:@"&after=%@", escaped];
    }
    return [NSURL URLWithString:urlString];
}

NSArray<NSString *> *ApolloForYouFeedPostFullnamesFromHTML(NSData *html) {
    if (html.length == 0) return @[];
    NSString *text = [[NSString alloc] initWithData:html encoding:NSUTF8StringEncoding]
        ?: [[NSString alloc] initWithData:html encoding:NSISOLatin1StringEncoding];
    if (text.length == 0) return @[];

    static NSRegularExpression *postTag;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        // The leading whitespace keeps award-id="..." from matching as the id.
        postTag = [NSRegularExpression regularExpressionWithPattern:@"<shreddit-post\\s[^>]*?\\sid=\"(t3_[a-z0-9]+)\""
                                                            options:0
                                                              error:NULL];
    });

    NSMutableOrderedSet<NSString *> *fullnames = [NSMutableOrderedSet orderedSet];
    [postTag enumerateMatchesInString:text
                              options:0
                                range:NSMakeRange(0, text.length)
                           usingBlock:^(NSTextCheckingResult *match, __unused NSMatchingFlags flags, __unused BOOL *stop) {
        [fullnames addObject:[text substringWithRange:[match rangeAtIndex:1]]];
    }];
    return fullnames.array;
}

NSString *ApolloForYouFeedInfoQuery(NSArray<NSString *> *fullnames) {
    return [NSString stringWithFormat:@"id=%@&limit=100&raw_json=1", [fullnames componentsJoinedByString:@","]];
}

NSDictionary *ApolloForYouFeedListing(NSData *infoData, NSArray<NSString *> *orderedFullnames, NSString *after) {
    if (infoData.length == 0) return nil;
    id root = [NSJSONSerialization JSONObjectWithData:infoData options:0 error:NULL];
    if (![root isKindOfClass:[NSDictionary class]] || ![root[@"kind"] isEqual:@"Listing"]) return nil;
    NSDictionary *data = [root[@"data"] isKindOfClass:[NSDictionary class]] ? root[@"data"] : nil;
    NSArray *children = [data[@"children"] isKindOfClass:[NSArray class]] ? data[@"children"] : nil;
    NSString *modhash = [data[@"modhash"] isKindOfClass:[NSString class]] ? data[@"modhash"] : nil;
    if (!children || modhash.length == 0) return nil;

    NSMutableDictionary<NSString *, NSDictionary *> *childByFullname = [NSMutableDictionary dictionaryWithCapacity:children.count];
    for (id child in children) {
        if (![child isKindOfClass:[NSDictionary class]]) continue;
        NSDictionary *post = [child[@"data"] isKindOfClass:[NSDictionary class]] ? child[@"data"] : nil;
        NSString *fullname = [post[@"name"] isKindOfClass:[NSString class]] ? post[@"name"] : nil;
        if (fullname.length == 0 || [post[@"hidden"] isEqual:@YES]) continue;
        childByFullname[fullname] = child;
    }

    NSMutableArray<NSDictionary *> *orderedChildren = [NSMutableArray arrayWithCapacity:orderedFullnames.count];
    for (NSString *fullname in orderedFullnames) {
        NSDictionary *child = childByFullname[fullname];
        if (child) [orderedChildren addObject:child];
    }

    NSMutableDictionary *listingData = [data mutableCopy];
    listingData[@"children"] = orderedChildren;
    listingData[@"after"] = after.length > 0 ? after : (id)[NSNull null];
    listingData[@"before"] = [NSNull null];
    listingData[@"dist"] = @(orderedChildren.count);
    return @{ @"kind": @"Listing", @"data": listingData };
}
