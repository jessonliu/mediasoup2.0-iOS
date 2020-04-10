//
//  CL_RTC_Handler.m
//  WebRtcRoomIOS
//
//  Created by 刘金丰 on 2019/1/19.
//  Copyright © 2019 wjr. All rights reserved.
//

#import "CL_RTC_Handler.h"
#import "J_Utils.h"
#import "JSManager.h"
#import "RTCProducer.h"
#import "RTCConsumer.h"


NSString *const CL_Direction_Send = @"send";
NSString *const CL_Direction_Recv = @"recv";

@interface CL_RTC_Handler () <RTCPeerConnectionDelegate>

@property (nonatomic, strong) NSLock *lock;

@end

@implementation CL_RTC_Handler
@synthesize direction = _direction;

- (instancetype)initWithDirection:(NSString *)direction rtpParametersByKind:(NSDictionary *)rtpParametersByKind settings:(NSDictionary *)settings {
    self = [super init];
    if (self) {
        self.direction = direction;
        self.rtpParametersByKind = rtpParametersByKind;
        self.settings = settings;
        self.lock = [NSLock new];
        self.peerConnection = [CL_RTC_Handler createPeerConnectionWithDelegate:self];
        self.remoteSdp = [mt_RemoteUnifiedPlanSdp shareRemoteSdp:direction rtpParametersByKind:rtpParametersByKind];
    }
    return self;
}

- (void)close {
    self.lock = nil;
    @try {
        [self.peerConnection close];
        JFErrorLog(@"==============%@",self.peerConnection);
    } @catch (NSException *exception) {
        JFErrorLog(@"%@", exception);
    }
}

- (void)remoteClose {
    self.transportReady = NO;
    if (self.transportUpdated) self.transportUpdated = NO;
}

- (BOOL)setBweMinBitrateBps:(nullable NSNumber *)minBitrateBps
          currentBitrateBps:(nullable NSNumber *)currentBitrateBps
              maxBitrateBps:(nullable NSNumber *)maxBitrateBps {
    return [self.peerConnection setBweMinBitrateBps:minBitrateBps currentBitrateBps:currentBitrateBps maxBitrateBps:maxBitrateBps];
}

+ (NSArray *)enumerateDevices {
    NSMutableArray *devices = [NSMutableArray array];
    NSArray *videoDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in videoDevices) {
        [devices addObject:@{
                             @"deviceId": device.uniqueID,
                             @"groupId": @"",
                             @"label": device.localizedName,
                             @"kind": @"videoinput",
                             }];
    }
    NSArray *audioDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio];
    for (AVCaptureDevice *device in audioDevices) {
        [devices addObject:@{
                             @"deviceId": device.uniqueID,
                             @"groupId": @"",
                             @"label": device.localizedName,
                             @"kind": @"audioinput",
                             }];
    }
    return devices;
}

- (RTCPeerConnection *)peerConnection {
    return _peerConnection;
}

#pragma mark - Class Method
+ (RTCPeerConnection *)createPeerConnectionWithDelegate:(id)objc {
    
    RTCPeerConnectionFactory *factory = [CL_RTC_Handler getFactory];
    RTCConfiguration *configuration     = [[RTCConfiguration alloc] init];
    configuration.iceServers            = @[];
    configuration.iceTransportPolicy    = RTCIceTransportPolicyAll;
    configuration.bundlePolicy          = RTCBundlePolicyMaxBundle;
    configuration.rtcpMuxPolicy         = RTCRtcpMuxPolicyRequire;
    configuration.sdpSemantics          = RTCSdpSemanticsUnifiedPlan;
    
    RTCPeerConnection *peerConnection   = [factory peerConnectionWithConfiguration:configuration constraints:CL_RTC_Handler.createMediaConstraints delegate:objc];
    return peerConnection;
}

