//
//  RTCRoom.m
//  WebRtcRoomIOS
//
//  Created by 刘金丰 on 2019/3/9.
//  Copyright © 2019 wjr. All rights reserved.
//

#import "RTCRoom.h"
#import "RTCTransport.h"
#import "RTCProducer.h"
#import "RTCPeer.h"
#import "RTCConsumer.h"
#import "CL_RTC_Handler.h"



@implementation RTCRoomOptions

- (NSDictionary *)toDictionary {
    return @{@"roomSettings":self.roomSettings ?: @{},
             @"requestTimeout":@(self.requestTimeout),
             @"transportOptions":self.transportOptions ?: @{},
             @"turnServers":self.turnServers ?: @[],
             @"iceTransportPolicy":@(self.iceTransportPolicy),
             @"spy":@(self.spy),
             @"appData":self.appData ?: @{}
             };
}

@end


typedef NS_ENUM(NSInteger, RTCRoomNotiType) {
    RTCRoomNotiTypeClosed = 1,
    RTCRoomNotiTypeTransportClosed,
    RTCRoomNotiTypeTransportStats,
    RTCRoomNotiTypeNewPeer,
    RTCRoomNotiTypePeerClosed,
    RTCRoomNotiTypeProducerPaused,
    RTCRoomNotiTypeProducerResumed,
    RTCRoomNotiTypeProducerClosed,
    RTCRoomNotiTypeProducerStats,
    RTCRoomNotiTypeNewConsumer,
    RTCRoomNotiTypeConsumerClosed,
    RTCRoomNotiTypeConsumerPaused,
    RTCRoomNotiTypeConsumerResumed,
    RTCRoomNotiTypeConsumerPreferredProfileSet,
    RTCRoomNotiTypeConsumerEffectiveProfileChanged,
    RTCRoomNotiTypeConsumerStats
};


@interface RTCRoom ()
@property (nonatomic, strong) RTCRoomOptions *settings;
@property (nonatomic, assign) BOOL joined;
@property (nonatomic, assign) BOOL closed;
@property (nonatomic, strong) NSLock *lock;
@end

@implementation RTCRoom

+ (instancetype)constructor:(RTCRoomOptions *)options {
    RTCRoom *room = [RTCRoom new];
    room.settings = options;
    return room;
}

- (instancetype)init {
    if (self = [super init]) {
        self.state = RTCRoomsStateNew;
    }
    return self;
}


