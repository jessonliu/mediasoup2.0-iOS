//
//  ConsumerData.h
//  CinLanMedia
//
//  Created by 刘金丰 on 2019/3/22.
//  Copyright © 2019 Liujinfeng. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RTCData.h"

NS_ASSUME_NONNULL_BEGIN

@interface ConsumerData : RTCData

@property (nonatomic, assign, readonly) NSInteger cid;
@property (nonatomic, strong) NSString *peerName;


@end

NS_ASSUME_NONNULL_END
