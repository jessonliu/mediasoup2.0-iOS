//
//  RTCPeer.h
//  WebRtcRoomIOS
//
//  Created by 刘金丰 on 2019/1/15.
//  Copyright © 2019 wjr. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CLPeerProtocol.h"
#import "RTCMember.h"
#import "CLConsumer.h"
#import "CLConsumerProtocol.h"

NS_ASSUME_NONNULL_BEGIN

typedef M13MutableOrderedDictionary MulOrderedDictionary;
@class RTCConsumer;

@interface RTCPeer : RTCMember
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *displayName;
@property (nonatomic, strong) NSString *host;
@property (nonatomic, strong, nullable) id appData;
@property (nonatomic, assign) BOOL closed;
@property (nonatomic, assign) ConfShareType share;
@property (nonatomic, strong) MulOrderedDictionary <NSString *, RTCConsumer *> *consumers;
@property (nonatomic, strong) CLPeer <CLPeerProtocol>*peerData;


+ (instancetype)shareInstance:(NSString *)name appData:(id _Nullable)appData;

- (NSArray <RTCConsumer *>*)consumersToArr;

- (void)close;

- (void)remoteClose:(id _Nullable)appData;

- (RTCConsumer *)getConsumerById:(NSString *)cid;

- (void)addConsumer:(RTCConsumer *)consumer;

@end

NS_ASSUME_NONNULL_END