#pragma mark - Public Method
- (AnyPromise *)join:(NSString *)peerName appData:(id _Nullable)appData {
    if (self.state != RTCRoomsStateNew && self.state != RTCRoomsStateClosed)
        [self promiseError:[NSString stringWithFormat:@"invalid state -- %ld]", (long)self.state] code:70015];
    
    self.peerName   = peerName;
    self.state      = RTCRoomsStateJoining;
    __block NSDictionary *roomSettings = @{};
    
    kWeakSelf(weakSelf)
    
    return [AnyPromise promiseWithValue:nil].thenInBackground(^(){
        
        if (weakSelf.settings.roomSettings) {
            roomSettings = weakSelf.settings.roomSettings;
            return [AnyPromise promiseWithValue:nil];
        } else {
            
            return [weakSelf sendRequest:@"queryRoom" data:@{@"target":@"room"}].thenInBackground(^(NSDictionary *response){
                roomSettings = response;
                JFLog(@"join() | got Room settings:%@", roomSettings);
            });
            
        }
    }).thenInBackground(^(){
        
        return [CL_RTC_Handler getNativeRtpCapabilities];
        
    }).thenInBackground(^(NSDictionary *nativeRtpCapabilities) {
        
        mt_ortc *ortc = [mt_ortc new];
        
        weakSelf.extendedRtpCapabilities = ortc.getExtendedRtpCapabilities(nativeRtpCapabilities, roomSettings[@"rtpCapabilities"]);
        
        NSArray *unsupportedRoomCodecs = ortc.getUnsupportedCodecs(roomSettings[@"rtpCapabilities"], roomSettings[@"mandatoryCodecPayloadTypes"], weakSelf.extendedRtpCapabilities);
        
        if (unsupportedRoomCodecs.count) {
            JFErrorLog(@"%lu mandatory room codecs not supported:%@", (unsigned long)(unsigned long)unsupportedRoomCodecs.count, unsupportedRoomCodecs);
        }
        
        [weakSelf.canSendByKind setObject:@(ortc.canSend(@"audio", weakSelf.extendedRtpCapabilities)) forKey:@"audio"];
        [weakSelf.canSendByKind setObject:@(ortc.canSend(@"video", weakSelf.extendedRtpCapabilities)) forKey:@"video"];
        
        NSDictionary *effectiveLocalRtpCapabilities = ortc.getRtpCapabilities(weakSelf.extendedRtpCapabilities);

        JFLog(@"join() | effective local RTP capabilities for receiving:%@", effectiveLocalRtpCapabilities);
        
        NSDictionary *data = @{@"target":@"room",
                               @"peerName":weakSelf.peerName,
                               @"rtpCapabilities":effectiveLocalRtpCapabilities,
                               @"spy":@(weakSelf.settings.spy),
                               @"appData":appData ?: @{}};
        
        return [weakSelf sendRequest:@"join" data:data].thenInBackground(^(id response){
            JFLog(@"join : peers \n[%@]", response);
            return response[@"peers"];
        });
        
    }).thenInBackground(^(NSDictionary *peers){
        
        for (NSDictionary *peerData in peers) {
            [weakSelf handlePeerData:peerData];
        }
        
        weakSelf.state =  RTCRoomsStateJoined;
        return weakSelf.peers;
        
    }).catchInBackground(^(NSError *error) {
        JFErrorLog(@"%@", error);
        weakSelf.state = RTCRoomsStateNew;
    });
}


- (void)leave:(id _Nullable)appData {
    JFLog(@"leave");
    if (self.closed) return;
    [self sendNotification:@"leave" data:@{@"appData":appData ?: @{}}];
    
    self.state = RTCRoomsStateClosed;
    
    for (RTCTransport *transport in [self get_Transports]) {
        [transport close:nil];
    }
    
    
    for (RTCProducer *producer in [self get_Producers]) {
        [producer close:nil];
    }
    
    for (RTCPeer *peer in [self get_Peers]) {
        [peer close];
    }
    
    [self.transports removeAllObjects];
    [self.peers removeAllObjects];
    [self.producers removeAllObjects];
    
    if (self.Close_CB) self.Close_CB(@"local", appData);
}

- (void)remoteClose:(id _Nullable)appData {
    if (self.closed) return;
    
    self.state = RTCRoomsStateClosed;
    if (self.Close_CB) self.Close_CB(@"remote", appData);
    
    for (RTCTransport *transport in [self get_Transports]) {
        [transport remoteClose:nil destroy:YES];
    }
    
    for (RTCProducer *producer in [self get_Producers]) {
        [producer remoteClose:nil];
    }
    
    for (RTCPeer *peer in [self get_Peers]) {
        [peer remoteClose:nil];
    }
}

- (BOOL)canSend:(RTCRoomMediaKind)kind {
    if (kind != RTCRoomMediaKindAudio && kind != RTCRoomMediaKindVideo) return NO;

    if (!self.joined || self.settings.spy) return NO;
    return [self.canSendByKind[kind ? @"video" : @"audio"] boolValue];
}

