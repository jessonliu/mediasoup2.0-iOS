//
//  RTCTransport.m
//  WebRtcRoomIOS
//
//  Created by 刘金丰 on 2019/1/17.
//  Copyright © 2019 wjr. All rights reserved.
//

#import "RTCTransport.h"
#import "J_Utils.h"
#import "RTCCommandQueue.h"
#import "CL_RTC_Handler.h"
#import "RTCProducer.h"
#import "RTCConsumer.h"
#import "JSManager.h"


@interface RTCTransport ()

@property (nonatomic, strong) CL_RTC_Handler *handler;

@property (nonatomic, strong) NSMutableDictionary *localParameters;

@property (nonatomic, strong) RTCCommandQueue *commandQueue;

@end

@implementation RTCTransport
@synthesize tid = _tid;


+ (instancetype)shareInstance:(NSString *)direction extendedRtpCapabilities:(NSDictionary *)extendedRtpCapabilities settings:(NSDictionary *)settings appData:(id _Nullable)appData {
    RTCTransport *transport             = [RTCTransport new];
    transport.tid                       = J_Utils.getRandomEightDigitNumber;
    transport.direction                 = direction;
    transport.settings                  = settings;
    transport.extendedRtpCapabilities   = extendedRtpCapabilities;
    transport.appData                   = appData;
    transport.connectionState           = RTCTranConnectStateNew;
    transport.commandQueue              = [RTCCommandQueue defaultRTCCommandQueue];
    transport.handler                   = [CL_RTC_Handler_Factory createHandlerDirection:direction extendedRtpCapabilities:extendedRtpCapabilities settings:settings];
    [transport _handleHandler];
    return transport;
}



#pragma mark - Publick Method

- (void)close:(id _Nullable)appData {
    if (self.closed) return;
    self.closed = YES;
    
    if (self.statsEnabled) {
        self.statsEnabled = NO;
        [self disableStats];
    }
    
    kWeakSelf(weakSelf)
    [self.commandQueue close:^{
        if (self.Notify_CB) self.Notify_CB(@"closeTransport", @{@"id":@(weakSelf.tid), @"appData":appData ?: @{}}, nil);
        if (weakSelf.Close_CB)  weakSelf.Close_CB(@"close", appData, weakSelf);
    }];
    
    [self destroy];
}

- (void)remoteClose:(id _Nullable)appData destroy:(BOOL)destroy {
    if (self.closed) return;
    
    if (!destroy) {
        [self.handler remoteClose];
        return;
    }
    
    self.closed = YES;
    
    kWeakSelf(weakSelf)
    [self.commandQueue close:^{
        if (weakSelf.Close_CB) weakSelf.Close_CB(@"remote", appData, weakSelf);
    }];
    [self destroy];
}

- (void)destroy {
    [self.handler close];
}

- (void)restartIce {
    if (self.closed) return;
    
    else if (self.connectionState == RTCTranConnectStateNew) return;
    
    kWeakSelf(weakSelf)
    
    [AnyPromise promiseWithValue:nil].then(^(){
        
        id data = @{@"id":@(weakSelf.tid)};
        
        return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolver) {
            
           if (self.Request_CB) weakSelf.Request_CB(@"restartTransport", data, ^(id  _Nonnull response) {
                resolver (response);
            });
            
        }];
        
    }).then(^(NSDictionary *response){
        NSDictionary *remoteIceParameters = response[@"iceParameters"];
        
        return [weakSelf.commandQueue invoke:^AnyPromise *{
            return [weakSelf _execRestartIce:remoteIceParameters];
        }];
        
    }).catchInBackground(^(NSError *error){
        JFErrorLog(@"%@", error);
    });
}

- (void)enableStats:(NSInteger)interval {
    if (!interval || interval < 1000) interval = DEFAULT_STATS_INTERVAL;
    self.statsEnabled = YES;
    
    NSDictionary *data = @{@"id":@(self.tid),
                           @"interval":@(interval)};
    
    if (self.Notify_CB) self.Notify_CB(@"enableTransportStats", data, nil);
}


- (void)disableStats {
    
    self.statsEnabled = NO;
    
    NSDictionary *data = @{@"id":@(self.tid)};
    
    if (self.Notify_CB) self.Notify_CB(@"disableTransportStats", data, nil);
}