+ (RTCPeerConnectionFactory *)getFactory {
    RTCDefaultVideoEncoderFactory *encoderFactory = [[RTCDefaultVideoEncoderFactory alloc] init];
    RTCDefaultVideoDecoderFactory *decoderFactory = [[RTCDefaultVideoDecoderFactory alloc] init];
    RTCVideoCodecInfo *codecInfo = [[RTCVideoCodecInfo alloc] initWithName:@"VP8"];
    encoderFactory.preferredCodec = codecInfo;
    
    RTCPeerConnectionFactory *factory   = [[RTCPeerConnectionFactory alloc] initWithEncoderFactory:encoderFactory decoderFactory:decoderFactory];
    return factory;
}


- (void)setLocalOfferDescription:(CL_Handler_Complete)complete {
    __weak typeof(self)weakSelf = self;
    [self.peerConnection offerForConstraints:CL_RTC_Handler.creatAnswerOrOfferConstraint completionHandler:^(RTCSessionDescription * _Nullable sdp, NSError * _Nullable error) {
        if (error) {
            complete(nil, error);
            return;
        }
        [weakSelf.peerConnection setLocalDescription:sdp completionHandler:^(NSError * _Nullable error) {
            complete(sdp.sdp, error);
        }];
    }];
}

- (void)setLocalAnswerDescription:(CL_Handler_Complete)complete {
    kWeakSelf(weakSelf)
    [self.peerConnection answerForConstraints:CL_RTC_Handler.creatAnswerOrOfferConstraint completionHandler:^(RTCSessionDescription * _Nullable sdp, NSError * _Nullable error) {
        if (error) {
            complete(nil, error);
            return;
        }
        [weakSelf.peerConnection setLocalDescription:sdp completionHandler:^(NSError * _Nullable error) {
            complete(sdp.sdp, error);
        }];
    }];
}


// MediaConstraints
+ (RTCMediaConstraints *)createMediaConstraints {
    RTCMediaConstraints *media_constraints = [[RTCMediaConstraints alloc] initWithMandatoryConstraints:@{kRTCMediaConstraintsOfferToReceiveAudio:kRTCMediaConstraintsValueTrue,kRTCMediaConstraintsOfferToReceiveVideo:kRTCMediaConstraintsValueTrue} optionalConstraints:nil];
    return media_constraints;
}

/**
 *  设置offer/answer的约束
 */
+ (RTCMediaConstraints *)creatAnswerOrOfferConstraint {
    return [CL_RTC_Handler creatConstraintWithOption:nil];
}


+ (RTCMediaConstraints *)creatConstraintWithOption:(NSDictionary * _Nullable)optional {
    RTCMediaConstraints *constraints = [[RTCMediaConstraints alloc] initWithMandatoryConstraints:@{kRTCMediaConstraintsOfferToReceiveAudio:kRTCMediaConstraintsValueTrue,kRTCMediaConstraintsOfferToReceiveVideo:kRTCMediaConstraintsValueTrue} optionalConstraints:optional];
    return constraints;
}


+ (AnyPromise *)getNativeRtpCapabilities {
    RTCPeerConnection *peerConnection   = [CL_RTC_Handler createPeerConnectionWithDelegate:nil];
    [peerConnection addTransceiverOfType:RTCRtpMediaTypeAudio];
    [peerConnection addTransceiverOfType:RTCRtpMediaTypeVideo];
    __weak typeof(peerConnection)weakPeerConnection = peerConnection;
    
    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolver) {
        [peerConnection offerForConstraints:CL_RTC_Handler.creatAnswerOrOfferConstraint completionHandler:^(RTCSessionDescription * _Nullable sdp, NSError * _Nullable error) {
            @try {
                
                [weakPeerConnection close];
                
            } @catch (NSException *exception) {
                JFErrorLog(@"%@", exception);
            }
            if (error) {
                resolver (error);
            }
            else {
                NSDictionary *nativeRtpCapabilities = [J_Utils extractRtpCapabilities:sdp.sdp];
                resolver(nativeRtpCapabilities);
            }
        }];
    }].catchInBackground(^(NSError *error) {
        @try {
            [weakPeerConnection close];
        } @catch (NSException *exception) {
            JFErrorLog(@"%@", exception);
        }
        JFErrorLog(@"%@", error);
    });
    
}


#pragma mark - Setter
- (void)setDirection:(NSString * _Nonnull)direction {
    _direction = direction;
}