- (RTCTransport *)createTransport:(NSString *)direction appData:(id _Nullable)appData {
    if (!self.joined) {
        JFErrorLog(@"invalid state %ld", (long)self.state);
        return nil;
    }
    
    if (![direction isEqualToString:@"send"] && ![direction isEqualToString:@"recv"]) {
        JFErrorLog(@"Invalid direction %@", direction);
        return nil;
    }
    
    if ([direction isEqualToString:@"send"] && self.settings.spy) {
        JFErrorLog(@"a spy peer cannot send media to the room");
        return nil;
    }
    
    RTCTransport *transport = [RTCTransport shareInstance:direction extendedRtpCapabilities:self.extendedRtpCapabilities settings:[self.settings toDictionary] appData:appData];
    
    [self.lock lock];
    [self.transports setObject:transport forKey:[NSString stringWithFormat:@"%ld", (long)transport.tid]];
    [self.lock unlock];
    
    kWeakSelf(weakSelf)
    transport.Request_CB = ^(NSString * _Nonnull args, NSDictionary * _Nonnull data, RTCTran_CB  _Nullable callback) {
        [weakSelf sendRequest:args data:data].thenInBackground(callback);
    };
    
    transport.Notify_CB = ^(NSString * _Nonnull args, NSDictionary * _Nonnull data, RTCTran_CB  _Nullable callback) {
        JFLog(@"%@", data);
        [weakSelf sendNotification:args data:data];
    };
    
    transport.Close_CB = ^(NSString * _Nullable args,  id _Nullable appData, RTCTransport * _Nonnull obj) {
        [weakSelf.lock lock];
        [weakSelf.transports removeObjectForKey:[NSString stringWithFormat:@"%ld", (long)obj.tid]];
        [weakSelf.lock unlock];
    };
    
    return transport;
}

- (RTCProducer *)createProducer:(RTCMediaStreamTrack *)track options:(NSDictionary * _Nullable)options appData:(id _Nullable )appData {
    if (!self.joined) {
        JFErrorLog(@"Invalid state  %ld", (long)self.state);
        return nil;
    }
    
    if (self.settings.spy) {
        JFErrorLog(@"a spy peer cannot send media to the room");
        return nil;
    }
    
    if (!track) {
        JFErrorLog(@"Create Producer No Track");
        return nil;
    }
    
    if (![self.canSendByKind[track.kind] boolValue]) {
        JFErrorLog(@"cannot send %@", track.kind);
        return nil;
    }
    
    if (track.readyState == RTCMediaStreamTrackStateEnded) {
        JFErrorLog(@"track.readyState is ended");
        return nil;
    }
    
    options = options ?: @{};
    
    RTCProducer *producer = [RTCProducer shareInstance:track peerName:self.peerName options:options appData:appData];

    [self.lock lock];
    [self.producers setObject:producer forKey:[NSString stringWithFormat:@"%ld", (long)producer.pid]];
    [self.lock unlock];
    
    kWeakSelf(weakSelf)
    producer.Close_CB = ^(NSString * _Nonnull args,  id _Nullable appData, RTCProducer * _Nonnull obj) {
        [weakSelf.lock lock];
        [weakSelf.producers removeObjectForKey:[NSString stringWithFormat:@"%ld", (long)obj.pid]];
        [weakSelf.lock unlock];
    };
    return producer;
}

- (void)restartIce {
    if (!self.joined) {
        JFErrorLog(@"restartIce() | invalid state %ld", (long)self.state);
        return;
    }
    
    for (RTCTransport *transport in [self get_Transports]) {
        [transport restartIce];
    }
}

