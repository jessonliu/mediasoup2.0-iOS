//
//  RTCCommandQueue.h
//  WebRtcRoomIOS
//
//  Created by 刘金丰 on 2019/3/7.
//  Copyright © 2019 wjr. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef AnyPromise *_Nullable(^RCQ_Scalper)(void);

@interface RTCCommandQueue : NSObject

@property (nonatomic, assign) BOOL closed;


+ (instancetype)defaultRTCCommandQueue;


/**
 必须确保 该方法在异步线程中调用
 */
- (AnyPromise *)invoke:(RCQ_Scalper)scalper;

- (void)close:(void (^)(void))closeFinich;



@end

NS_ASSUME_NONNULL_END