#pragma mark - Getter



#pragma mark - RTCPeerConnectionDelegate
- (void)peerConnection:(nonnull RTCPeerConnection *)peerConnection didAddStream:(nonnull RTCMediaStream *)stream {
}

- (void)peerConnection:(nonnull RTCPeerConnection *)peerConnection didChangeIceConnectionState:(RTCIceConnectionState)newState {
    if (!self.Connectionstatechange_CB) return;
    switch (newState) {
        case RTCIceConnectionStateChecking:
            self.Connectionstatechange_CB(RTCTranConnectStateConnecting);
            break;
        case RTCIceConnectionStateConnected:
            break;
        case RTCIceConnectionStateCompleted:
            self.Connectionstatechange_CB(RTCTranConnectStateConnected);
            break;
        case RTCIceConnectionStateFailed:
            self.Connectionstatechange_CB(RTCTranConnectStateFailed);
            break;
        case RTCIceConnectionStateDisconnected:
            self.Connectionstatechange_CB(RTCTranConnectStateDisconnected);
            break;
        case RTCIceConnectionStateClosed:
            self.Connectionstatechange_CB(RTCTranConnectStateClosed);
            break;
        default:
            break;
    }
}

- (void)peerConnection:(nonnull RTCPeerConnection *)peerConnection didChangeIceGatheringState:(RTCIceGatheringState)newState {
    
}

- (void)peerConnection:(nonnull RTCPeerConnection *)peerConnection didChangeSignalingState:(RTCSignalingState)stateChanged {
    
}

- (void)peerConnection:(nonnull RTCPeerConnection *)peerConnection didGenerateIceCandidate:(nonnull RTCIceCandidate *)candidate {
    
}

- (void)peerConnection:(nonnull RTCPeerConnection *)peerConnection didOpenDataChannel:(nonnull RTCDataChannel *)dataChannel {
    
}

- (void)peerConnection:(nonnull RTCPeerConnection *)peerConnection didRemoveIceCandidates:(nonnull NSArray<RTCIceCandidate *> *)candidates {
    
}

- (void)peerConnection:(nonnull RTCPeerConnection *)peerConnection didRemoveStream:(nonnull RTCMediaStream *)stream {
    
}

- (void)peerConnectionShouldNegotiate:(nonnull RTCPeerConnection *)peerConnection {
    
}


