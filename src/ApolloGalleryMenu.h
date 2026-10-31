#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

#ifdef __cplusplus
extern "C" {
#endif

// The Home feed whose ••• opened this sheet, or nil for any other sheet. Safe to
// call any number of times for one sheet, from any spec's blocks.
UIViewController *_Nullable ApolloGalleryMenuHomeOwnerForActionController(id actionController);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
