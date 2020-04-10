//
//  ProducerData.m
//  CinLanMedia
//
//  Created by 刘金丰 on 2019/3/22.
//  Copyright © 2019 Liujinfeng. All rights reserved.
//

#import "ProducerData.h"

@implementation ProducerData

+ (NSArray *)mj_ignoredPropertyNames {
    return @[@"idStr", @"kind", @"pid", @"track"];
}


#pragma mark - Getter

- (NSInteger)pid {
    return self.dataID;
}

@end
