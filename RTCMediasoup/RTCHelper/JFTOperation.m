//
//  JFTOperation.m
//  CinLanMedia
//
//  Created by 刘金丰 on 2019/5/29.
//  Copyright © 2019 Liujinfeng. All rights reserved.
//

#import "JFTOperation.h"

@implementation JFTOperation

+ (void)waitChildTreadWithResolverBlock:(void (^)(JFResolver resolver))resolverBlock {
    CFRunLoopRef ref = CFRunLoopGetCurrent();
    resolverBlock (^(){
        CFRunLoopStop(ref);
    });
    CFRunLoopRun();
}

@end