- (void)peerConnection:(RTCPeerConnection *)peerConnection didStartReceivingOnTransceiver:(RTCRtpTransceiver *)transceiver {
    
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didAddReceiver:(RTCRtpReceiver *)rtpReceiver streams:(NSArray<RTCMediaStream *> *)mediaStreams {
    
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didRemoveReceiver:(RTCRtpReceiver *)rtpReceiver {
    
}

#pragma mark - Dealloc
- (void)dealloc {
    JFLog(@"🍎🍎🍎%@ dealloc🍎🍎🍎", NSStringFromClass([self class]));
}

@end


@interface CL_RTC_SendHandler ()

@property (nonatomic, strong) NSMutableArray <NSString *>*track_ids;

@end

@implementation CL_RTC_SendHandler

- (instancetype)initWithDirection:(NSString *)direction rtpParametersByKind:(NSDictionary *)rtpParametersByKind settings:(NSDictionary *)settings {
    self = [super initWithDirection:direction rtpParametersByKind:rtpParametersByKind settings:settings];
    if (self) {

    }
    return self;
}

#pragma mark - Publick Method
- (AnyPromise *)addProducer:(RTCProducer *)producer {
    
    RTCMediaStreamTrack *track = producer.track;
    if ([self.track_ids containsObject:track.trackId])
        return [AnyPromise promiseWithValue:[NSError errorWithDomain:@"该track 已存在, 不能重复添加" code:70005 userInfo:nil]];
    
    [self.lock lock];
    [self.track_ids addObject:track.trackId];
    [self.lock unlock];
    
    RTCRtpTransceiver *transceiver = nil;
    for (RTCRtpTransceiver *t in self.peerConnection.transceivers) {
        if ([t.receiver.track.kind isEqualToString:track.kind] && (t.direction == RTCRtpTransceiverDirectionInactive)) {
            transceiver = t;
            break;
        }
    }
    
    if (transceiver) {
        transceiver.direction       = RTCRtpTransceiverDirectionSendOnly;
        transceiver.sender.track    = track;
    } else {
        RTCRtpTransceiverInit *transceiverInit = [[RTCRtpTransceiverInit alloc] init];
        transceiverInit.direction = RTCRtpTransceiverDirectionSendOnly;
        transceiver = [self.peerConnection addTransceiverWithTrack:track init:transceiverInit];
    }
    
    __weak typeof(producer)weakProducer = producer;
    kWeakSelf(weakSelf)

    return [AnyPromise promiseWithResolverBlock:^(PMKResolver _Nonnull resolver) {
        [self.peerConnection offerForConstraints:CL_RTC_Handler.creatAnswerOrOfferConstraint completionHandler:^(RTCSessionDescription * _Nullable sdp, NSError * _Nullable error) {
            if (error) {
                resolver (error);
            } else {
                RTCSessionDescription *offerSdp = sdp;
                if (producer.simulcast) {
                    NSDictionary *sdpObj    = [J_Utils sdpTransportToDictionary:sdp.sdp];
                    NSDictionary *trackDic  = @{@"id":producer.track.trackId, @"kind":producer.track.kind};
                    NSDictionary *para = @{@"sdpObj":sdpObj,
                                           @"track":trackDic,
                                           @"mid":transceiver.mid ?: @""};
                    sdpObj = [mt_unifiedPlanUtils new].addPlanBSimulcast(para);
                    if (sdpObj) {
                        NSString *sdpStr = [J_Utils transportToNativeSdp:sdpObj];
                        offerSdp = [[RTCSessionDescription alloc] initWithType:RTCSdpTypeOffer sdp:sdpStr];
                        JFLog(@"simulcast:sdp\n %@", sdpStr);
                    }
                }
                [weakSelf.peerConnection setLocalDescription:offerSdp completionHandler:^(NSError * _Nullable error) {
                    resolver (error);
                }];
            }
        }];
        
    }].thenInBackground(^(){
        
        return !weakSelf.transportReady ? [weakSelf setupTransport] : nil;
        
    }).thenInBackground(^(){
        
        return [AnyPromise promiseWithResolverBlock:^(PMKResolver _Nonnull resolver) {
            
            NSDictionary *localSdp              = [J_Utils sdpTransportToDictionary:weakSelf.peerConnection.localDescription.sdp];
            NSString *sdp                       = weakSelf.remoteSdp.send_createAnswerSdp(localSdp);
            RTCSessionDescription *remoteSdp    = [[RTCSessionDescription alloc] initWithType:RTCSdpTypeAnswer sdp:sdp];
            
            [weakSelf.peerConnection setRemoteDescription:remoteSdp completionHandler:^(NSError * _Nullable error) {
                resolver (localSdp);
            }];
            
        }];
        
    }).thenInBackground(^(NSDictionary *localSdp){
        
        NSDictionary *rtpParameters = weakSelf.rtpParametersByKind[producer.track.kind];
        
        if (!producer.track) return rtpParameters;
        
        NSDictionary *trackDic      = @{@"id":producer.track.trackId, @"kind":producer.track.kind};
        
        NSDictionary *para          = @{@"rtpParameters":rtpParameters,
                                        @"sdpObj":localSdp,
                                        @"track":trackDic,
                                        @"options":@{
                                                @"mid":transceiver.mid,
                                                @"planBSimulcast":@(true)
                                                }
                                        };
        
        rtpParameters               = [mt_unifiedPlanUtils new].fillRtpParametersForTrack(para);
        
        weakProducer.rtpParameters  = rtpParameters;
        
        return rtpParameters;
    });
}

- (AnyPromise *)removeProducer:(RTCProducer *)producer {
    
    RTCMediaStreamTrack *track = producer.track;
    
    if (![self.track_ids containsObject:track.trackId]) {
        JFErrorLog(@"track not found");
        return [AnyPromise promiseWithValue:[NSError errorWithDomain:@"" code:70006 userInfo:nil]];
    }
    
    RTCRtpSender *rtpSender = nil;
    for (RTCRtpSender *s in self.peerConnection.senders) {
        if ([s.track isEqual:track]) {
            rtpSender = s;
            break;
        }
    }
    
    if (!rtpSender) JFErrorLog(@"local track not found");
    
    [self.peerConnection removeTrack:rtpSender];
    
    [self.lock lock];
    [self.track_ids removeObject:track.trackId];
    [self.lock unlock];
    
    kWeakSelf(weakSelf)
    
    return
    [AnyPromise promiseWithResolverBlock:^(PMKResolver _Nonnull resolver) {
        
        [weakSelf setLocalOfferDescription:^(NSString *sdp, NSError * _Nonnull error) {
            resolver(error);
        }];
        
    }].then(^(){
        
        NSDictionary *localSdp              = [J_Utils sdpTransportToDictionary:weakSelf.peerConnection.localDescription.sdp];
        NSString *sdp                       = weakSelf.remoteSdp.send_createAnswerSdp(localSdp);

        RTCSessionDescription *remoteSdp    = [[RTCSessionDescription alloc] initWithType:RTCSdpTypeAnswer sdp:sdp];
        
        return [AnyPromise promiseWithResolverBlock:^(PMKResolver _Nonnull resolver) {
            
            [weakSelf.peerConnection setRemoteDescription:remoteSdp completionHandler:^(NSError * _Nullable error) {
                resolver (error);
            }];
            
        }];
        
    }).catchInBackground(^(NSError *error){
        JFErrorLog(@"%@", error);
    });
}

- (AnyPromise *)replaceProducerTrack:(RTCProducer *)producer track:(RTCMediaStreamTrack *)track {
    RTCMediaStreamTrack *oldTrack = producer.track;
    
    kWeakSelf(weakSelf)
    return [AnyPromise promiseWithValue:nil].thenInBackground(^(){
        
        RTCRtpSender *rtpSender = nil;
        
        for (RTCRtpSender *s in weakSelf.peerConnection.senders) {
            if ([s.track isEqual:oldTrack]) {
                rtpSender = s;
                break;
            }
        }
        
        if (!rtpSender) JFErrorLog(@"local track not found");
        rtpSender.track = track;
       
    }).thenInBackground(^(){
        [weakSelf.lock lock];
        [weakSelf.track_ids removeObject:oldTrack.trackId];
        [weakSelf.track_ids addObject:track.trackId];
        [weakSelf.lock unlock];
    });
   
}



- (AnyPromise *)restartIce:(NSDictionary *)remoteIceParameters {
    kWeakSelf(weakSelf)
    [self.remoteSdp updateTransportRemoteIceParameters:remoteIceParameters];
    
    return
    [AnyPromise promiseWithResolverBlock:^(PMKResolver _Nonnull resolver) {
        
        RTCMediaConstraints *constraints = [CL_RTC_Handler creatConstraintWithOption:@{kRTCMediaConstraintsIceRestart:@(true)}];
        
        [weakSelf.peerConnection offerForConstraints:constraints completionHandler:^(RTCSessionDescription *sdp, NSError *error) {
            
            [weakSelf.peerConnection setLocalDescription:sdp completionHandler:^(NSError *error) {
                resolver (error);
            }];
            
        }];
        
    }].thenInBackground(^(){
        
        NSDictionary *localSdp              = [J_Utils sdpTransportToDictionary:weakSelf.peerConnection.localDescription.sdp];
        NSString *sdp                       = weakSelf.remoteSdp.send_createAnswerSdp(localSdp);
        RTCSessionDescription *remoteSdp    = [[RTCSessionDescription alloc] initWithType:RTCSdpTypeAnswer sdp:sdp];
        
        return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolver) {
            
            [weakSelf.peerConnection setRemoteDescription:remoteSdp completionHandler:^(NSError * _Nullable error) {
                resolver (error);
            }];
            
        }];
        
    }).catchInBackground(^(NSError *error){
        JFErrorLog(@"%@", error);
    });
}

