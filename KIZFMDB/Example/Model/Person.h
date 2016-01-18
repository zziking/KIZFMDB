//
//  User.h
//  KIZFMDB
//
//  Created by Eugene on 16/1/13.
//  Copyright © 2016年 hunlimao. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KIZDBProtocol.h"
#import "IDCard.h"

@protocol TestProtocol <NSObject>
@end


@interface Person : NSObject<KIZDBProtocol>

@property (nonatomic, assign) NSInteger userId;
@property (nonatomic, copy  ) NSString  *userName;
@property (nonatomic, strong) NSDate    *birthDate;

@property (nonatomic, strong) NSDate *updateTime;

@property (nonatomic, assign) long longValue;

@property (nonatomic, strong) IDCard<KIZOneToOne, TestProtocol> *idCard;

@end
