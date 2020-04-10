//
//  RTCCommandQueue.m
//  WebRtcRoomIOS
//
//  Created by 刘金丰 on 2019/3/7.
//  Copyright © 2019 wjr. All rights reserved.
//

#import "RTCCommandQueue.h"

@interface RTCCommandQueue ()

@property (nonatomic) dispatch_semaphore_t Semaphore;
@property (nonatomic) dispatch_queue_t handleQueue;
@property (nonatomic, strong) NSLock *lock;
@property (nonatomic, assign) NSInteger count;
@property (nonatomic, copy) void (^CloseFinich)(void);

@end

@implementation RTCCommandQueue

+ (instancetype)defaultRTCCommandQueue {
    RTCCommandQueue *comQue = [RTCCommandQueue new];
    return comQue;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.Semaphore = dispatch_semaphore_create(1);
        self.handleQueue = dispatch_queue_create("CL_Media_Socket_Queue", DISPATCH_QUEUE_SERIAL);
        self.lock = [NSLock new];
    }
    return self;
}

- (void)close:(void (^)(void))closeFinich {
    [self.lock lock];
    self.closed = YES;
    self.CloseFinich = closeFinich;
    JFErrorLog(@"-------------%ld", (long)self.count);
    if (_count == 0 && closeFinich) closeFinich();
    [self.lock unlock];
}

- (void)start {
    dispatch_semaphore_wait(self.Semaphore, DISPATCH_TIME_FOREVER);
    [self.lock lock];
    self.count += 1;
    [self.lock unlock];
}

- (void)finish {
    dispatch_semaphore_signal(self.Semaphore);
    [self.lock lock];
    self.count -= 1;
    JFErrorLog(@"+++++++++++++++++++-%ld", (long)self.count);
    [self.lock unlock];
}

- (AnyPromise *)invoke:(RCQ_Scalper)scalper {
    if (self.closed) return [AnyPromise promiseWithValue:[NSError errorWithDomain:@"RTCCommandQueue Closed" code:70009 userInfo:nil]];
    [self start];
    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolver) {
        if (!self.closed){
          resolver (scalper());
        } else {
            [self finish];
        }
    }].then(^(id obj){
        [self finish];
        if (self.closed) return (id)[NSError errorWithDomain:@"RTCCommandQueue Closed" code:70009 userInfo:nil];
        return obj;
    }).catchInBackground(^(NSError *error){
        [self finish];
        JFErrorLog(@"%@", error);
    });
}

- (void)setCount:(NSInteger)count {
    _count = count;
    if (count == 0 && self.closed) {
        if (self.CloseFinich){
          self.CloseFinich();
        }
    }
}

- (void)dealloc {
    JFLog(@"🔱🔱RTCCommandQueue dealloc🔱🔱");
}

@end
