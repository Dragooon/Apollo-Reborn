# For You on Home

API-Key-Free accounts see Reddit's For You feed on Home, in place of subscriptions at the Best and Hot sorts. It's on by default. **Show Subscriptions** in Home's ••• menu or **For You on Home** in Apollo Reborn settings turns it off. API-key accounts never use it: the feed needs the session cookie.

## What Reddit answers

Checked on 2026-10-31 on one signed-in account, with the cookie header alone from outside a browser and a browser User-Agent. `reddit_session` alone gave the same results.

| Request | Answer |
|---|---|
| `/best.json`, `/hot.json` | Subscribed subreddits only |
| `/svc/shreddit/feeds/home-feed` | HTML, subscribed subreddits only |
| `/svc/shreddit/feeds/interest-home-feed?feed=following` | HTML, subscribed subreddits only |
| `/svc/shreddit/feeds/interest-home-feed?feed=for-you` | HTML, recommended posts mixed in |

Of the posts from `feed=for-you`, 7 to 13 of each 25 came from unsubscribed subreddits in one run, and 4 of the first 28 in another.

- **Posts:** `<shreddit-post>` tags with an `id` attribute. Ads are `<shreddit-ad-post>`.
- **Paging:** `&after=<base64 of the last post's fullname>` is enough. The page's own next link adds more, and none of it was needed.
- **First page:** 3 posts in about 440 KB. Later pages hold 25 posts in about 1 MB, before compression.
- **Repeats:** the same cursor gave entirely different posts on each request, so a resend doesn't get the same page.
- **Signed out:** the feed still answers 200, with a feed for a signed-out visitor. `/api/info/.json` answers 403 and has no signed-in listing to return, which is how a dead session shows up.

## How it works

1. `-[RDKClient taskWithMethod:path:parameters:completion:]` (`ApolloWebJSONIdentity.xm`) catches Home's GET at the Best or Hot sort or the bare path, for a web-session account. Other sorts go out as usual.
2. `ApolloWebJSONFetchForYouPage` reads the feed page, plus the next one on a first load, and takes the post order from the HTML.
3. It reads those posts from `/api/info` by that entry's routes (`docs/keyless-routes.md`), so a route update applies here too.
4. `ApolloForYouFeedListing` puts them in feed order, drops posts the account has hidden, and sets `after` to the feed page's last post.
5. The listing goes to RedditKit's completion as if it were `/best.json`'s answer, after the same media repair other listings get.

A first page that fails sends the request Apollo asked for and shows a toast once per launch. A later page reports a failed load, because its `after` is a post from the For You feed.

## Limits

- Home pays 2 requests a page, or 3 for a first load, where `/best` costs 1.
- It reads Reddit's website markup. If the tags change, the first page falls back to subscriptions and logs `[ForYou]`.
- Gallery View on Home still shows subscriptions. It sends its own requests and doesn't pass through RedditKit.
- Apollo's own Home row still reads "Posts from subscriptions". Only the feed shortcuts' detail text changes.
