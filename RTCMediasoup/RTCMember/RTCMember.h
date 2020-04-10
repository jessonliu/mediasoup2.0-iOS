//
//  RTCMember.h
//  CinLanMedia
//
//  Created by 刘金丰 on 2019/3/29.
//  Copyright © 2019 Liujinfeng. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void(^RTCMemberCB)();
typedef void(^RTCMember1ParaCB)(id _Nullable p);
typedef void(^RTCMember2ParaCB)(id _Nullable p1,  id _Nullable p2);
typedef void(^RTCMember3ParaCB)(id _Nullable p1, id _Nullable p2, id _Nullable p3);

@interface RTCMember : NSObject

@property (nonatomic, strong) NSLock *lock;

@property (nonatomic, copy) RTCMember3ParaCB    Close_CB;
@property (nonatomic, copy) RTCMemberCB         Unhandled_CB;
@property (nonatomic, copy) RTCMemberCB         Handled_CB;
@property (nonatomic, copy) RTCMember3ParaCB    Pause_CB;
@property (nonatomic, copy) RTCMember3ParaCB    Resume_CB;
@property (nonatomic, copy) RTCMember2ParaCB    Stats_CB;

#pragma mark - RTCPeer CB
@property (nonatomic, copy) RTCMember1ParaCB    Newconsumer_CB;

#pragma mark - RTCConsumer CB
@property (nonatomic, copy) RTCMember1ParaCB    Effectiveprofilechange_CB;

#pragma mark - RTCTransport CB
@property (nonatomic, copy) RTCMember3ParaCB Notify_CB;
@property (nonatomic, copy) RTCMember2ParaCB CloseTransport_CB;
@property (nonatomic, copy) RTCMember3ParaCB Request_CB;

//@property (nonatomic, copy) void (^Notify_CB)(NSString *args, NSDictionary *data, RTCTran_CB _Nullable callback);
//@property (nonatomic, copy) void (^CloseTransport_CB)(NSString *args,  id _Nullable appData);
//@property (nonatomic, copy) void (^Request_CB)(NSString *args, NSDictionary *data, RTCTran_CB _Nullable callback);


- (void)setCB:(id)cb old_cb:(id)old_cb  getter:(SEL)getter;

- (NSArray <id>*)getCBArr:(NSString *)cb_namme;

@end

NS_ASSUME_NONNULL_END
