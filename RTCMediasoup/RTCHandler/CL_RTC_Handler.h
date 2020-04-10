//
//  CL_RTC_Handler.h
//  WebRtcRoomIOS
//
//  Created by 刘金丰 on 2019/1/19.
//  Copyright © 2019 wjr. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RTCTransport.h"

NS_ASSUME_NONNULL_BEGIN

UIKIT_EXTERN NSString *const CL_Direction_Send;
UIKIT_EXTERN NSString *const CL_Direction_Recv;

typedef void (^CL_Handler_Complete)(NSString * _Nullable sdp, NSError *error);
typedef void (^CL_CT_CB)(id data);


@class RTCProducer;
@class RTCConsumer;

@interface CL_RTC_Handler : NSObject

@property (nonatomic, strong) RTCPeerConnection *peerConnection;
@property (nonatomic, strong) mt_RemoteUnifiedPlanSdp *remoteSdp;
@property (nonatomic, strong, readonly) NSString *direction;
@property (nonatomic, strong) NSDictionary *rtpParametersByKind;
@property (nonatomic, strong) NSDictionary *settings;
@property (nonatomic, assign) BOOL transportReady;
@property (nonatomic, assign) BOOL transportUpdated;


// ************************** Callback *********************
@property (nonatomic, copy) void (^Connectionstatechange_CB)(RTCTranConnectState state);
@property (nonatomic, copy) void (^Needcreatetransport_CB)(NSDictionary * __nullable transportLocalParameters, CL_CT_CB callback);
@property (nonatomic, copy) void (^Needupdatetransport_CB)(NSDictionary *transportLocalParameters);


- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithDirection:(NSString *)direction rtpParametersByKind:(NSDictionary *)rtpParametersByKind settings:(NSDictionary *)settings NS_DESIGNATED_INITIALIZER;

- (void)close;

- (void)remoteClose;

- (BOOL)setBweMinBitrateBps:(nullable NSNumber *)minBitrateBps
          currentBitrateBps:(nullable NSNumber *)currentBitrateBps
              maxBitrateBps:(nullable NSNumber *)maxBitrateBps;

/**
 设置本地Offer SDP
 
 @param complete 返回结果
 */
- (void)setLocalOfferDescription:(CL_Handler_Complete)complete;

/**
 设置本地Answer SDP
 
 @param complete 返回结果
 */
- (void)setLocalAnswerDescription:(CL_Handler_Complete)complete;


/**
 重启 ICE

 @param remoteIceParameters 远端ICE 参数
 @return AnyPromise Resolver -> nullable
 */
- (AnyPromise *)restartIce:(NSDictionary *)remoteIceParameters;


/**
 设置 Transport

 @return AnyPromise Resolver -> nil
 */
- (AnyPromise *)setupTransport;


/**
 *  设置offer/answer的约束
 */
+ (RTCMediaConstraints *)creatAnswerOrOfferConstraint;

/**
 设置 Constraint

 @param optional {NSDictionary} option
 @return RTCMediaConstraints
 */
+ (RTCMediaConstraints *)creatConstraintWithOption:(NSDictionary * _Nullable)optional;


/**
 获取 RTCPeerConnectionFactory

 @return RTCPeerConnectionFactory
 */
+ (RTCPeerConnectionFactory *)getFactory;



/**
 获取 SDP

 @return AnyPromise resolver sdp or error
 */
+ (AnyPromise *)getNativeRtpCapabilities;


/**
 枚举设备

 @return 返回枚举的设备集合
 */
+ (NSArray *)enumerateDevices;



/**
 添加 producer
 
 @param producer producer
 @return AnyPromise Resolves with a <NSDictionary *>rtpParameters
 */
- (AnyPromise *)addProducer:(RTCProducer *)producer;

- (AnyPromise *)removeProducer:(RTCProducer *)producer;

- (AnyPromise *)replaceProducerTrack:(RTCProducer *)producer track:(RTCMediaStreamTrack *)track;



/**
 添加 Consumer
 
 @param consumer consumer
 @return AnyPromise Resolves with a <MediaStreamTrack *>track
 */
- (AnyPromise *)addConsumer:(RTCConsumer *)consumer;

- (AnyPromise *)removeConsumer:(RTCConsumer *)consumer;

- (void)updateTransport;

@end






/****************************************   CL_RTC_SendHandler    ****************************************/

@interface CL_RTC_SendHandler : CL_RTC_Handler

@end

/****************************************   CL_RTC_RecvHandler    ****************************************/

@interface CL_RTC_RecvHandler : CL_RTC_Handler

@end


/****************************************   CL_RTC_Handler_Factory    ****************************************/

@interface CL_RTC_Handler_Factory : NSObject

+ (CL_RTC_Handler *)createHandlerDirection:(NSString *)direction extendedRtpCapabilities:(NSDictionary *)extendedRtpCapabilities settings:(NSDictionary *)settings;
@end

NS_ASSUME_NONNULL_END