- (AnyPromise *)setupTransport {
    kWeakSelf(weakSelf)
    
    NSString *sdp           = self.peerConnection.localDescription.sdp;
    NSDictionary *localSdp  = [J_Utils sdpTransportToDictionary:sdp];
    NSDictionary *dtlsPara  = [mt_commonUtils new].extractDtlsParameters(localSdp);
    NSMutableDictionary *mul_dtlsParameters = [NSMutableDictionary dictionaryWithDictionary:dtlsPara];
    
    if (dtlsPara) {
        [mul_dtlsParameters setObject:@"server" forKey:@"role"];
        [self.remoteSdp.transportLocalParameters setObject:mul_dtlsParameters forKey:@"dtlsParameters"];
    }
    
    return [AnyPromise promiseWithResolverBlock:^(PMKResolver _Nonnull resolver) {
        
        NSMutableDictionary *parameters = [@{@"dtlsParameters":mul_dtlsParameters} mutableCopy];
        
        weakSelf.Needcreatetransport_CB(parameters, ^(id  _Nonnull data) {
            resolver (data);
        });
        
    }].thenInBackground(^(id data){
        [weakSelf.lock lock];
        weakSelf.remoteSdp.transportRemoteParameters = [NSMutableDictionary dictionaryWithDictionary:data];
        weakSelf.transportReady = YES;
        [weakSelf.lock unlock];
    });
}

