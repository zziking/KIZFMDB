//
//  KIZDatabaseQueue.m
//  HunLiMaoMerchant
//
//  Created by Eugene on 16/1/21.
//  Copyright © 2016年 hunlimao. All rights reserved.
//

#import "KIZDatabaseQueue.h"
#import "FMDatabase.h"

//static NSString *const KIZDatabaseQueue = @"KIZDatabaseQueue";

@interface FMDatabaseQueue (Private)

- (void)beginTransaction:(BOOL)useDeferred withBlock:(void (^)(FMDatabase *db, BOOL *rollback))block;

@end

@interface KIZDatabaseQueue ()

@property (weak,    nonatomic) FMDatabase *executingDB;
@property (assign,  nonatomic) BOOL *shouldRollback;
@property (strong,  nonatomic) NSRecursiveLock *rLock;

@end

@implementation KIZDatabaseQueue

- (instancetype)init{
    self = [super init];
    if (self) {
        _rLock = [[NSRecursiveLock alloc] init];
    }
    return self;
}

- (void)inDatabase:(void (^)(FMDatabase *db))block{
    
    [self.rLock lock];
    
    if (self.executingDB) {
        block(self.executingDB);
        
    }else{
        [super inDatabase:^(FMDatabase *db){
            self.executingDB = db;
            block(db);
            self.executingDB = nil;
        }];
    }
    
    [self.rLock unlock];
    
}


- (void)beginTransaction:(BOOL)useDeferred withBlock:(void (^)(FMDatabase *db, BOOL *rollback))block {
    
    [self.rLock lock];
    
    if (self.executingDB) {
        
        if (self.shouldRollback && *self.shouldRollback == NO) {
            
            block(self.executingDB, self.shouldRollback);
        }
        
    }else{
        [super beginTransaction:useDeferred withBlock:^(FMDatabase *db, BOOL *rollback){
            self.executingDB    = db;
            self.shouldRollback = rollback;
            block(db, rollback);
            self.executingDB = nil;
            self.shouldRollback = nil;
        }];
    }
    
    [self.rLock unlock];
}

@end
