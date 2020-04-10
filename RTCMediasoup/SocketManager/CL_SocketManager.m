//
//  CL_SocketManager.m
//  WebRtcRoomIOS
//
//  Created by 刘金丰 on 2019/3/11.
//  Copyright © 2019 wjr. All rights reserved.
//

#import "CL_SocketManager.h"

#define kTimeoutInterval 3000
@interface CL_SocketManager ()  <NSURLSessionDelegate>

@property(nonatomic,strong) SocketManager* socketManager;
@property(nonatomic,strong) SocketIOClient* socketClient;

@end

@implementation CL_SocketManager

+ (instancetype)socket {
    static CL_SocketManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [CL_SocketManager new];
    });
    return manager;
}

- (void)create:(NSString *)url para:(NSDictionary *)para {
    
    NSURL *socketUrl = [[NSURL alloc] initWithString:url];
    SSLSecurity* sec = [[SSLSecurity alloc] initWithUsePublicKeys:YES];
    
    dispatch_queue_t handleQueue = dispatch_queue_create("CL_Media_Socket_Queue", DISPATCH_QUEUE_SERIAL);
    
    BOOL secure = [url containsString:@"https://"];
//    @"reconnects":@(NO),
    NSDictionary *config = @{@"log": @NO,
                             @"connectParams":para,
                             @"forceWebsockets":@YES,
                             @"compress": @YES,
                             @"security":sec,
                             @"secure":@(secure),
                             @"reconnectWait":@(3),
                             @"reconnectWaitMax":@(15),
                             @"reconnectAttempts":@(5),
                             @"sessionDelegate":self,
                             @"selfSigned":@(secure),
                             @"handleQueue":handleQueue};
    
    self.socketManager = [[SocketManager alloc] initWithSocketURL:socketUrl config:config];
    self.socketClient = self.socketManager.defaultSocket;
    
    kWeakSelf(weakSelf)
    
    [self.socketClient on:@"connect" callback:^(NSArray * data, SocketAckEmitter * ack) {
        JFLog(@"服务器连接成功");
        if (weakSelf.Open) weakSelf.Open(nil);
    }];
    
    // 断开连接
    [self.socketClient on:@"disconnect" callback:^(NSArray* data, SocketAckEmitter* ack) {
        JFLog(@"断开连接-- %@", data);
        NSString *reason = nil;
        if (data.count) {
            if ([data.firstObject isKindOfClass:[NSString class]])
                reason = data.firstObject;
        }
        if (weakSelf.Disconnected) weakSelf.Disconnected(reason);
    }];
    
    // 关闭
    [self.socketClient on:@"close" callback:^(NSArray* data, SocketAckEmitter* ack) {
        JFLog(@"关闭连接-- %@", data);
        if (weakSelf.Close) weakSelf.Close();
    }];
    
    
    // 发生错误时发出。
    [self.socketClient on:@"error" callback:^(NSArray* data, SocketAckEmitter* ack) {
        JFErrorLog(@"发生错误时发出 -- %@", data);
        if (data.count) {
            if ([data.firstObject isKindOfClass:[NSString class]]) {
                NSError *error = [NSError errorWithDomain:data.firstObject code:0 userInfo:nil];
                weakSelf.Error(error);
            }
        }
    }];
    
    // 当客户端发出开始重新连接过程。
    [self.socketClient on:@"reconnect" callback:^(NSArray* data, SocketAckEmitter* ack) {
        JFErrorLog(@"当客户端发出开始重新连接过程。 ping -- %@", data);
        if (weakSelf.Reconnect) {
             weakSelf.Reconnect();
        }
    }];
    
    // 每次发出客户机试图连接到服务器。
    [self.socketClient on:@"reconnectAttempt" callback:^(NSArray* data, SocketAckEmitter* ack) {
        JFLog(@"每次发出客户机试图连接到服务器 -- %@", data);
    }];
    
    
    // 客户端每次改变状态的时候出发
    [self.socketClient on:@"statusChange" callback:^(NSArray* data, SocketAckEmitter* ack) {
        JFLog(@"客户端每次改变状态的时候出发 -- %@", data);
    }];
    
    [self.socketClient on:@"clmedia-notification" callback:^(NSArray * data, SocketAckEmitter * ack) {
        JFLog(@"收到通知 %@", data);
        id noti = data.lastObject;
        
        if ([noti isKindOfClass:[NSString class]]) {
            JFErrorLog(@"⚡️⚡️⚡️⚡️⚡️⚡️⚡️⚡️\nclmedia-notification: \n%@\n⚡️⚡️⚡️⚡️⚡️⚡️⚡️⚡️", noti);
            return;
        }
        if (weakSelf.CLM_Notification) weakSelf.CLM_Notification(noti);
    }];
    
    
    [self.socketClient on:Lis_ProducerDataChange callback:^(NSArray * data, SocketAckEmitter * adc) {
        JFLog(@"Lis_ProducerDataChange : [%@]", data);
        if (weakSelf.CLAS_ProducerDataChanged) {
            if ([data.lastObject isKindOfClass:[NSDictionary class]]) {
                weakSelf.CLAS_ProducerDataChanged(data.lastObject);
            }
        }
    }];
    
    [self.socketClient on:Lis_PeerDataChange callback:^(NSArray * data, SocketAckEmitter * ack) {
        JFLog(@"Lis_PeerDataChange : [%@]", data);
        if (weakSelf.CLAS_PeerDataChanged) {
            if ([data.lastObject isKindOfClass:[NSDictionary class]]) {
                weakSelf.CLAS_PeerDataChanged(data.lastObject);
            }
        }
    }];
    
    [self.socketClient on:Lis_PubMsg callback:^(NSArray * data, SocketAckEmitter * ack) {
        JFLog(@"Lis_PubMsg : [%@]", data);
        if (weakSelf.CLAS_PubMsg){
            if ([data.lastObject isKindOfClass:[NSDictionary class]]) {
                 weakSelf.CLAS_PubMsg(data.lastObject);
            }
        }
    }];
    
    [self.socketClient on:Lis_DelMsg callback:^(NSArray * data, SocketAckEmitter * ack) {
        JFLog(@"DelMsg : [%@]", data);
        if (weakSelf.CLAS_DelMsg) {
            if ([data.lastObject isKindOfClass:[NSDictionary class]]) {
                weakSelf.CLAS_DelMsg(data.lastObject);
            }
        }
    }];
    
    
    [self.socketClient on:Lis_CLClosed callback:^(NSArray * data, SocketAckEmitter * ack) {
        JFErrorLog(@"cl-closed : [%@]", data);
        if (weakSelf.CLAS_CLClosed) {
            if ([data.lastObject isKindOfClass:[NSDictionary class]]) {
                NSDictionary *dic = data.lastObject;
                weakSelf.CLAS_CLClosed([NSError errorWithDomain:dic[@"msg"] code:[dic[@"code"] integerValue] userInfo:nil]);
            }
        }
    }];
    
    // 语音激励
    [self.socketClient on:@"active-speaker" callback:^(NSArray * data, SocketAckEmitter * ack) {
        JFErrorLog(@"active-speaker : [%@]", data);
        NSDictionary *dic = data.firstObject;
        
        if (weakSelf.CLAS_ActiveSpeaker) {
            if ([data.lastObject isKindOfClass:[NSDictionary class]]) {
                NSDictionary *dic = data.lastObject;
                id value = dic[@"peerName"];
                weakSelf.CLAS_ActiveSpeaker(value);
            }
        }
    }];
    
    [self.socketClient connect];
    SocketEngine *engin = (SocketEngine *)self.socketManager.engine;
    
    NSLog(@"%d -- %@", self.socketManager.forceNew,  engin.connectParams);
    
}