#pragma mark - Getter
- (NSMutableArray<NSString *> *)track_ids {
    if (!_track_ids) {
        _track_ids = [@[] mutableCopy];
    }
    return _track_ids;
}

@end


@interface CL_RTC_RecvHandler ()
@property (nonatomic, strong) M13MutableOrderedDictionary <NSString *, NSDictionary *>*consumerInfos;
@property (nonatomic, strong) RTCCallbackLogger *callBackLogger;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) RTCMediaStreamTrack *track;

@end
@implementation CL_RTC_RecvHandler

- (instancetype)initWithDirection:(NSString *)direction rtpParametersByKind:(NSDictionary *)rtpParametersByKind settings:(NSDictionary *)settings {
    self = [super initWithDirection:direction rtpParametersByKind:rtpParametersByKind settings:settings];
    if (self) {
//        self.callBackLogger = [RTCCallbackLogger new];
//        self.callBackLogger.severity = RTCLoggingSeverityError;
//        [self.callBackLogger startWithMessageAndSeverityHandler:^(NSString * _Nonnull message, RTCLoggingSeverity severity) {
//            JFLog(@"%@", message);
//        }];
    }
    return self;
}

- (void)startTimer {
    if (self.timer) return;
    self.timer = [NSTimer timerWithTimeInterval:1 target:self selector:@selector(timerAction) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
    [self.timer fire];
}

- (void)timerAction {
    [self.peerConnection statsForTrack:self.track statsOutputLevel:RTCStatsOutputLevelDebug completionHandler:^(NSArray<RTCLegacyStatsReport *> * _Nonnull stats) {
        JFErrorLog(@"================================== \n%@\n===============================", stats);
    }];
}

- (void)close {
    [super close];
    [self.consumerInfos removeAllObjects];
    self.consumerInfos = nil;
}

- (AnyPromise *)addConsumer:(RTCConsumer *)consumer {
    
    NSString *cid = [NSString stringWithFormat:@"%ld", (long)consumer.cid];
    
    if ([self.consumerInfos.allKeys containsObject:cid]) return [AnyPromise promiseWithValue:[NSError errorWithDomain:@"Consumer already added" code:70007 userInfo:nil]];
    
    NSDictionary *consumerInfo  = [self getConsumerInfoWithConsumer:consumer];
    NSString *mid               = consumerInfo[@"mid"];
    
    [self.lock lock];
    [self.consumerInfos setObject:consumerInfo forKey:cid];
    [self.lock unlock];
    
    kWeakSelf(weakSelf)
    
    return
    [AnyPromise promiseWithValue:nil].thenInBackground(^(){
        
        return !weakSelf.transportReady ? [weakSelf setupTransport] : nil;
        
    }).thenInBackground(^(){
        
        NSString *sdpStr = weakSelf.remoteSdp.recv_createOfferSdp(weakSelf.consumerInfos.allObjects);
        
        JFLog(@"==========\n%@", sdpStr);

        RTCSessionDescription *remoteSdp = [[RTCSessionDescription alloc] initWithType:RTCSdpTypeOffer sdp:sdpStr];
        
        return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolver) {
            
            [weakSelf.peerConnection setRemoteDescription:remoteSdp completionHandler:^(NSError * _Nullable error) {
                
                if (error) resolver(error);
                
                [weakSelf setLocalAnswerDescription:^(NSString *sdp, NSError * _Nonnull error) {
                    resolver(error);
                }];
                
            }];
            
        }];
        
    }).thenInBackground(^(){
        
        if (!weakSelf.transportUpdated) [weakSelf updateTransport];
        
    }).thenInBackground(^(){
        
        NSArray <RTCRtpTransceiver *>*transceivers = weakSelf.peerConnection.transceivers;
        RTCMediaStreamTrack *track_obj = nil;
        
        for (RTCRtpTransceiver *t in transceivers) {
            if ([t.mid isEqualToString:mid]) {
                track_obj = t.receiver.track;
                break;
            }
        }
        
        return track_obj;
        
    }).catchInBackground(^(NSError *error){
        
        JFErrorLog(@"%@", error);
        
    });
}