- (AnyPromise *)receiveNotification:(NSDictionary *)notification {
    if (self.closed)    return [self promiseError:@"Room closed" code:70018];
    if (!notification)  return [self promiseError:@"Wrong Notification is nill" code:70019];
    if (![notification[@"notification"] boolValue]) return [self promiseError:@"not a notification" code:70020];
    if (![notification[@"method"] isKindOfClass:[NSString class]]) return [self promiseError:@"wrong/missing notification method" code:70021];
    
    NSString *method = notification[@"method"];
    RTCRoomNotiType type = [self getNotiType:method];
    JFLog(@"😝😝😝😝😝😝\nreceiveNotification() [method:%@, notification:%@]\n 😝😝😝😝😝😝", method, notification);
    
    kWeakSelf(weakSelf)
    return [AnyPromise promiseWithValue:nil].thenInBackground(^(){
        
        NSString *errorDomain = nil;
        
        switch (type) {
            case RTCRoomNotiTypeClosed:
            {
                id appData = notification[@"appData"];
                [weakSelf remoteClose:appData];
            }
                break;
            case RTCRoomNotiTypeTransportClosed:
            {
                NSString *tid = [NSString stringWithFormat:@"%@", notification[@"id"]];
                id appData = notification[@"appData"];
                RTCTransport *transport = weakSelf.transports[tid];
                if (!tid)
                    errorDomain = [NSString stringWithFormat:@"[method: %@] Transport not found [id:%@]", method, tid];
                    else
                        [transport remoteClose:appData destroy:NO];
            }
                break;
            case RTCRoomNotiTypeTransportStats:
            {
                NSString *tid = [NSString stringWithFormat:@"%@", notification[@"id"]];
                id stats = notification[@"stats"];
                RTCTransport *transport = weakSelf.transports[tid];
                [transport remoteStats:stats];
            }
                break;
            case RTCRoomNotiTypeNewPeer:
            {
                NSString *name = notification[@"name"];
                if (weakSelf.peers[name])
                    
                    errorDomain = [NSString stringWithFormat:@"[method: %@] Peer already exists [name: %@]", method, name];
                
                else
                [weakSelf handlePeerData:notification];
            }
                break;
                
            case RTCRoomNotiTypePeerClosed:
            {
                NSString *peerName = notification[@"name"];
                id appData = notification[@"appData"];
                RTCPeer *peer = [weakSelf.peers objectForKey:peerName];
                if (!peer)
                
                    errorDomain = [NSString stringWithFormat:@"[method: %@] No Peer found [name:%@]", method, peerName];
                
                else
                [peer remoteClose:appData];
            }
                break;
            case RTCRoomNotiTypeProducerPaused:
            {
                NSString *pid = [NSString stringWithFormat:@"%@", notification[@"id"]];
                id appData = notification[@"appData"];
                RTCProducer *producer = weakSelf.producers[pid];
                if (!producer)
                    errorDomain = [NSString stringWithFormat:@"[method: %@] No producer found [id: %@]", method, pid];
                else
                    [producer remotePause:appData];
            }
                break;
            case RTCRoomNotiTypeProducerResumed:
            {
                NSString *pid = [NSString stringWithFormat:@"%@", notification[@"id"]];
                id appData = notification[@"appData"];
                RTCProducer *producer = weakSelf.producers[pid];
                if (!producer)
                    errorDomain = [NSString stringWithFormat:@"[method: %@] No producer found [id: %@]", method, pid];
                else
                    [producer remoteResume:appData];
            }
                break;
            case RTCRoomNotiTypeProducerClosed:
            {
                NSString *pid = [NSString stringWithFormat:@"%@", notification[@"id"]];
                id appData = notification[@"appData"];
                RTCProducer *producer = weakSelf.producers[pid];
                if (!producer)
                     errorDomain = [NSString stringWithFormat:@"[method: %@] No producer found [id: %@]", method, pid];
                else
                    [producer remoteClose:appData];
            }
                break;
            case RTCRoomNotiTypeProducerStats:
            {
                NSString *pid = [NSString stringWithFormat:@"%@", notification[@"id"]];
                id stats = notification[@"stats"];
                RTCProducer *producer = weakSelf.producers[pid];
                if (!producer)
                    errorDomain = [NSString stringWithFormat:@"[method: %@] No producer found [id: %@]", method, pid];
                else
                    [producer remoteStats:stats];
            }
                break;
            case RTCRoomNotiTypeNewConsumer:
            {
                NSString *peerName = notification[@"peerName"];
                RTCPeer *peer = weakSelf.peers[peerName];
                if (!peer)
                    errorDomain = [NSString stringWithFormat:@"[method: %@] No Peer found [name: %@]", method, peerName];
                else
                    [weakSelf handleConsumerData:notification peer:peer];
            }
                break;
            case RTCRoomNotiTypeConsumerClosed:
            {
                NSString *cid = [NSString stringWithFormat:@"%@", notification[@"id"]];
                NSString *peerName = notification[@"peerName"];
                RTCPeer *peer = weakSelf.peers[peerName];
                if (!peer) {
                  errorDomain = [NSString stringWithFormat:@"[method: %@] No Peer found [name: %@]", method, peerName];
                } else {
                    
                    RTCConsumer *consumer = [peer getConsumerById:cid];
                    if (!consumer)
                        errorDomain = [NSString stringWithFormat:@"[method: %@] No Consumer found [cid: %ld]", method, (long)consumer.cid];
                    else
                        [consumer remoteClose];
                }
            }
                break;
            case RTCRoomNotiTypeConsumerPaused:
            {
                NSString *cid = [NSString stringWithFormat:@"%@", notification[@"id"]];
                id appData = notification[@"appData"];
                NSString *peerName = notification[@"peerName"];
                RTCPeer *peer = weakSelf.peers[peerName];
                if (!peer) {
                    errorDomain = [NSString stringWithFormat:@"[method: %@] No Peer found [name: %@]", method, peerName];
                } else {
                    
                    RTCConsumer *consumer = [peer getConsumerById:cid];
                    if (!consumer)
                        errorDomain = [NSString stringWithFormat:@"[method: %@] No Consumer found [cid: %ld]", method, (long)consumer.cid];
                    else
                        [consumer remotePause:appData];
                }
            }
                break;
            case RTCRoomNotiTypeConsumerResumed:
            {
                NSString *cid = [NSString stringWithFormat:@"%@", notification[@"id"]];
                id appData = notification[@"appData"];
                NSString *peerName = notification[@"peerName"];
                RTCPeer *peer = weakSelf.peers[peerName];
                if (!peer) {
                    errorDomain = [NSString stringWithFormat:@"[method: %@] No Peer found [name: %@]", method, peerName];
                } else {
                    
                    RTCConsumer *consumer = [peer getConsumerById:cid];
                    if (!consumer)
                        errorDomain = [NSString stringWithFormat:@"[method: %@] No Consumer found [cid: %ld]", method, (long)consumer.cid];
                    else
                        [consumer remoteResume:appData];
                }
            }
                break;
            case RTCRoomNotiTypeConsumerPreferredProfileSet:
            {
                NSString *cid = [NSString stringWithFormat:@"%@", notification[@"id"]];
                NSString *profile = notification[@"profile"];
                NSString *peerName = notification[@"peerName"];
                RTCPeer *peer = weakSelf.peers[peerName];
                if (!peer) {
                    errorDomain = [NSString stringWithFormat:@"[method: %@] No Peer found [name: %@]", method, peerName];
                } else {
                    
                    RTCConsumer *consumer = [peer getConsumerById:cid];
                    if (!consumer)
                        errorDomain = [NSString stringWithFormat:@"[method: %@] No Consumer found [cid: %ld]", method, (long)consumer.cid];
                    else
                        [consumer remoteSetPreferredProfile:profile];
                }
            }
                break;
            case RTCRoomNotiTypeConsumerEffectiveProfileChanged:
            {
                NSString *cid = [NSString stringWithFormat:@"%@", notification[@"id"]];
                NSString *profile = notification[@"profile"];
                NSString *peerName = notification[@"peerName"];
                RTCPeer *peer = weakSelf.peers[peerName];
                if (!peer) {
                    errorDomain = [NSString stringWithFormat:@"[method: %@] No Peer found [name: %@]", method, peerName];
                } else {
                    
                    RTCConsumer *consumer = [peer getConsumerById:cid];
                    if (!consumer)
                        errorDomain = [NSString stringWithFormat:@"[method: %@] No Consumer found [cid: %ld]", method, (long)consumer.cid];
                    else
                        [consumer remoteEffectiveProfileChanged:profile];
                }
            }
                break;
            case RTCRoomNotiTypeConsumerStats:
            {
                NSString *cid = [NSString stringWithFormat:@"%@", notification[@"id"]];
                id stats = notification[@"stats"];
                NSString *peerName = notification[@"peerName"];
                RTCPeer *peer = weakSelf.peers[peerName];
                if (!peer) {
                     errorDomain = [NSString stringWithFormat:@"[method: %@] No Peer found [name: %@]", method, peerName];
                } else {
                    
                    RTCConsumer *consumer = [peer getConsumerById:cid];
                    if (!consumer)
                        errorDomain = [NSString stringWithFormat:@"[method: %@] No Consumer found [cid: %ld]", method, (long)consumer.cid];
                    else
                        [consumer remoteStats:stats];
                }
            }
                break;
            default:
                 errorDomain = [NSString stringWithFormat:@"[method: %@] Unknown notification method", method];
                break;
        }
        
        return errorDomain ? [weakSelf promiseError:errorDomain code:70020] : nil;
        
    }).catchInBackground (^(NSError *error) {
        JFErrorLog(@"receiveNotification() failed [notification:%@]:\n %@", notification, error);
    });
    
}





