//
//  RTCProducer.h
//  WebRtcRoomIOS
//
//  Created by 刘金丰 on 2019/1/17.
//  Copyright © 2019 wjr. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RTCTrackProtocol.h"
#import "RTCMember.h"
@class RTCTransport;
@class RTCTrack;

NS_ASSUME_NONNULL_BEGIN

@interface RTCProducer : RTCMember
@property (nonatomic, assign, readonly) NSInteger pid;
@property (nonatomic, strong, readonly) NSString *peerName;
@property (nonatomic, assign) BOOL closed;
@property (nonatomic, strong) RTCMediaStreamTrack *originalTrack;
@property (nonatomic, strong, nullable) RTCMediaStreamTrack *track;
@property (nonatomic, strong, nullable) id appData;
@property (nonatomic, strong) NSDictionary *simulcast;
@property (nonatomic, strong, nullable) RTCTransport *transport;
@property (nonatomic, strong, nullable) NSDictionary *rtpParameters;
@property (nonatomic, assign) BOOL locallyPaused;
@property (nonatomic, assign) BOOL remotelyPaused;
@property (nonatomic, assign) BOOL statsEnabled;
@property (nonatomic, assign) NSInteger statsInterval;
@property (nonatomic, strong, readonly) NSString *kind;
@property (nonatomic, strong) NSDictionary *options;
@property (nonatomic, assign, readonly) MediaSourceType source;
@property (nonatomic, strong) RTCTrack <RTCTrackProtocol>*rtcTrack;



+ (instancetype)shareInstance:(RTCMediaStreamTrack *)track peerName:(NSString *)peerName options:(NSDictionary *)options appData:(id _Nullable)appData;

- (void)close:(id _Nullable)appData;
- (void)remoteClose:(id _Nullable)appData;
- (AnyPromise *)send:(RTCTransport *)transport;
- (BOOL)pause:(id _Nullable)appData;
- (void)remotePause:(id _Nullable)appData;
- (BOOL)resume:(id _Nullable)appData;
- (void)remoteResume:(id _Nullable)appData;
- (AnyPromise *)replaceTrack:(RTCMediaStreamTrack *)track;
- (void)enableStats:(NSInteger)intervale;
- (void)disableStats;
- (void)remoteStats:(id)stats;



@end

NS_ASSUME_NONNULL_END