- (AnyPromise *)removeConsumer:(RTCConsumer *)consumer {
    
    NSString *cid = [NSString stringWithFormat:@"%ld", (long)consumer.cid];
    
    NSMutableDictionary *consumerInfo = [self.consumerInfos[cid] mutableCopy];
    
    if (!consumerInfo) return [AnyPromise promiseWithValue:[NSError errorWithDomain:@"Consumer not found" code:70008 userInfo:nil]];
    
    [self.lock lock];
    [consumerInfo setObject:@(YES) forKey:@"closed"];
    [self.consumerInfos setObject:consumerInfo forKey:cid];
    [self.lock unlock];
    
    kWeakSelf(weakSelf)
    
    return
    [AnyPromise promiseWithResolverBlock:^(PMKResolver resolver) {
        NSString *sdpStr                    = weakSelf.remoteSdp.recv_createOfferSdp(weakSelf.consumerInfos.allObjects);
        RTCSessionDescription *remoteSdp    = [[RTCSessionDescription alloc] initWithType:RTCSdpTypeOffer sdp:sdpStr];
        
        [weakSelf.peerConnection setRemoteDescription:remoteSdp completionHandler:^(NSError * _Nullable error) {
            resolver (error);
        }];
        
    }].thenInBackground(^(){
        
        return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolver) {
            
            [weakSelf setLocalAnswerDescription:^(NSString *sdp, NSError * _Nonnull error) {
                resolver (error);
            }];
            
        }];
    }).catchInBackground(^(NSError *error){
        JFErrorLog(@"%@", error);
    });
}

- (AnyPromise *)restartIce:(NSDictionary *)remoteIceParameters {
    
    [self.remoteSdp updateTransportRemoteIceParameters:remoteIceParameters];
    kWeakSelf(weakSelf)
    
    return
    [AnyPromise promiseWithResolverBlock:^(PMKResolver resolver) {
        
        NSString *sdpStr = weakSelf.remoteSdp.recv_createOfferSdp(weakSelf.consumerInfos.allObjects);
        RTCSessionDescription *remoteSdp = [[RTCSessionDescription alloc] initWithType:RTCSdpTypeOffer sdp:sdpStr];
        
        [weakSelf.peerConnection setRemoteDescription:remoteSdp completionHandler:^(NSError * _Nullable error) {
            resolver (error);
        }];
        
    }].thenInBackground(^(){
        
        return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolver) {
            
            [weakSelf setLocalAnswerDescription:^(NSString *sdp, NSError * _Nonnull error) {
                resolver (error);
            }];
            
        }];
        
    }).catchInBackground(^(NSError *error){
        JFErrorLog(@"%@", error);
    });
}

