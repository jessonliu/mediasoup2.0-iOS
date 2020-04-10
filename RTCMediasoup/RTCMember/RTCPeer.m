//
//  RTCPeer.m
//  WebRtcRoomIOS
//
//  Created by 刘金丰 on 2019/1/15.
//  Copyright © 2019 wjr. All rights reserved.
//

#import "RTCPeer.h"
#import "RTCConsumer.h"
#import "CLPeerProtocol.h"
#import "CLConsumer.h"

@interface RTCPeer ()
 @end

@implementation RTCPeer

+ (instancetype)shareInstance:(NSString *)name appData:(id _Nullable)appData {
    RTCPeer *peer       = [RTCPeer new];
    peer.name           = name;
    peer.appData        = appData;
    peer->_share        = peer.getShareType(appData[@"share"]);
    peer->_host          = appData[@"host"];
    return peer;
}


#pragma mark - Publick Method

- (NSArray <RTCConsumer *>*)consumersToArr {
    return self.consumers.allObjects;
}

- (void)close {
    
    if (self.closed) return;
    self.closed = YES;
    [self.peerData assignClosed:YES];
    
    if (self.Close_CB) self.Close_CB(@"local", nil, self);
    NSArray <RTCConsumer *>*consumers = [NSArray arrayWithArray:self.consumers.allObjects];
    for (RTCConsumer *consumer in consumers) {
        [consumer close];
    }
}

- (void)remoteClose:(id _Nullable)appData {
    
    if (self.closed) return;
    
    self.closed = YES;
    [self.peerData assignClosed:YES];
    
    if (self.Close_CB) self.Close_CB(@"remote", appData, self);
    NSArray <RTCConsumer *>*consumers = [NSArray arrayWithArray:self.consumers.allObjects];
    for (RTCConsumer *consumer in consumers) {
        [consumer remoteClose];
    }
}


- (RTCConsumer *)getConsumerById:(NSString *)cid {
    
    if (!cid.length) return nil;
    
    return [self.consumers objectForKey:cid];
}

- (void)addConsumer:(RTCConsumer *)consumer {
    NSString *cid = [NSString stringWithFormat:@"%ld", (long)consumer.cid];
    
    if ([self.consumers.allKeys containsObject:cid]) {
        JFErrorLog(@"Peer: %@ 已经添加过 consumer : %ld", self.name, (long)consumer.cid);
        return;
    }
    
    [self.lock lock];
    [self.consumers setObject:consumer forKey:cid];
    if (consumer.mKind == MSMediaKindAudio)
        [self.peerData assignAudioConsumer:consumer.consumerData];
    if (consumer.mKind == MSMediaKindVideo)
        [self.peerData addVideoConsumer:consumer.consumerData];
    [self.lock unlock];
    
    kWeakSelf(weakSelf)
    
    consumer.Pause_CB = ^(NSString * _Nonnull args,  id _Nullable appData, RTCConsumer *obj) {
        if (obj.mKind == MSMediaKindAudio)
            [weakSelf.peerData assignAudioConsumer:obj.consumerData];
        if (obj.mKind == MSMediaKindVideo)
            [weakSelf.peerData updVideoConsumer:obj.consumerData];
    };
    consumer.Resume_CB = ^(NSString * _Nonnull args, id  _Nonnull appData, RTCConsumer *obj) {
        if (obj.mKind == MSMediaKindAudio)
            [weakSelf.peerData assignAudioConsumer:obj.consumerData];
        if (obj.mKind == MSMediaKindVideo)
            [weakSelf.peerData updVideoConsumer:obj.consumerData];
    };
    
    consumer.Close_CB = ^(id  _Nonnull originator, id _Nullable appData, RTCConsumer * _Nonnull obj) {
        [weakSelf.lock lock];
        NSString *cid = [NSString stringWithFormat:@"%ld", (long)obj.cid];
        [weakSelf.consumers removeObjectForKey:cid];
        [weakSelf.lock unlock];
        if (obj.mKind == MSMediaKindAudio)
            [weakSelf.peerData assignAudioConsumer:obj.consumerData];
        if (obj.mKind == MSMediaKindVideo)
            [weakSelf.peerData delVideoConsumer:obj.cid];

    };
    
    if (self.Newconsumer_CB) self.Newconsumer_CB(consumer);
}


#pragma mark - Setter
- (void)setShare:(ConfShareType)share {
    if (_share != share) {
        _share = share;
        NSMutableDictionary *dic = [self.appData mutableCopy];
        [dic setObject:self.getShareCode(_share) forKey:@"share"];
        self.appData = [dic copy];
    }
}

- (void)setHost:(NSString *)host {
    if (_host != host) {
        _host = host;
        if (host) {
            NSMutableDictionary *dic = [self.appData mutableCopy];
            [dic setObject:host forKey:@"host"];
            self.appData = [dic copy];
        }
    }
}

#pragma mark - Getter
- (MulOrderedDictionary *)consumers {
    if (!_consumers) {
        _consumers = [M13MutableOrderedDictionary orderedDictionary];
    }
    return _consumers;
}

- (CLPeer<CLPeerProtocol> *)peerData {
    if (!_peerData) {
        _peerData = (CLPeer <CLPeerProtocol>*)[CLPeer createUser:self.name nickName:self.displayName];
        [_peerData assignPeer:self];
    }
    return _peerData;
}

- (NSString *)displayName {
    if (!_displayName) {
        _displayName = self.appData[@"displayName"];
    }
    return _displayName;
}

- (ConfShareType (^)(NSString *))getShareType {
    return ^(NSString *shareCode) {
        ConfShareType type = ConfShareTypeNO;
        if ([shareCode isEqualToString:@"none"]) {
            type = ConfShareTypeNO;
        }
        if ([shareCode isEqualToString:@"whiteboard"]) {
            type = ConfShareTypeWB;
        }
        if ([shareCode isEqualToString:@"application"]) {
            type = ConfShareTypeSN;
        }
        if ([shareCode isEqualToString:@"document"]) {
            type = ConfShareTypeDM;
        }
        return type;
    };
}

- (NSString * (^)(ConfShareType))getShareCode {
    return ^(ConfShareType shareType) {
        if (shareType & ConfShareTypeNO) return @"none";
        if (shareType & ConfShareTypeWB) return @"whiteboard";
        if (shareType & ConfShareTypeSN) return @"application";
        if (shareType & ConfShareTypeDM) return @"document";
        return @"none";
    };
}

- (void)dealloc {
    JFLog(@"🔱🔱Peer dealloc🔱🔱");
}

@end
