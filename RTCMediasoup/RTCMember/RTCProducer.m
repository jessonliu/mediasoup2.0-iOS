//
//  RTCProducer.m
//  WebRtcRoomIOS
//
//  Created by 刘金丰 on 2019/1/17.
//  Copyright © 2019 wjr. All rights reserved.
//

#import "RTCProducer.h"
#import "J_Utils.h"
#import "RTCTransport.h"
#import "RTCTrack.h"
#import "RTCTrackProtocol.h"
#import "RTCMediaStreamTrack+React.h"
#import <objc/runtime.h>



@interface RTCProducer () {
    NSDictionary *SIMULCAST_DEFAULT;
}

@property (nonatomic, assign) BOOL paused;
@property (nonatomic, assign) MSMediaKind mKind;

@end

@implementation RTCProducer
@synthesize pid = _pid;
@synthesize kind = _kind;
@synthesize peerName = _peerName;
@synthesize source = _source;

+ (instancetype)shareInstance:(RTCMediaStreamTrack *)track peerName:(NSString *)peerName options:(NSDictionary *)options appData:(id _Nullable)appData {
    RTCProducer *producer   = [RTCProducer new];
    producer.track          = track;
    producer.options        = options;
    producer.appData        = appData;
    producer.originalTrack  = track;
    producer.peerName       = peerName;
    producer.pid            = J_Utils.getRandomEightDigitNumber;
    
    if (options && options[@"simulcast"])
        producer.simulcast = @{@"SIMULCAST_DEFAULT":producer->SIMULCAST_DEFAULT, @"simulcast":options[@"simulcast"]};
    else if ([options[@"simulcast"] boolValue] == true)
        producer.simulcast = @{@"SIMULCAST_DEFAULT":producer->SIMULCAST_DEFAULT};
    
    
    producer.locallyPaused  = !track.isEnabled;
    producer.statsInterval  = DEFAULT_STATS_INTERVAL;
    
    return producer;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        SIMULCAST_DEFAULT = @{@"low":@(100000),
                              @"medium":@(300000),
                              @"high":@(1500000)
                              };
    }
    return self;
}

- (void)close:(id _Nullable)appData {
    if (self.closed) return;
    
    if (self.statsEnabled) {
        self.statsEnabled = NO;
        if (self.transport) [self.transport disableProducerStats:self];
    }
    
    if (self.transport) [self.transport removeProducer:self originator:@"local" appData:appData];
    [self destroy];
    if (self.Close_CB) {
        self.Close_CB(@"local", appData, self);
    }
}

- (void)remoteClose:(id _Nullable)appData {
    if (self.closed) return;
    self.closed = YES;
    if (self.transport) [self.transport removeProducer:self originator:@"remote" appData:appData];
    [self destroy];
    self.Close_CB(@"remote", appData, self);
}


- (void)destroy {
    self.transport = nil;
    self.rtpParameters = nil;
    [self.track stop];
    self.track = nil;
}



- (AnyPromise *)send:(RTCTransport *)transport {
    
    if (self.closed)    return [self promiseError:@"Producer closed" code:70011];
    if (self.transport) return [self promiseError:@"already handled by a Transport" code:1];
    if (!transport)     return [self promiseError:@"Transport is nill" code:70013];
    
    self.transport = transport;
    
    kWeakSelf(weakSelf)
    __weak typeof(transport)weakTransport = transport;
    
    return [transport addProducer:self].thenInBackground(^(){
        
        weakTransport.Close_CB = ^(NSString * _Nullable args,  id _Nullable appData, RTCTransport *obj) {
            
            if (weakSelf.closed || obj != weakTransport) return;
            
            [obj removeProducer:weakSelf originator:@"local" appData:nil];
            
            obj = nil;
            weakSelf.rtpParameters  = nil;
            if (weakSelf.Unhandled_CB) weakSelf.Unhandled_CB();
        };
        
        if (weakSelf.Handled_CB) weakSelf.Handled_CB();
        if (weakSelf.statsEnabled) [weakTransport enableProducerStats:weakSelf interval:weakSelf.statsInterval];
        
    }).catchInBackground(^(NSError *error){
        
        weakSelf.transport = nil;
        JFErrorLog(@"%@", error);
        
    });
}

- (BOOL)pause:(id _Nullable)appData {
    if (self.closed) {
        JFErrorLog(@"pause() | Producer closed");
        return NO;
    }
    
    if (self.locallyPaused) return YES;
    self.locallyPaused      = YES;
    self.track.isEnabled    = NO;
    if (self.transport) [self.transport pauseProducer:self appData:appData];
    if (self.Pause_CB)  self.Pause_CB(@"local", appData, self);
    
    return self.paused;
}

