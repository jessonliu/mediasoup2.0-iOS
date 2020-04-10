//
//  JFTOperation.h
//  CinLanMedia
//
//  Created by 刘金丰 on 2019/5/29.
//  Copyright © 2019 Liujinfeng. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^JFResolver)(void);

@interface JFTOperation : NSObject

+ (void)waitChildTreadWithResolverBlock:(void (^)(JFResolver resolver))resolverBlock;

@end

NS_ASSUME_NONNULL_END