- (AnyPromise *)setupTransport {
    kWeakSelf(weakSelf)
    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolver) {
        
        weakSelf.Needcreatetransport_CB(nil, ^(id  _Nonnull data) {
            resolver (data);
        });
        
    }].thenInBackground(^(id data){
        [weakSelf.lock lock];
        weakSelf.remoteSdp.transportRemoteParameters = [NSMutableDictionary dictionaryWithDictionary:data];
        weakSelf.transportReady = YES;
        [weakSelf.lock unlock];
    });
}


- (void)updateTransport {
    NSString *sdp                   = self.peerConnection.localDescription.sdp;
    NSDictionary *sdpObj            = [J_Utils sdpTransportToDictionary:sdp];
    NSDictionary *dtlsParameters    = [mt_commonUtils new].extractDtlsParameters(sdpObj);
    
    NSMutableDictionary *transportLocalParameters = [NSMutableDictionary dictionary];
    
    [transportLocalParameters setObject:dtlsParameters forKey:@"dtlsParameters"];
    
    if (self.Needupdatetransport_CB) self.Needupdatetransport_CB(transportLocalParameters);
    
    self.transportUpdated = YES;
}


- (NSDictionary *)getConsumerInfoWithConsumer:(RTCConsumer *)consumer {
    NSDictionary *encoding  = consumer.rtpParameters[@"encodings"][0];
    NSString *cname         = consumer.rtpParameters[@"rtcp"][@"cname"];
    NSString *streamId      = [NSString stringWithFormat:@"recv-stream-%ld", (long)consumer.cid];
    NSString *trackId       = [NSString stringWithFormat:@"consumer-%@-%ld",  consumer.kind, (long)consumer.cid];
    NSString *mid           = [NSString stringWithFormat:@"%@%ld", [consumer.kind substringWithRange:NSMakeRange(0, 1)], (long)consumer.cid];
    
    NSDictionary *consumerInfo = @{@"mid":mid,
                                   @"kind":consumer.kind,
                                   @"closed":@(consumer.closed),
                                   @"streamId":streamId,
                                   @"trackId":trackId,
                                   @"ssrc":encoding[@"ssrc"],
                                   @"cname":cname };
    
    NSMutableDictionary *mul_consumerInfo   = [NSMutableDictionary dictionaryWithDictionary:consumerInfo];
    NSDictionary *rtx                       = encoding[@"rtx"];
    if (rtx && rtx[@"ssrc"]) [mul_consumerInfo setObject:rtx[@"ssrc"] forKey:@"rtxSsrc"];
    return mul_consumerInfo;
}



- (M13MutableOrderedDictionary<NSString *,NSDictionary *> *)consumerInfos {
    if (!_consumerInfos) {
        _consumerInfos = [M13MutableOrderedDictionary orderedDictionary];
    }
    return _consumerInfos;
}
@end



@implementation CL_RTC_Handler_Factory


+ (CL_RTC_Handler *)createHandlerDirection:(NSString *)direction extendedRtpCapabilities:(NSDictionary *)extendedRtpCapabilities settings:(NSDictionary *)settings {
    
    CL_RTC_Handler *handler = nil;
    NSDictionary *rtpParametersByKind = nil;
    mt_ortc *ortc = [mt_ortc new];
    if ([direction isEqualToString:@"send"]) {
        rtpParametersByKind = @{
                                 @"audio":ortc.getSendingRtpParameters(@"audio", extendedRtpCapabilities),
                                 @"video":ortc.getSendingRtpParameters(@"video", extendedRtpCapabilities)
                                 };
        
        handler = [[CL_RTC_SendHandler alloc] initWithDirection:direction rtpParametersByKind:rtpParametersByKind settings:settings];
    }
    
    if ([direction isEqualToString:@"recv"]) {
        rtpParametersByKind = @{
                                 @"audio":ortc.getReceivingFullRtpParameters(@"audio", extendedRtpCapabilities),
                                 @"video":ortc.getReceivingFullRtpParameters(@"video", extendedRtpCapabilities)
                                 };
        
        handler = [[CL_RTC_RecvHandler alloc] initWithDirection:direction rtpParametersByKind:rtpParametersByKind settings:settings];
    }
    return handler;
}


@end

