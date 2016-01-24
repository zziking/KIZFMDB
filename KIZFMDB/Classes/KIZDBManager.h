//
//  KIZDBHelper.h
//  HunLiMaoMerchant
//
//  Created by Eugene on 15/12/2.
//  Copyright © 2015年 hunlimao. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "KIZDBProtocol.h"

typedef void(^KIZDataBaseUpgradeBlock)(FMDatabaseQueue *dbQueue, int fromVersion, int toVersion);

@protocol KIZDBManagerDelegate <NSObject>

@optional
- (void)dataBaseQueue:(FMDatabaseQueue *)dbQueue upgradeFromVersion:(int)fromVersion toVersion:(int)toVersion;

@end


@interface KIZDBManager : NSObject

@property (strong, nonatomic, readonly) dispatch_queue_t queue;
@property (strong, atomic) FMDatabaseQueue *fmdbQueue;
@property (copy,   nonatomic) KIZDataBaseUpgradeBlock upgradeBlock;
@property (weak,   nonatomic) id<KIZDBManagerDelegate> delegate;
@property (assign, nonatomic) BOOL enableDebugSql;

+ (instancetype)sharedInstance;

- (int)dbVersion;
/**
 *  设置数据库版本，如果实际数据库的版本和设置的版本不一致，将触发upgradeBlock
 *  @param version
 */
- (void)setDbVersion:(int)version;

/** 更改数据库路径 */
- (void)changeDataBasePath:(NSString *)filePath;

@end