#pragma mark - Handler Callback
- (void)_handleHandler {
    
    kWeakSelf(weakSelf)
    
    CL_RTC_Handler *handler = self.handler;
    
    handler.Connectionstatechange_CB = ^(RTCTranConnectState state) {
        
        if (weakSelf.connectionState == state) return;
        weakSelf.connectionState = state;
        if (!weakSelf.closed && weakSelf.Connectionstatechange_CB) weakSelf.Connectionstatechange_CB(state);
        
    };
    
    handler.Needcreatetransport_CB = ^(NSDictionary * _Nullable transportLocalParameters, CL_CT_CB  _Nonnull callback) {
        [weakSelf createTransport:transportLocalParameters callback:callback];
    };
    
    handler.Needupdatetransport_CB = ^(NSDictionary * _Nonnull transportLocalParameters) {
        [weakSelf updateTransport:transportLocalParameters];
    };
}


- (void)createTransport:(NSDictionary *)localParameters callback:(CL_CT_CB)callback {
    
    NSDictionary *para = @{@"id":@(self.tid),
                           @"direction":self.direction,
                           @"options":self.settings[@"transportOptions"],
                           @"appData":self.appData ? : @{}};

    NSMutableDictionary *mul_para = [para mutableCopy];
    
    if (localParameters) {
        NSDictionary *dtlsParameters = localParameters[@"dtlsParameters"];
        NSDictionary *plainRtpParameters = localParameters[@"plainRtpParameters"];
        if (dtlsParameters) [mul_para setObject:dtlsParameters forKey:@"dtlsParameters"];
        if (plainRtpParameters) [mul_para setObject:plainRtpParameters forKey:@"plainRtpParameters"];
    }
    
    if (self.Request_CB) self.Request_CB(@"createTransport", mul_para, ^(id  _Nonnull response) {
        JFLog(@"🌹🌹🌹🌹 %@ -- %@", NSStringFromClass([self class]), response);
        if (!response) return;
        if ([response isKindOfClass:[NSDictionary class]]) callback (response);
    });
    
}

- (void)updateTransport:(NSDictionary *)transportLocalParameters {
    
    NSDictionary *dtlsPara = transportLocalParameters[@"dtlsParameters"];
    NSDictionary *plainRtpParameters = transportLocalParameters[@"plainRtpParameters"];
    
    if (dtlsPara) [self setTransportLocalParameters:dtlsPara];
    
    NSMutableDictionary *data = [@{@"id":@(self.tid)} mutableCopy];
    if (dtlsPara) [data setObject:dtlsPara forKey:@"dtlsParameters"];
    if (plainRtpParameters) [data setObject:plainRtpParameters forKey:@"plainRtpParameters"];
    if (self.Notify_CB) self.Notify_CB(@"updateTransport", data, nil);
    
}


#pragma mark - Public Method

- (AnyPromise *)addProducer:(RTCProducer *)producer {
    kWeakSelf(weakSelf)
    if (self.closed) return [AnyPromise promiseWithValue:[NSError errorWithDomain:@"Transport closed" code:70010 userInfo:nil]];
    
    if (![self.direction isEqualToString:@"send"]) return [AnyPromise promiseWithValue:[NSError errorWithDomain:@"not a sending Transport" code:70010 userInfo:nil]];
    
    return [self.commandQueue invoke:^AnyPromise *{
        return [weakSelf _execAddProducer:producer];
    }];
}

- (void)removeProducer:(RTCProducer *)producer originator:(NSString *)originator appData:(id _Nullable)appData {
    
    kWeakSelf(weakSelf)
    if (!self.closed) [self.commandQueue invoke:^AnyPromise *{
        return [self _execRemoveProducer:producer];
    }];
    
    
    if ([originator isEqualToString:@"local"] && self.Notify_CB) self.Notify_CB(@"closeProducer", @{@"id":@(producer.pid), @"appData":appData ?: @{}}, nil);
}

