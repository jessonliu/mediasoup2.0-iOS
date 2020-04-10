//
//  JSManager.m
//  WebRtcRoomIOS
//
//  Created by 刘金丰 on 2019/1/16.
//  Copyright © 2019 wjr. All rights reserved.
//

#import "JSManager.h"
#import "J_Utils.h"

@implementation JSTransition

+(instancetype)transition {
    JSTransition *tra = [JSTransition new];
    return tra;
}

- (JSValue *(^)(NSArray *))callWithArguments {
    kWeakSelf(weakSelf)
    return ^id (NSArray *arguments) {
        return [weakSelf.funValue callWithArguments:arguments];
    };
}

- (void)dealloc {
    
}

@end

@implementation JSCoreBase
- (JSContext *)ctx {
    if (!_ctx) {
        JSVirtualMachine *vc = [[JSVirtualMachine alloc] init];
        _ctx = [[JSContext alloc] initWithVirtualMachine:vc];
        [_ctx evaluateScript:[self getScript:NSStringFromClass([self class])]];
        _ctx.exceptionHandler = ^(JSContext *context, JSValue *exception) {
            JFErrorLog(@"%@", exception);
        };
    }
    return _ctx;
}

- (NSString *)getScript:(NSString *)fileName {
    
    NSBundle *bundle = [NSBundle bundleWithPath:[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"CLMediaBundle.bundle"]];
    
    NSString *filePath = [bundle pathForResource:fileName ofType:@"js"];
    NSString *script = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
    return script;
}

- (JSTransition *(^)(SEL))method {
    kWeakSelf(weakSelf)
    return ^id(SEL method) {
        JSTransition *trans = [JSTransition transition];
        trans.funValue = [weakSelf.ctx objectForKeyedSubscript:NSStringFromSelector(method)];
        return trans;
    };
}

- (void)dealloc {
    
}

@end

@implementation mt_ortc

- (NSDictionary *(^)(NSDictionary *, NSDictionary *))getExtendedRtpCapabilities {
    kWeakSelf(weakSelf)
    SEL method = _cmd;
    return ^NSDictionary *(NSDictionary *localCap, NSDictionary *remoteCap) {
        return weakSelf.method(method).callWithArguments(@[localCap,remoteCap]).toDictionary;
    };
}

- (NSDictionary *(^)(NSDictionary *))getRtpCapabilities {
    kWeakSelf(weakSelf)
    SEL method = _cmd;
    return ^id (NSDictionary *extendedRtpCapabilities) {
        return weakSelf.method(method).callWithArguments(@[extendedRtpCapabilities]).toDictionary;
    };
}

- (NSArray *(^)(NSDictionary *, NSArray *, NSDictionary *))getUnsupportedCodecs {
    kWeakSelf(weakSelf)
    SEL method = _cmd;
    return ^id (NSDictionary *remoteCaps, NSArray *mandatoryCodecPayloadTypes, NSDictionary *extendedRtpCapabilities) {
        return weakSelf.method(method).callWithArguments(@[remoteCaps, mandatoryCodecPayloadTypes, extendedRtpCapabilities]).toArray;
    };
}

- (BOOL (^)(NSString *, NSDictionary *))canSend {
    kWeakSelf(weakSelf)
    SEL method = _cmd;
    return ^BOOL(NSString *kind, NSDictionary *extendedRtpCapabilities) {
        return weakSelf.method(method).callWithArguments(@[kind, extendedRtpCapabilities]).toBool;
    };
}

- (BOOL (^)(NSDictionary *, NSDictionary *))canReceive {
    kWeakSelf(weakSelf)
    SEL method = _cmd;
    return ^BOOL (NSDictionary *rtpParameters, NSDictionary *extendedRtpCapabilities) {
        return weakSelf.method(method).callWithArguments(@[rtpParameters, extendedRtpCapabilities]).toBool;
    };
}

- (NSDictionary *(^)(NSString *, NSDictionary *))getSendingRtpParameters {
    kWeakSelf(weakSelf)
    SEL method = _cmd;
    return ^id (NSString *kind, NSDictionary *extendedRtpCapabilities) {
        return weakSelf.method(method).callWithArguments(@[kind, extendedRtpCapabilities]).toDictionary;
    };
}

- (NSDictionary *(^)(NSString *, NSDictionary *))getReceivingFullRtpParameters {
    kWeakSelf(weakSelf)
    SEL method = _cmd;
    return ^id (NSString *kind, NSDictionary *extendedRtpCapabilities) {
        return weakSelf.method(method).callWithArguments(@[kind, extendedRtpCapabilities]).toDictionary;
    };
}

@end


@implementation mt_edgeUtils

@end

@implementation mt_planBUtils

- (NSDictionary *(^)(NSDictionary *))fillRtpParametersForTrack {
    kWeakSelf(weakSelf)
    SEL method = _cmd;
    return ^id(NSDictionary *param) {
        JSValue *value = weakSelf.method(method).callWithArguments(@[param]);
        return value.toDictionary;
    };
}

@end

@implementation mt_commonUtils

- (NSDictionary *(^)(NSDictionary *))extractDtlsParameters {
    kWeakSelf(weakSelf)
    SEL method = _cmd;
    return ^id (NSDictionary *sdp) {
        return weakSelf.method(method).callWithArguments(@[sdp]).toDictionary;
    };
}

- (NSDictionary *(^)(NSDictionary *))extractRtpCapabilities {
    kWeakSelf(weakSelf)
    SEL method = _cmd;
    return ^id (NSDictionary *sdpObj) {
        return weakSelf.method(method).callWithArguments(@[sdpObj]).toDictionary;
    };
}

