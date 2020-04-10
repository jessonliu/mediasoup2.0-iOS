//
//  RTCMember.m
//  CinLanMedia
//
//  Created by 刘金丰 on 2019/3/29.
//  Copyright © 2019 Liujinfeng. All rights reserved.
//

#import "RTCMember.h"

@interface RTCMember ()
@property (nonatomic, strong) NSMutableDictionary <NSString *, NSMutableArray <id>*>*cbMap;
@end



@implementation RTCMember
@synthesize Close_CB        = _Close_CB;
@synthesize Unhandled_CB    = _Unhandled_CB;
@synthesize Handled_CB      = _Handled_CB;
@synthesize Pause_CB        = _Pause_CB;
@synthesize Resume_CB       = _Resume_CB;
@synthesize Stats_CB        = _Stats_CB;
@synthesize Newconsumer_CB  = _Newconsumer_CB;
@synthesize Notify_CB       = _Notify_CB;
@synthesize Request_CB      = _Request_CB;
@synthesize CloseTransport_CB = _CloseTransport_CB;
@synthesize Effectiveprofilechange_CB = _Effectiveprofilechange_CB;



#pragma mark - Setter
- (void)setClose_CB:(RTCMember3ParaCB)Close_CB {
    [self.lock lock];
    [self setCB:Close_CB old_cb:_Close_CB getter:@selector(Close_CB)];
    _Close_CB = Close_CB;
    [self.lock unlock];
}

- (void)setUnhandled_CB:(RTCMemberCB)Unhandled_CB {
    [self.lock lock];
    [self setCB:Unhandled_CB old_cb:_Unhandled_CB getter:@selector(Unhandled_CB)];
    _Unhandled_CB = Unhandled_CB;
    [self.lock unlock];
}

- (void)setHandled_CB:(RTCMemberCB)Handled_CB {
    [self.lock lock];
    [self setCB:Handled_CB old_cb:_Handled_CB getter:@selector(Handled_CB)];
    _Handled_CB = Handled_CB;
    [self.lock unlock];
}

- (void)setPause_CB:(RTCMember3ParaCB)Pause_CB {
    [self.lock lock];
    [self setCB:Pause_CB old_cb:_Pause_CB getter:@selector(Pause_CB)];;
    _Pause_CB = Pause_CB;
    [self.lock unlock];
}

- (void)setResume_CB:(RTCMember3ParaCB)Resume_CB {
    [self.lock lock];
    [self setCB:Resume_CB old_cb:_Resume_CB getter:@selector(Resume_CB)];
    _Resume_CB = Resume_CB;
    [self.lock unlock];
}

- (void)setStats_CB:(RTCMember2ParaCB)Stats_CB {
    [self.lock lock];
    [self setCB:Stats_CB old_cb:_Stats_CB getter:@selector(Stats_CB)];
    _Stats_CB = Stats_CB;
    [self.lock unlock];
}



- (void)setNewconsumer_CB:(RTCMember1ParaCB)Newconsumer_CB {
    [self.lock lock];
    [self setCB:Newconsumer_CB old_cb:_Newconsumer_CB getter:@selector(Newconsumer_CB)];
    _Newconsumer_CB = Newconsumer_CB;
    [self.lock unlock];
}
- (void)setEffectiveprofilechange_CB:(RTCMember1ParaCB)Effectiveprofilechange_CB {
    [self.lock lock];
    [self setCB:Effectiveprofilechange_CB old_cb:_Effectiveprofilechange_CB getter:@selector(Effectiveprofilechange_CB)];
    _Effectiveprofilechange_CB = Effectiveprofilechange_CB;
    [self.lock unlock];
}

- (void)setNotify_CB:(RTCMember3ParaCB)Notify_CB {
    [self.lock lock];
    [self setCB:Notify_CB old_cb:_Notify_CB getter:@selector(Notify_CB)];
    _Notify_CB = Notify_CB;
    [self.lock unlock];
}