- (void)send:(NSString *)method para:(NSDictionary *)para callback:(SManagerCB)callback {
        
    [[self.socketClient emitWithAck:method with:@[para]] timingOutAfter:kTimeoutInterval callback:^(NSArray * data) {
        id respon = data.lastObject;
        
        if ([respon isKindOfClass:[NSString class]]) {
            JFErrorLog(@"⚡️⚡️⚡️⚡️⚡️⚡️⚡️⚡️\nSend request [%@] error: \n%@\n⚡️⚡️⚡️⚡️⚡️⚡️⚡️⚡️", method, respon);
            return;
        }
        if (callback) callback(respon);
    }];
}

- (void)notify:(NSString *)method para:(NSDictionary *)para callback:(SManagerCB)callback {
    
    [[self.socketClient emitWithAck:method with:@[para]] timingOutAfter:kTimeoutInterval callback:^(NSArray * data) {
        id notify = data.lastObject;
        
        if ([notify isKindOfClass:[NSString class]]) {
            JFErrorLog(@"⚡️⚡️⚡️⚡️⚡️⚡️⚡️⚡️\nnotify request [%@] error: \n%@\n⚡️⚡️⚡️⚡️⚡️⚡️⚡️⚡️", method, notify);
            return;
        }
        if (callback) callback(notify);
    }];
}



- (void)sendSignalingMsg:(SignalingMsg *)msg result:(void (^)(NSString * _Nullable error))result {
    JFLog(@"%@:\n%@", msg.ack, msg.toDictionary);
    [[self.socketClient emitWithAck:msg.ack with:@[msg.toDictionary]] timingOutAfter:kTimeoutInterval callback:^(NSArray * data) {
        if (data.count) {
            id resp = data.lastObject;
            if ([resp isKindOfClass:[NSNull class]]) {
               if (result) result (nil);
            }
            if ([resp isKindOfClass:[NSString class]]) {
                JFErrorLog(@"%@", data);
               if (result) result (resp);
            }
        }
    }];
}


- (void)close {
    [self.socketClient disconnect];
    [self.socketManager disconnectSocket:self.socketClient];
    self.socketClient = nil;
    self.socketManager = nil;
}


- (void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
 completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * _Nullable credential))completionHandler
{
    if(challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust) {
        // 告诉服务器，客户端信任证书
        // 创建凭据对象
        NSURLCredential *credntial = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
        // 通过completionHandler告诉服务器信任证书
        completionHandler(NSURLSessionAuthChallengeUseCredential,credntial);
    }
}

- (void)dealloc {
    
}

@end