- (void)remotePause:(id _Nullable)appData {
    if (self.closed || self.remotelyPaused) return;
    self.remotelyPaused     = YES;
    self.track.isEnabled    = NO;
    if (self.Pause_CB) self.Pause_CB(@"remote", appData, self);
}

- (BOOL)resume:(id _Nullable)appData {
    if (self.closed) {
        JFErrorLog(@"resume() | Producer closed");
        return NO;
    }
    if (!self.locallyPaused) return YES;
    
    self.locallyPaused = NO;
    
    if (!self.remotelyPaused) self.track.isEnabled = YES;
    if (self.transport) [self.transport resumeProducer:self appData:appData];
    if (self.Resume_CB) self.Resume_CB(@"local", appData, self);
    return !self.paused;
}

- (void)remoteResume:(id _Nullable)appData {
    if (self.closed || self.remotelyPaused) return;
    self.remotelyPaused = NO;
    if (!self.locallyPaused) self.track.isEnabled = YES;
    if (self.Resume_CB) self.Resume_CB(@"remote", appData, self);
}


- (AnyPromise *)replaceTrack:(RTCMediaStreamTrack *)track {
    if (self.closed)    return [self promiseError:@"Producer closed" code:70011];
    if (!track)         return [self promiseError:@"no track given" code:70014];
    
    if (track.readyState == RTCMediaStreamTrackStateEnded) return [self promiseError:@"track.readyState is ended " code:70015];
    
    RTCMediaStreamTrack *clonedTrack = track;
    
    kWeakSelf(weakSelf)
    
    return [AnyPromise promiseWithValue:nil].thenInBackground(^(){
        
        if (weakSelf.transport) return [weakSelf.transport replaceProducerTrack:weakSelf track:clonedTrack];
        
        return [weakSelf promiseError:@"replaceTrack but no transport" code:70016];
    }).thenInBackground(^(){
        
        [weakSelf.track stop];
        clonedTrack.isEnabled   = !weakSelf.paused;
        weakSelf.originalTrack  = track;
        weakSelf.track          = clonedTrack;
        
        return weakSelf;
        
    }).catchInBackground(^(NSError *error){
        
        JFErrorLog(@"%@", error);
        
    });
}

- (void)enableStats:(NSInteger)intervale {
    if (!intervale || intervale < DEFAULT_STATS_INTERVAL) intervale = DEFAULT_STATS_INTERVAL;
    
    if (self.closed) {
        JFErrorLog(@"'enableStats() | Producer closed");
        return;
    }
    if (self.statsEnabled) return;
    self.statsInterval = intervale;
    self.statsEnabled = YES;
    if (self.transport) [self.transport enableProducerStats:self interval:self.statsInterval];
}

- (void)disableStats {
    if (self.closed) {
        JFErrorLog(@"'enableStats() | Producer closed");
        return;
    }
    
    if (!self.statsEnabled) return;
    if (self.transport) [self.transport disableProducerStats:self];
}

- (void)remoteStats:(id)stats {
    if (self.Stats_CB) self.Stats_CB(stats, self);
}

- (RTCTrack <RTCTrackProtocol>*)rtcTrack {
    if (!_rtcTrack) {
        _rtcTrack = (RTCTrack <RTCTrackProtocol> *)[RTCTrack createRTCTrack:self.peerName mid:self.pid kind:self.mKind sourceType:self.source];
        [_rtcTrack assignUserName:CLOwnData.nickName];
    }
    _rtcTrack.track = self.track;
    return _rtcTrack;
}


#pragma mark - Setter
- (void)setPid:(NSInteger)pid {
    _pid = pid;
}

- (void)setKind:(NSString *)kind {
    _kind = kind;
}

- (void)setPeerName:(NSString * _Nonnull)peerName {
    _peerName = peerName;
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

- (NSString *)kind {
    if (!_kind) {
        _kind = self.track.kind;
    }
    return _kind;
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

- (NSString *)peerName {
    return _peerName;
}

- (BOOL)paused {
    return self.locallyPaused || self.remotelyPaused;
}


- (AnyPromise *)promiseError:(NSString *)desc code:(NSInteger)code {
    return [AnyPromise promiseWithValue:[NSError errorWithDomain:desc code:code userInfo:nil]];
}

- (void)dealloc {
    JFLog(@"🔱🔱Producer dealloc🔱🔱");
}

@end
