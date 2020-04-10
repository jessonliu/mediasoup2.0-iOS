//
//  RTCRoom.h
//  WebRtcRoomIOS
//
//  Created by 刘金丰 on 2019/3/9.
//  Copyright © 2019 wjr. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "M13OrderedDictionary.h"

NS_ASSUME_NONNULL_BEGIN

@interface RTCRoomOptions : NSObject
@property (nonatomic, strong) NSDictionary *roomSettings;
@property (nonatomic, assign) NSInteger requestTimeout;
@property (nonatomic, strong) NSDictionary *transportOptions;
@property (nonatomic, strong) NSArray <RTCIceServer *>*turnServers;
@property (nonatomic, assign) RTCTcpCandidatePolicy iceTransportPolicy;
@property (nonatomic, assign) BOOL spy;
@property (nonatomic, strong, nullable) id appData;

@end

typedef NS_ENUM(NSInteger, RTCRoomsState) {
    RTCRoomsStateNew,
    RTCRoomsStateJoining,
    RTCRoomsStateJoined,
    RTCRoomsStateClosed
};

typedef NS_ENUM(NSInteger, RTCRoomMediaKind) {
    RTCRoomMediaKindAudio,
    RTCRoomMediaKindVideo
} ;

typedef M13MutableOrderedDictionary OrderedDictionary;

@class RTCTransport;
@class RTCProducer;
@class RTCPeer;

@interface RTCRoom : NSObject
@property (nonatomic, assign) RTCRoomsState state;
@property (nonatomic, strong) NSString *peerName;
@property (nonatomic, strong, nullable) OrderedDictionary <NSString *, RTCTransport *>*transports;
@property (nonatomic, strong, nullable) OrderedDictionary <NSString *, RTCProducer *>*producers;
@property (nonatomic, strong, nullable) OrderedDictionary <NSString *, RTCPeer *>*peers;
@property (nonatomic, strong) NSDictionary *extendedRtpCapabilities;
@property (nonatomic, strong) NSMutableDictionary *canSendByKind;


// *****************************  Callback ***************************//
@property (nonatomic, copy) void (^Request_CB)(NSDictionary *request, void (^Callback)(id data));
@property (nonatomic, copy) void (^Newpeer_CB)(RTCPeer *peer);
@property (nonatomic, copy) void (^Notify_CB)(NSDictionary *notification,  void (^ _Nullable Callback)(id data));
@property (nonatomic, copy) void (^Close_CB)(NSString *args,  id _Nullable appData);

+ (instancetype)constructor:(RTCRoomOptions *)options;

- (AnyPromise *)join:(NSString *)peerName appData:(id _Nullable)appData;

- (void)leave:(id _Nullable)appData;

- (void)remoteClose:(id _Nullable)appData;

- (BOOL)canSend:(RTCRoomMediaKind)kind;

- (RTCTransport *)createTransport:(NSString *)direction appData:(id _Nullable)appData;

- (RTCProducer *)createProducer:(RTCMediaStreamTrack *)track options:(NSDictionary * _Nullable)options appData:(id _Nullable)appData;

- (void)restartIce;

- (AnyPromise *)receiveNotification:(NSDictionary *)notification;

@end

NS_ASSUME_NONNULL_END
