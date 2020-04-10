//
//  RTCConsumer.m
//  WebRtcRoomIOS
//
//  Created by 刘金丰 on 2019/1/20.
//  Copyright © 2019 wjr. All rights reserved.
//

#import "RTCConsumer.h"
#import "RTCPeer.h"
#import "RTCTransport.h"
#import "RTCTrack.h"
#import "RTCMediaStreamTrack+React.h"
#import "CLConsumer.h"


@interface RTCConsumer ()

@end

@implementation RTCConsumer
@synthesize source = _source;

+ (instancetype)shareInstance:(NSInteger)cid kind:(NSString *)kind rtpParameters:(NSDictionary *)rtpParameters peer:(RTCPeer *)peer appData:(id _Nullable)appData {
    RTCConsumer *consumer = [RTCConsumer new];
    consumer.cid            = cid;
    consumer.closed         = NO;
    consumer.kind           = kind;
    consumer.rtpParameters  = rtpParameters;
    consumer.peer           = peer;
    consumer.appData        = appData;
    consumer.supported      = NO;
    consumer.locallyPaused  = NO;
    consumer.remotelyPaused = NO;
    consumer.statsEnabled   = NO;
    consumer.statsInterval  = DEFAULT_STATS_INTERVAL;
    consumer.preferredProfile = @"low";
    consumer.effectiveProfile = @"";
    consumer.dvid           = appData[@"deviceId"];
    consumer.dvName         = appData[@"deviceName"];
    consumer->_broadcast     = [appData[@"broadcast"] boolValue];
    return consumer;
}

- (instancetype)init {
    self = [super init];
    if (self) {

    }
    return self;
}

- (BOOL)getPaused {
    return self.locallyPaused || self.remotelyPaused;
}

- (void)close {
    if (self.closed) return;
    self.closed = true;
    
    if (self.statsEnabled) {
        self.statsEnabled = NO;
        if (self.transport) [self.transport disableConsumerStats:self];
    }
    [self.consumerData assignIsOpen:NO];
    if (self.Close_CB) self.Close_CB(@"local", nil, self);
}

- (void)remoteClose {
    if (self.closed) return;
    self.closed = YES;
    if (self.transport) [self.transport removeConsumer:self];
    [self destroy];
    if (self.Close_CB) self.Close_CB(@"remote", nil, self);
}

- (void)destroy {
    self.transport = nil;
    [self.track stop];
    self.track = nil;
    self.rtpParameters = nil;
    self.consumerData = nil;
}

- (AnyPromise *)receive:(RTCTransport *)transport {
    if (self.closed)        [self promiseError:@"Consumer closed" code:70040];
    if (!self.supported)    [self promiseError:@"unsupported codecs" code:70041];
    if (self.transport)     [self promiseError:@"already handled by a Transport" code:70042];
    
    self.transport = transport;
    kWeakSelf(weakSelf)
    
    __weak typeof(transport)weakTransport = transport;
    
    return [transport addConsumer:self].then(^(RTCMediaStreamTrack *track){
        
        weakSelf.track = track;
        
        if (weakSelf.getPaused) {
            track.isEnabled = NO;
        }

        [weakSelf.consumerData assignIsOpen:track.isEnabled];
        
        weakTransport.Close_CB = ^(NSString * _Nullable args,  id _Nullable appData, RTCTransport *obj) {
            
            if (weakSelf.closed || obj != weakTransport) return;
            
            obj = nil;
            
            [weakSelf.track stop];
            
            weakSelf.track = nil;
            
            if(weakSelf.Unhandled_CB) weakSelf.Unhandled_CB();
            
        };
        
        if (weakSelf.Handled_CB) weakSelf.Handled_CB();
        if (weakSelf.statsEnabled) [weakTransport enableConsumerStats:weakSelf interval:weakSelf.statsInterval];
        
        return weakSelf;
        
    }).catch(^(NSError *error) {
        
        weakSelf.transport = nil;
        JFErrorLog(@"%@", error);
        
    });
}

- (BOOL)pause:(id _Nullable)appData {
    if (self.closed)        return NO;
    if (self.locallyPaused) return YES;
    [self.lock lock];
    self.locallyPaused  = YES;
    if (self.track)     self.track.isEnabled = NO;
    [self.lock unlock];
    if (self.transport) [self.transport pauseConsumer:self appData:appData];
    [self.consumerData assignIsPause:YES];
    if (self.Pause_CB)  self.Pause_CB(@"local", appData, self);
    
    return self.getPaused;
}

- (void)remotePause:(id _Nullable)appData {
    if (self.closed || self.remotelyPaused) return;
    [self.lock lock];
    self.remotelyPaused = YES;
    if (self.track) self.track.isEnabled = NO;
    [self.lock unlock];
    if (self.Pause_CB) self.Pause_CB(@"remote", appData, self);
}

- (BOOL)resume:(id _Nullable)appData {
    if (self.closed)            return YES;
    if (!self.locallyPaused)    return YES;
    if (self.remotelyPaused)    return NO;
    self.locallyPaused = NO;
    [self.lock lock];
    if (self.track && !self.remotelyPaused) self.track.isEnabled = YES;
    [self.lock unlock];
    if (self.transport) [self.transport resumeConsumer:self appData:appData];
    [self.consumerData assignIsPause:NO];
    if (self.Resume_CB) self.Resume_CB(@"local", appData, self);
    return !self.getPaused;
}