#pragma mark - Private Method
- (AnyPromise *)sendRequest:(NSString * _Nonnull)method data:(NSDictionary * _Nonnull)data {
    
    NSMutableDictionary *request = [data mutableCopy];
    
    [request setObject:method forKey:@"method"];
    
    if (!data[@"target"]) [request setObject:@"peer" forKey:@"target"];
    
    if (self.closed) {
        JFErrorLog(@"%@", [NSString stringWithFormat:@"sendRequest() | Room closed [method:%@, request:%@]", method, request]);
        return [self promiseError:@"Room closed" code:70016];
    }
    
    kWeakSelf(weakSelf)
    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolver) {
        
        void (^Callback)(id response) = ^(id response) {
            
            if (weakSelf.closed) {
                JFErrorLog(@"request failed [method:%@]: Room closed", method);
                resolver ([NSError errorWithDomain:@"Room closed when Request Success" code:70017 userInfo:nil]);
            }
            
            resolver (response);
        };
        
        if (weakSelf.Request_CB) weakSelf.Request_CB(request, Callback);
    }];
}

- (void)sendNotification:(NSString *)method data:(NSDictionary *)data {
    if (self.closed) return;
    
    NSMutableDictionary *notification = [data mutableCopy];
    
    [notification setObject:method forKey:@"method"];
    [notification setObject:@(YES) forKey:@"notification"];
    
    if (!data[@"target"]) [notification setObject:@"peer" forKey:@"target"];
    
    if (self.Notify_CB) self.Notify_CB(notification, nil);
}