- (void)pauseProducer:(RTCProducer *)produser appData:(id _Nullable)appData {
    
    NSDictionary *data = @{@"id":@(produser.pid),
                           @"appData":appData ?: @{}};
    
    if (self.Notify_CB) self.Notify_CB(@"pauseProducer", data, nil);
}

- (void)resumeProducer:(RTCProducer *)produser appData:(id _Nullable)appData {
    
    NSDictionary *data = @{@"id":@(produser.pid),
                           @"appData":appData ?: @{}};
    
   if (self.Notify_CB) self.Notify_CB(@"resumeProducer", data, nil);
}

- (AnyPromise *)replaceProducerTrack:(RTCProducer *)producer track:(RTCMediaStreamTrack *)track {
    
    kWeakSelf(weakSelf)
    
    return [self.commandQueue invoke:^AnyPromise *{
       return [weakSelf _execReplaceProducerTrack:producer track:track];
    }];
    
}

- (void)enableProducerStats:(RTCProducer *)producer interval:(NSInteger)interval {
    
    NSDictionary *data = @{@"id":@(producer.pid),
                           @"interval":@(interval)};
    
   if (self.Notify_CB) self.Notify_CB(@"enableProducerStats", data, nil);
}

- (void)disableProducerStats:(RTCProducer *)producer {
    
    NSDictionary *data = @{@"id":@(producer.pid)};
   if (self.Notify_CB) self.Notify_CB(@"disableProducerStats", data, nil);
    
}

- (AnyPromise *)addConsumer:(RTCConsumer *)consumer {
    if (self.closed) return [AnyPromise promiseWithValue:[NSError errorWithDomain:@"Transport closed" code:70010 userInfo:nil]];
    
    if (![self.direction isEqualToString:@"recv"]) return [AnyPromise promiseWithValue:[NSError errorWithDomain:@"not a sending Transport" code:70010 userInfo:nil]];
    
    kWeakSelf(weakSelf)
    return [self.commandQueue invoke:^AnyPromise *{
        return [weakSelf _execAddConsumer:consumer];
    }];
}

- (void)removeConsumer:(RTCConsumer *)consumer {
    kWeakSelf(weakSelf)
    [self.commandQueue invoke:^AnyPromise *{
        return [weakSelf _execRemoveConsumer:consumer];
    }];
}

- (void)pauseConsumer:(RTCConsumer *)consumer appData:(id _Nullable)appData {
    
    NSDictionary *data = @{@"id":@(consumer.cid),
                           @"appData":appData ?: @{}};
    
    if (self.Notify_CB) self.Notify_CB(@"pauseConsumer", data, nil);
}

- (void)resumeConsumer:(RTCConsumer *)consumer appData:(id _Nullable)appData {
    
    NSDictionary *data = @{@"id":@(consumer.cid),
                           @"appData":appData ?: @{}};
    
   if (self.Notify_CB) self.Notify_CB(@"resumeConsumer", data, nil);
}

- (void)setConsumerPreferredProfile:(RTCConsumer *)consumer profile:(NSString *)profile {
    
    NSDictionary *data = @{@"id":@(consumer.cid),
                           @"profile":profile};
    
   if (self.Notify_CB) self.Notify_CB(@"setConsumerPreferredProfile", data, nil);
}

- (void)enableConsumerStats:(RTCConsumer *)consumer interval:(NSInteger)interval {
    
    NSDictionary *data = @{@"id":@(consumer.cid),
                           @"interval":@(interval)};
    
   if (self.Notify_CB) self.Notify_CB(@"enableConsumerStats", data, nil);
}

- (void)disableConsumerStats:(RTCConsumer *)consumer {
    
    NSDictionary *data = @{@"id":@(consumer.cid)};
   if (self.Notify_CB) self.Notify_CB(@"disableConsumerStats", data, nil);
}

- (void)remoteStats:(id)stats {
   if (self.Stats_CB) self.Stats_CB(stats, self);
}


- (BOOL)setBweMinBitrateBps:(nullable NSNumber *)minBitrateBps
          currentBitrateBps:(nullable NSNumber *)currentBitrateBps
              maxBitrateBps:(nullable NSNumber *)maxBitrateBps {
    return [self.handler setBweMinBitrateBps:minBitrateBps currentBitrateBps:currentBitrateBps maxBitrateBps:maxBitrateBps];
}

