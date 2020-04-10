//
//  RTCTransport.h
//  WebRtcRoomIOS
//
//  Created by 刘金丰 on 2019/1/17.
//  Copyright © 2019 wjr. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RTCMember.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, RTCTranConnectState) {
    RTCTranConnectStateNew,
    RTCTranConnectStateConnecting,
    RTCTranConnectStateConnected,
    RTCTranConnectStateFailed,
    RTCTranConnectStateDisconnected,
    RTCTranConnectStateClosed
};

typedef void (^RTCTran_CB)(id response);

@class RTCProducer;
@class RTCConsumer;

@interface RTCTransport : RTCMember

@property (nonatomic, assign, readonly) NSInteger tid;

@property (nonatomic, assign) BOOL closed;

@property (nonatomic, strong) NSString *direction;

@property (nonatomic, strong) NSDictionary *settings;

@property (nonatomic, strong, nullable) id appData;

@property (nonatomic, assign) BOOL statsEnabled;

@property (nonatomic, assign) RTCTranConnectState connectionState;

@property (nonatomic, strong) NSDictionary *extendedRtpCapabilities;


@property (nonatomic, copy) void (^AddConsumerCallBack)(RTCVideoTrack *);



// ********************* call back ******************
@property (nonatomic, copy) void (^Connectionstatechange_CB)(RTCTranConnectState state);


+ (instancetype)shareInstance:(NSString *)direction extendedRtpCapabilities:(NSDictionary *)extendedRtpCapabilities settings:(NSDictionary *)settings appData:(id _Nullable)appData;


- (void)setTransportLocalParameters:(NSDictionary *)parameters;

- (void)setTransportRemoteParameters:(NSDictionary *)paramters;

- (void)close:(id _Nullable)appData;
- (void)remoteClose:(id _Nullable)appData destroy:(BOOL)destroy;
- (void)restartIce;
- (void)enableStats:(NSInteger)interval;
- (AnyPromise *)addProducer:(RTCProducer *)producer;
- (void)removeProducer:(RTCProducer *)producer originator:(NSString *)originator appData:(id _Nullable)appData;
- (void)pauseProducer:(RTCProducer *)produser appData:(id _Nullable)appData;
- (void)resumeProducer:(RTCProducer *)produser appData:(id _Nullable)appData;
- (AnyPromise *)replaceProducerTrack:(RTCProducer *)producer track:(RTCMediaStreamTrack *)track;
- (void)enableProducerStats:(RTCProducer *)producer interval:(NSInteger)interval;
- (void)disableProducerStats:(RTCProducer *)producer;
- (AnyPromise *)addConsumer:(RTCConsumer *)consumer;
- (void)removeConsumer:(RTCConsumer *)consumer;
- (void)pauseConsumer:(RTCConsumer *)consumer appData:(id _Nullable)appData;
- (void)resumeConsumer:(RTCConsumer *)consumer appData:(id _Nullable)appData;
- (void)setConsumerPreferredProfile:(RTCConsumer *)consumer profile:(NSString *)profile;
- (void)enableConsumerStats:(RTCConsumer *)consumer interval:(NSInteger)interval;
- (void)disableConsumerStats:(RTCConsumer *)consumer;
- (void)remoteStats:(id)stats;

- (BOOL)setBweMinBitrateBps:(nullable NSNumber *)minBitrateBps
          currentBitrateBps:(nullable NSNumber *)currentBitrateBps
              maxBitrateBps:(nullable NSNumber *)maxBitrateBps;


@end

NS_ASSUME_NONNULL_END