- (void)handlePeerData:(NSDictionary *)peerData {
    NSString *name      = peerData[@"name"];
    id appData          = peerData[@"appData"];
    NSArray *consumers  = peerData[@"consumers"];
    RTCPeer *peer       = [RTCPeer shareInstance:name appData:appData];
    
    [self.lock lock];
    [self.peers setObject:peer forKey:name];
    [self.lock unlock];
    
    kWeakSelf(weakSelf)
    peer.Close_CB = ^(NSString * _Nonnull args,  id _Nullable appData, RTCPeer * _Nonnull obj) {
        [weakSelf.lock lock];
        [weakSelf.peers removeObjectForKey:obj.name];
        [weakSelf.lock unlock];
    };
    
    // Add consumers
    for (NSDictionary *consumerData in consumers) {
        [weakSelf handleConsumerData:consumerData peer:peer];
    }
    
    if (self.joined && self.Newpeer_CB) self.Newpeer_CB(peer);
}

- (void)handleConsumerData:(NSDictionary *)consuemrData peer:(RTCPeer *)peer {
    NSInteger cid               = [consuemrData[@"id"] integerValue];
    NSString *kind              = consuemrData[@"kind"];
    NSDictionary *rtpParameters = consuemrData[@"rtpParameters"];
    BOOL paused                 = [consuemrData[@"paused"] boolValue];
    id appData                  = consuemrData[@"appData"];
    
    RTCConsumer *consumer   = [RTCConsumer shareInstance:cid kind:kind rtpParameters:rtpParameters peer:peer appData:appData];
    
    mt_ortc *ortc = [mt_ortc new];
    
    BOOL supported = ortc.canReceive(consumer.rtpParameters, self.extendedRtpCapabilities);
    
    if (supported) consumer.supported = YES;
    if (paused) [consumer remotePause:nil];
    // 如果会议模式为广播
    if (consumer.mKind == MSMediaKindVideo) {
        // 判断 该 consumer 是否被广播 如果没有被广播则只有主持人可以看, 否则暂停掉
        if (!consumer.broadcast && !(CLOwnData.isHostOrCoHost) && (CLConfData.confSchema == CLConfSchemaSWHB)) {
            [consumer pause:nil];
        }
    }
    
    [peer addConsumer:consumer];
}

