//
//  IDCard.h
//  KIZFMDB
//
//  Created by kingizz on 16/1/15.
//  Copyright © 2016年 hunlimao. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KIZDBProtocol.h"

@interface IDCard : NSObject<KIZDBProtocol>

@property (assign, nonatomic) NSInteger id;
@property (strong, nonatomic) NSDate *validDate;

@end
