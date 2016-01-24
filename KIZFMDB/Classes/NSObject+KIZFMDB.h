//
//  NSObject+KIZFMDB.h
//  HunLiMaoMerchant
//
//  Created by Eugene on 15/12/2.
//  Copyright © 2015年 hunlimao. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KIZDBProtocol.h"

@interface NSObject (KIZFMDB)<KIZDBProtocol>

//the rowId when store in sqlite, if primary key is integer, then dbRowId is equal primary key's value
@property (assign, nonatomic) NSInteger dbRowId;

@end