#pragma mark - Getter

- (NSArray <RTCTransport *>*)get_Transports {
    return [NSArray arrayWithArray:self.transports.allObjects];
}

- (NSArray <RTCProducer *>*)get_Producers {
    return [NSArray arrayWithArray:self.producers.allObjects];
}

- (NSArray <RTCPeer *>*)get_Peers {
    return [NSArray arrayWithArray:self.peers.allObjects];
}

- (RTCTransport *)getTransportById:(NSInteger)tid {
    return self.transports[[NSString stringWithFormat:@"%ld", (long)tid]];
}

- (RTCProducer *)getProducerById:(NSInteger)pid {
    return self.producers[[NSString stringWithFormat:@"%ld", (long)pid]];
}

- (RTCPeer *)getPeerByName:(NSString *)name {
    return self.peers[name];
}

- (OrderedDictionary <NSString *,RTCTransport *> *)transports {
    if (!_transports)
        _transports = [OrderedDictionary orderedDictionary];
    return _transports;
}

- (OrderedDictionary <NSString *,RTCProducer *> *)producers {
    if (!_producers) _producers = [OrderedDictionary orderedDictionary];
    return _producers;
}

- (OrderedDictionary <NSString *,RTCPeer *> *)peers {
    if (!_peers) _peers = [OrderedDictionary orderedDictionary];
    return _peers;
}

- (NSMutableDictionary *)canSendByKind {
    if (!_canSendByKind) {
        _canSendByKind = [@{
                            @"audio":@(NO),
                            @"video":@(NO)
                            } mutableCopy];
    }
    return _canSendByKind;
}


- (BOOL)joined {
    return self.state == RTCRoomsStateJoined;
}

- (BOOL)closed {
    return self.state == RTCRoomsStateClosed;
}

- (AnyPromise *)promiseError:(NSString *)desc code:(NSInteger)code {
    return [AnyPromise promiseWithValue:[NSError errorWithDomain:desc code:code userInfo:nil]];
}

- (RTCRoomNotiType)getNotiType:(NSString *)type {
    NSArray *arr = @[@"",
                     @"closed", @"transportClosed", @"transportStats",
                     @"newPeer", @"peerClosed", @"producerPaused",
                     @"producerResumed", @"producerClosed", @"producerStats",
                     @"newConsumer", @"consumerClosed", @"consumerPaused",
                     @"consumerResumed", @"consumerPreferredProfileSet", @"consumerEffectiveProfileChanged",
                     @"consumerStats"];
    return [arr indexOfObject:type];
}

- (void)dealloc {
    JFLog(@"🔱🔱%@ dealloc🔱🔱", NSStringFromClass([self class]));
}

@end