- (void)setCloseTransport_CB:(RTCMember2ParaCB)CloseTransport_CB {
    [self.lock lock];
    [self setCB:CloseTransport_CB old_cb:_CloseTransport_CB getter:@selector(CloseTransport_CB)];
    _CloseTransport_CB = CloseTransport_CB;
    [self.lock unlock];
}

- (void)setRequest_CB:(RTCMember3ParaCB)Request_CB {
    [self.lock lock];
    [self setCB:Request_CB old_cb:_Request_CB getter:@selector(Request_CB)];
    _Request_CB = Request_CB;
    [self.lock unlock];
}

#pragma mark - Getter
- (RTCMember3ParaCB)Close_CB {
    return  self.getCB(3, _cmd);
}

- (RTCMemberCB)Unhandled_CB {
    return  self.getCB(0, _cmd);
}

- (RTCMemberCB)Handled_CB {
    return  self.getCB(0, _cmd);
}

- (RTCMember3ParaCB)Pause_CB {
    return  self.getCB(3, _cmd);
}

- (RTCMember3ParaCB)Resume_CB {
    return  self.getCB(3, _cmd);
}

- (RTCMember2ParaCB)Stats_CB {
    return  self.getCB(2, _cmd);
}

- (RTCMember1ParaCB)Newconsumer_CB {
    return self.getCB(1, _cmd);
}

- (RTCMember1ParaCB)Effectiveprofilechange_CB {
    return self.getCB(1, _cmd);
}

- (RTCMember3ParaCB)Notify_CB {
    return self.getCB(3, _cmd);
}

- (RTCMember2ParaCB)CloseTransport_CB {
    return self.getCB(2, _cmd);
}

- (RTCMember3ParaCB)Request_CB {
    return self.getCB(3, _cmd);
}

- (RTCMemberCB (^)(NSInteger paraCount, SEL sel))getCB {
    kWeakSelf(weakSelf)
    return ^(NSInteger paraCount, SEL sel) {
        return [weakSelf getCB:paraCount sel:sel];
    };
}

- (RTCMemberCB)getCB:(NSInteger)paraCount sel:(SEL)sel {
    NSString *cb_name = NSStringFromSelector(sel);
    id cb;
    NSArray *cb_arr = [self getCBArr:cb_name];
    if (!cb_arr) return [self valueForKey:[@"_" stringByAppendingString:cb_name]];
    switch (paraCount) {
        case 0:
        {
            cb = ^() {  for (RTCMemberCB tcb in cb_arr) tcb(); };
        }
            break;
        case 1:
        {
            cb = ^(id p) { for (RTCMemberCB tcb in cb_arr) tcb(p); };
        }
            break;
        case 2:
        {
            cb = ^(id p, id p1) { for (RTCMemberCB tcb in cb_arr) tcb(p, p1); };
        }
            break;
        case 3:
        {
            cb = ^(id p, id p2, id p3) { for (RTCMemberCB tcb in cb_arr) tcb(p, p2, p3); };
        }
            break;
        default:
        {
            cb = ^() { for (RTCMemberCB tcb in cb_arr) tcb(); };
        }
            break;
    }
    return cb;
}



- (NSLock *)lock {
    if (!_lock) {
        _lock = [NSLock new];
    }
    return _lock;
}

- (void)setCB:(id)cb old_cb:(id)old_cb  getter:(SEL)getter {
    NSString *cb_name = NSStringFromSelector(getter);
    if (!old_cb && cb) return;
    if (old_cb && cb) {
        NSMutableArray <id>*arr = [self.cbMap objectForKey:cb_name];
        if (!arr) {
            arr = [@[] mutableCopy];
            [self.cbMap setObject:arr forKey:cb_name];
            [arr addObject:old_cb];
        }
        [arr addObject:cb];
    }
}

- (NSArray <id>*)getCBArr:(NSString *)cb_namme {
    return [self.cbMap objectForKey:cb_namme];
}

- (NSMutableDictionary<NSString *,NSMutableArray <id>*> *)cbMap {
    if (!_cbMap) {
        _cbMap = [@{} mutableCopy];
    }
    return _cbMap;
}


- (void)dealloc {
    
}

@end