- (void)remoteResume:(id _Nullable)appData {
    if (self.closed || !self.remotelyPaused) return;
    self.remotelyPaused = NO;
    if (self.track && !self.locallyPaused) self.track.isEnabled = YES;
    if (self.Resume_CB) self.Resume_CB(@"remote", appData, self);
}

- (void)setPreferredProfile:(NSString *)preferredProfile {
    if (self.closed) return;
    
    if (preferredProfile == _preferredProfile) return;
    
    if (![self.PROFILES containsObject:preferredProfile]) return;
    
    _preferredProfile = preferredProfile;
    
    if (self.transport) [self.transport setConsumerPreferredProfile:self profile:preferredProfile];
}

- (void)remoteSetPreferredProfile:(NSString *)profile {
    if (self.closed || [profile isEqualToString:self.preferredProfile]) return;
    self.preferredProfile = profile;
}


- (void)remoteEffectiveProfileChanged:(NSString *)profile {
    if (self.closed || [self.effectiveProfile isEqualToString:profile]) return;
    self.effectiveProfile = profile;
    if (self.Effectiveprofilechange_CB) self.Effectiveprofilechange_CB(self.effectiveProfile);
}

- (void)enablesStats:(NSInteger)interval {
    if (!interval) interval = DEFAULT_STATS_INTERVAL;
    if (self.closed) return;
    if (self.statsEnabled) return;
    [self.lock lock];
    if (interval < DEFAULT_STATS_INTERVAL) {
        self.statsInterval = DEFAULT_STATS_INTERVAL;
    } else {
        self.statsInterval = interval;
    }
    self.statsEnabled = YES;
    [self.lock unlock];
    if (self.transport) [self.transport enableConsumerStats:self interval:self.statsInterval];
}

- (void)disableStats {
    if (self.closed) return;
    if (!self.statsEnabled) return;
    [self.lock lock];
    self.statsEnabled = NO;
    [self.lock unlock];
    if (self.transport) [self.transport disableConsumerStats:self];
}

- (void)setSupported:(BOOL)supported {
    _supported = supported;
}

- (void)setLocallyPaused:(BOOL)locallyPaused {
    _locallyPaused = locallyPaused;
}

- (void)remoteStats:(id)stats {
    if (self.Stats_CB) self.Stats_CB(stats, self);
}

- (AnyPromise *)promiseError:(NSString *)desc code:(NSInteger)code {
    return [AnyPromise promiseWithValue:[NSError errorWithDomain:desc code:code userInfo:nil]];
}

- (RTCTrack <RTCTrackProtocol>*)rtcTrack {
    if (!_rtcTrack) {
        _rtcTrack = (RTCTrack <RTCTrackProtocol> *)[RTCTrack createRTCTrack:self.peer.name mid:self.cid kind:self.mKind sourceType:self.source];
        [_rtcTrack assignUserName:self.peer.displayName];
    }
    _rtcTrack.track = self.track;
    return _rtcTrack;
}

#pragma mark - Setter

- (void)setBroadcast:(BOOL)broadcast {
    if (_broadcast != broadcast) {
        _broadcast = broadcast;
        NSMutableDictionary *dic = [self.appData mutableCopy];
        [dic setObject:@(broadcast)forKey:@"broadcast"];
        self.appData = [dic copy];
    }
}

#pragma mark - Getter
- (MediaSourceType)source {
    if (!_source) {
        if ([[self.appData allKeys] containsObject:[NSString stringWithFormat:@"source"]]) {
            NSString *sourceStr = self.appData[@"source"];
            if ([sourceStr isEqualToString:@"mic"]) {
                _source = MediaSourceTypeMic;
            } else if ([sourceStr isEqualToString:@"webcam"]) {
                _source = MediaSourceTypeCam;
            } else if ([sourceStr isEqualToString:@"screen"]) {
                _source = MediaSourceTypeScreen;
            } else {
                _source = MediaSourceTypeUnknow;
            }
        } else {
            _source = MediaSourceTypeUnknow;
        }
    }
    return _source;
}

- (MSMediaKind)mKind {
    if ([self.kind isEqualToString:@"video"]) {
        return MSMediaKindVideo;
    }
    if ([self.kind isEqualToString:@"audio"]) {
        return MSMediaKindAudio;
    }
    return MSMediaKindUnknow;
}

- (CLConsumer<CLConsumerProtocol> *)consumerData {
    if (!_consumerData) {
        _consumerData = (CLConsumer <CLConsumerProtocol> *)[[CLConsumer alloc] init:self.peer.name mid:self.cid kind:self.mKind];
        [_consumerData assignConsumer:self];
    }
    return _consumerData;
}

- (NSArray *)PROFILES {
    return @[@"default", @"low", @"medium", @"high"];
}

- (void)dealloc {
    JFLog(@"🔱🔱Consumer dealloc🔱🔱");
}

@end
