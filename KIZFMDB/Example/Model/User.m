//
//  User.m
//  KIZFMDB
//
//  Created by Eugene on 16/1/13.
//  Copyright © 2016年 hunlimao. All rights reserved.
//

#import "User.h"
#import "NSObject+KIZFMDB.h"

@implementation User

+ (NSDictionary<NSString *, NSString *> *)kiz_propertyDefaultValues{
    return @{
             @"updateTime" : @"(strftime('%s', 'now'))"
             };
}

#pragma mark- KIZDBProtocol

+ (NSArray<NSString *> *)kiz_primaryKeys{
    return @[@"userId"];
}

@end
