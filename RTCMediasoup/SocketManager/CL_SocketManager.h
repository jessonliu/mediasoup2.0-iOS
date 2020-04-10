//
//  CL_SocketManager.h
//  WebRtcRoomIOS
//
//  Created by 刘金丰 on 2019/3/11.
//  Copyright © 2019 wjr. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SocketIO/SocketIO-Swift.h>


NS_ASSUME_NONNULL_BEGIN

typedef void (^SManagerCB)(id data);

@interface CL_SocketManager : NSObject
// ********************* callback *********************
@property (nonatomic, copy) void (^Open)(NSError *_Nullable error);
@property (nonatomic, copy) void (^Reconnect)(void);
@property (nonatomic, copy) void (^Disconnected)(NSString * _Nullable);
@property (nonatomic, copy) void (^Error)(NSError *_Nullable error);
@property (nonatomic, copy) void (^Close)(void);
@property (nonatomic, copy) void (^CLM_Notification)(id data);
@property (nonatomic, copy) void (^CLM_ActiveSpeaker)(id data);

// ********************* CinLan Application Signaling callback ********************* //
@property (nonatomic, copy) void (^CLAS_PeerDataChanged)(id data);
@property (nonatomic, copy) void (^CLAS_ProducerDataChanged)(id data);
@property (nonatomic, copy) void (^CLAS_PubMsg)(id data);
@property (nonatomic, copy) void (^CLAS_DelMsg)(id data);
@property (nonatomic, copy) void (^CLAS_CLClosed)(NSError *error);
@property (nonatomic, copy) void (^CLAS_ActiveSpeaker)(NSString *peerName);

@property (nonatomic, assign) SocketIOStatus status;


+ (instancetype)socket;

- (void)create:(NSString *)url para:(NSDictionary *)para;

- (void)send:(NSString *)method para:(NSDictionary *)para callback:(SManagerCB)callback;

- (void)notify:(NSString *)method para:(NSDictionary *)para callback:(SManagerCB)callback;



// ******************************* Application Signaling ****************************//

- (void)sendSignalingMsg:(SignalingMsg *)msg result:(void (^)(NSString * _Nullable error))result;



- (void)close;



@end

NS_ASSUME_NONNULL_END