@end


@implementation mt_plainRtpUtils


@end

@interface mt_RemoteUnifiedPlanSdp ()
@property (nonatomic, strong) NSDictionary *transporParameters;
@end

@implementation mt_RemoteUnifiedPlanSdp

+ (instancetype)shareRemoteSdp:(NSString *)direction rtpParametersByKind:(NSDictionary *)rtpParametersByKind {
    mt_RemoteUnifiedPlanSdp *remoteSdp = [mt_RemoteUnifiedPlanSdp new];
    remoteSdp.direction = direction;
    remoteSdp.rtpParametersByKind = rtpParametersByKind;
    return remoteSdp;
}

- (CreateAnswerSdp)send_createAnswerSdp {
    kWeakSelf(weakSelf)
    SEL method = _cmd;
    return ^id(NSDictionary *localSdp) {
        
        NSDictionary *data       = weakSelf.method(method).callWithArguments(@[weakSelf.rtpParametersByKind, localSdp, weakSelf.transporParameters]).toDictionary;
        
        weakSelf.sdpGlobalFields = data[@"sdpGlobalFields"];
        
        NSDictionary *sdpObj     = data[@"sdpObj"];
        
        return [J_Utils transportToNativeSdp:sdpObj];;
    };
}

- (CreateOfferSdp)recv_createOfferSdp {
    kWeakSelf(weakSelf)
    SEL method = _cmd;
    return ^id(NSArray *consumerInfos) {
        
        NSDictionary *data          = weakSelf.method(method).callWithArguments(@[weakSelf.rtpParametersByKind, consumerInfos, weakSelf.transporParameters]).toDictionary;
        
        weakSelf.sdpGlobalFields    = data[@"sdpGlobalFields"];
        
        NSDictionary *sdpObj        = data[@"sdpObj"];
        
        return [J_Utils transportToNativeSdp:sdpObj];
    };
}

- (void)updateTransportRemoteIceParameters:(NSDictionary *)remoteIceParameters {
    [self.transportRemoteParameters setObject:remoteIceParameters forKey:@"iceParameters"];
}


#pragma mark - Getter
- (NSMutableDictionary *)transportLocalParameters {
    if (!_transportLocalParameters) {
        _transportLocalParameters = [NSMutableDictionary dictionary];
    }
    return _transportLocalParameters;
}

- (NSMutableDictionary *)transportRemoteParameters {
    if (!_transportRemoteParameters) {
        _transportRemoteParameters = [NSMutableDictionary dictionary];
    }
    return _transportRemoteParameters;
}

- (NSDictionary *)sdpGlobalFields {
    if (!_sdpGlobalFields) {
        _sdpGlobalFields = @{@"id":@([J_Utils getRandomEightDigitNumber]), @"version":@(0)};
    }
    return _sdpGlobalFields;
}

- (NSDictionary *)transporParameters {
    return @{@"transportLocalParameters":self.transportLocalParameters,
             @"transportRemoteParameters":self.transportRemoteParameters,
             @"sdpGlobalFields":self.sdpGlobalFields};
}

@end

@implementation mt_RemotePlanBSdp


@end



@implementation mt_unifiedPlanUtils

- (NSDictionary *(^)(NSDictionary *))fillRtpParametersForTrack {
    kWeakSelf(weakSelf)
    SEL method = _cmd;
    return ^id(NSDictionary *param) {
        return weakSelf.method(method).callWithArguments(@[param]).toDictionary;
    };
}

- (NSDictionary *(^)(NSDictionary *))addPlanBSimulcast {
    kWeakSelf(weakSelf)
    SEL method = _cmd;
    return ^id(NSDictionary *param) {
        return weakSelf.method(method).callWithArguments(@[param]).toDictionary;
    };
}

@end

@implementation JSManager

+ (instancetype)createJSManager {
    JSManager *manager = [JSManager new];
    return manager;
}

- (mt_ortc *)ortc {
    if (!_ortc) {
        _ortc = [[mt_ortc alloc] init];
    }
    return _ortc;
}

- (mt_edgeUtils *)edgeUtils {
    if (!_edgeUtils) {
        _edgeUtils = [[mt_edgeUtils alloc] init];
    }
    return _edgeUtils;
}

- (mt_planBUtils *)planBUtils {
    if (!_planBUtils) {
        _planBUtils = [[mt_planBUtils alloc] init];
    }
    return _planBUtils;
}

- (mt_commonUtils *)commonUtils {
    if (!_commonUtils) {
        _commonUtils = [[mt_commonUtils alloc] init];
    }
    return _commonUtils;
}

- (mt_plainRtpUtils *)plainRtpUtils {
    if (!_plainRtpUtils) {
        _plainRtpUtils = [[mt_plainRtpUtils alloc] init];
    }
    return _plainRtpUtils;
}

- (mt_RemoteUnifiedPlanSdp *)remoteUnifiedPlanSdp {
    if (!_remoteUnifiedPlanSdp) {
        _remoteUnifiedPlanSdp = [[mt_RemoteUnifiedPlanSdp alloc] init];
    }
    return _remoteUnifiedPlanSdp;
}

- (mt_RemotePlanBSdp *)remotePlanBSdp {
    if (!_remotePlanBSdp) {
        _remotePlanBSdp = [[mt_RemotePlanBSdp alloc] init];
    }
    return _remotePlanBSdp;
}

- (mt_unifiedPlanUtils *)unifiedPlanUtils {
    if (!_unifiedPlanUtils) {
        _unifiedPlanUtils = [mt_unifiedPlanUtils new];
    }
    return _unifiedPlanUtils;
}


- (void)dealloc {
    
}

@end
