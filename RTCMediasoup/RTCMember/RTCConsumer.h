//
//  RTCConsumer.h
//  WebRtcRoomIOS
//
//  Created by 刘金丰 on 2019/1/20.
//  Copyright © 2019 wjr. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CLConsumerProtocol.h"
#import "RTCMember.h"
#import "RTCTrackProtocol.h"


@class RTCPeer;
@class RTCTransport;
@class RTCTrack;
@class CLConsumer;

NS_ASSUME_NONNULL_BEGIN

@interface RTCConsumer : RTCMember

@property (nonatomic, assign) NSInteger cid;
@property (nonatomic, assign) BOOL closed;
@property (nonatomic, strong) NSString *kind;
@property (nonatomic, strong) NSString *dvid;
@property (nonatomic, strong) NSString *dvName;
@property (nonatomic, assign) BOOL broadcast;
@property (nonatomic, assign) MSMediaKind mKind;
@property (nonatomic, strong, nullable) NSDictionary *rtpParameters;
@property (nonatomic, weak) RTCPeer *peer;
@property (nonatomic, strong, nullable) id appData;
@property (nonatomic, assign) BOOL supported;
@property (nonatomic, weak, nullable) RTCTransport *transport;
@property (nonatomic, strong, nullable) RTCMediaStreamTrack *track;
@property (nonatomic, assign) BOOL locallyPaused;
@property (nonatomic, assign) BOOL remotelyPaused;
@property (nonatomic, assign) BOOL statsEnabled;
@property (nonatomic, assign) NSInteger statsInterval;
@property (nonatomic, strong) NSString *preferredProfile;
@property (nonatomic, strong) NSString *effectiveProfile;
@property (nonatomic, assign, readonly) MediaSourceType source;
@property (nonatomic, strong) RTCTrack <RTCTrackProtocol>*rtcTrack;

@property (nonatomic, strong, nullable) CLConsumer <CLConsumerProtocol>*consumerData;



+ (instancetype)shareInstance:(NSInteger)cid kind:(NSString *)kind rtpParameters:(NSDictionary *)rtpParameters peer:(RTCPeer *)peer appData:(id _Nullable)appData;

- (void)close;

- (BOOL)getPaused;

- (void)remoteClose;

- (AnyPromise *)receive:(RTCTransport *)transport;

- (BOOL)pause:(id _Nullable)appData;

- (void)remotePause:(id _Nullable)appData;

- (BOOL)resume:(id _Nullable)appData;

- (void)remoteResume:(id _Nullable)appData;

- (void)setPreferredProfile:(NSString *)preferredProfile;

- (void)remoteSetPreferredProfile:(NSString *)profile;

- (void)remoteEffectiveProfileChanged:(NSString *)profile;

- (void)enablesStats:(NSInteger)interval;

- (void)disableStats;

- (void)setSupported:(BOOL)supported;

- (void)remoteStats:(id)stats;

@end

NS_ASSUME_NONNULL_END