#pragma mark - Exec Method
- (AnyPromise *)_execAddProducer:(RTCProducer *)producer {
    kWeakSelf(weakSelf)
    __block NSDictionary * producerRtpParameters = @{};
    
    return [AnyPromise promiseWithValue:nil].thenInBackground(^(){
        return [weakSelf.handler addProducer:producer];
    }).thenInBackground(^(NSDictionary *rtpParameters){
        
        producerRtpParameters = rtpParameters;
        
        NSDictionary *data = @{@"id":@(producer.pid),
                               @"kind":producer.kind ?: @"",
                               @"transportId":@(weakSelf.tid),
                               @"rtpParameters":rtpParameters ?: @{},
                               @"paused" : @(producer.locallyPaused),
                               @"appData": producer.appData ?: @{}};
        
        return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolver) {
            
           if (weakSelf.Request_CB)  weakSelf.Request_CB(@"createProducer", data, ^(id  _Nonnull response) {
                resolver(response);
            });
            
        }];
    }).thenInBackground(^(){
        producer.rtpParameters = producerRtpParameters;
    });
}

- (AnyPromise *)_execRemoveProducer:(RTCProducer *)producer {
    return [self.handler removeProducer:producer];
}

- (AnyPromise *)_execReplaceProducerTrack:(RTCProducer *)producer track:(RTCMediaStreamTrack *)track {
    return [self.handler replaceProducerTrack:producer track:track];
}

- (AnyPromise *)_execAddConsumer:(RTCConsumer *)consumer {
    kWeakSelf(weakSelf)
    __block RTCMediaStreamTrack * consumerTrack = nil;
    NSInteger cid = consumer.cid;
    
    return [AnyPromise promiseWithValue:nil].thenInBackground(^(){
        return [weakSelf.handler addConsumer:consumer];
    }).thenInBackground(^(RTCMediaStreamTrack *track){
        
        consumerTrack = track;
        
        NSDictionary *data = @{@"id":@(cid),
                               @"transportId":@(weakSelf.tid),
                               @"paused":@(consumer.locallyPaused),
                               @"preferredProfile":consumer.preferredProfile ?: @""};
        
        return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolver) {
            
            if (weakSelf.Request_CB) weakSelf.Request_CB(@"enableConsumer", data, ^(id  _Nonnull response) {
                resolver (response);
            });
            
        }];
        
    }).thenInBackground(^(NSDictionary *response){
        
        if ([response[@"paused"] boolValue]) [consumer remotePause:nil];
        if (NSString *preferredProfile = response[@"preferredProfile"]) [consumer remoteSetPreferredProfile:preferredProfile];
        NSString *effectiveProfile = response[@"effectiveProfile"];
        if (effectiveProfile && ![effectiveProfile isKindOfClass:[NSNull class]]) [consumer remoteEffectiveProfileChanged:effectiveProfile];
        
        return consumerTrack;
        
    });
}

- (AnyPromise *)_execRemoveConsumer:(RTCConsumer *)consumer {
    return [self.handler removeConsumer:consumer];
}

- (AnyPromise *)_execRestartIce:(NSDictionary *)remoteIceParameters {
    return [self.handler restartIce:remoteIceParameters];
}


#pragma mark - Setter

- (void)setTid:(NSInteger)tid {
    _tid = tid;
}

- (void)setTransportLocalParameters:(NSDictionary *)parameters {
    [self.localParameters setObject:parameters forKey:@"dtlsParameters"];
    self.handler.remoteSdp.transportLocalParameters = [NSMutableDictionary dictionaryWithDictionary:self.localParameters];
}

- (void)setTransportRemoteParameters:(NSDictionary *)paramters {
    self.handler.remoteSdp.transportRemoteParameters = [NSMutableDictionary dictionaryWithDictionary:paramters];
}

#pragma mark - Getter

- (NSMutableDictionary *)localParameters {
    if (!_localParameters) {
        _localParameters = [NSMutableDictionary dictionary];
    }
    return _localParameters;
}

- (void)dealloc {
    JFLog(@"🔱🔱%@ (%@)dealloc🔱🔱", NSStringFromClass([self class]), self.direction);
}

@end
