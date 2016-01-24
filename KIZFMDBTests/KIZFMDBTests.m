//
//  KIZFMDBTests.m
//  KIZFMDBTests
//
//  Created by Eugene on 16/1/13.
//  Copyright © 2016年 hunlimao. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "Person.h"
#import "KIZDBManager.h"
#import "FMDatabaseQueue.h"
#import "FMDatabase.h"
#import "IDCard.h"

@interface KIZFMDBTests : XCTestCase

@end

@implementation KIZFMDBTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testExample {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

- (void)testUpgradeDataBase{
    
    [[KIZDBManager sharedInstance] setUpgradeBlock:^(FMDatabaseQueue *dbQueue, int fromVersion, int toVersion){
        NSLog(@"升级===");
        __block BOOL success = YES;
        [dbQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
            success = [db executeUpdate:@"DROP TABLE IF EXIST Person"];
        }];
        NSLog(@"升级%@", success ? @"success" : @"failure");
    }];
    [[KIZDBManager sharedInstance] setDbVersion:3];
    
    NSString *path = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    
    path = [path stringByAppendingString:@"/test/test.db"];
    
//    [[KIZDBManager sharedInstance] changeDataBasePath:path];
    
}

- (void)testCreateTable{
    
    NSError *error = nil;
    [Person kiz_createTableWithError:&error];
    [IDCard kiz_createTableWithError:&error];
    NSLog(@"%@", error);
    XCTAssert(!error);
}

- (void)testSave{
    NSError *error = nil;
    
    Person *user = [Person new];
    user.userName  = @"张三";
    user.birthDate = [NSDate date];
    user.longValue = LONG_MAX;
    
    IDCard *card = [IDCard new];
    card.id = user.userId;
    user.idCard = (id)card;
    
    [user kiz_saveWithError:&error];
    
    XCTAssert(error == nil);
}

- (void)testBatchSave{
    
    NSError *error = nil;
    
    Person *user1 = [Person new];
    user1.userName  = @"李四";
    user1.birthDate = [self dateWithFormat:@"1990-02-28"];
    
    Person *user2 = [Person new];
    user2.userName  = @"王五";
    user2.birthDate = [self dateWithFormat:@"1991-03-30"];
    
    [Person kiz_batchSave:@[user1, user2] error:&error];
    
    XCTAssert(error == nil);
    
}

- (void)testBatchSaveOrUpdate{
    
    NSError *error = nil;
    
    Person *user1 = [Person new];
    user1.userId = 1;
    user1.userName  = @"李四";
    user1.birthDate = [self dateWithFormat:@"1990-02-28"];
    
    IDCard *card1 = [IDCard new];
    card1.id = user1.userId;
    user1.idCard = (id)card1;
    
    Person *user2 = [Person new];
    user2.userId = 2;
    user2.userName  = @"王五";
    user2.birthDate = [self dateWithFormat:@"1991-03-30"];
    
    IDCard *card2 = [IDCard new];
    card2.id = user2.userId;
    user2.idCard = (id)card2;
    
    [Person kiz_batchSaveOrUpdate:@[user1, user2] error:&error];
    
    XCTAssert(error == nil);
    
}


- (void)testUpdate{
    NSError *error = nil;
    
    Person *user = [Person new];
    user.userName  = @"张三";
    user.birthDate = [NSDate date];
    
    [user kiz_updateWithError:&error];
    
    XCTAssert(error == nil);
}

- (void)testUpdateWithProperties{
    NSError *error = nil;
    
    Person *user = [Person new];
    user.userName  = @"张三";
    user.birthDate = [NSDate date];
    
    [user kiz_updateWithProperties:@[@"birthDate"] error:&error];
    
    XCTAssert(error == nil);
}

- (void)testSelect{
    NSError *error = nil;
    
    NSArray *users = [Person kiz_selectWhere:nil arguments:nil error:&error];
    NSLog(@"%@", users);
    
    XCTAssert(error == nil);

}

- (NSDate *)dateWithFormat:(NSString *)formatDate{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd";
    
    return [formatter dateFromString:formatDate];
}
@end
