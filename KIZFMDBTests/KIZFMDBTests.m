//
//  KIZFMDBTests.m
//  KIZFMDBTests
//
//  Created by Eugene on 16/1/13.
//  Copyright © 2016年 hunlimao. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "User.h"

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

- (void)testCreateTable{
    NSError *error = nil;
    [User kiz_createTableWithError:&error];
    NSLog(@"%@", error);
    XCTAssert(!error);
}

- (void)testSave{
    NSError *error = nil;
    
    User *user = [User new];
    user.userName  = @"张三";
    user.birthDate = [NSDate date];
    user.longValue = LONG_MAX;
    
    [user kiz_saveWithError:&error];
    
    XCTAssert(error == nil);
}

- (void)testBatchSave{
    
    NSError *error = nil;
    
    User *user1 = [User new];
    user1.userName  = @"李四";
    user1.birthDate = [self dateWithFormat:@"1990-02-28"];
    
    User *user2 = [User new];
    user2.userName  = @"王五";
    user2.birthDate = [self dateWithFormat:@"1991-03-30"];
    
    [User kiz_batchSave:@[user1, user2] error:&error];
    
    XCTAssert(error == nil);
    
}

- (void)testUpdate{
    NSError *error = nil;
    
    User *user = [User new];
    user.userName  = @"张三";
    user.birthDate = [NSDate date];
    
    [user kiz_updateWithError:&error];
    
    XCTAssert(error == nil);
}

- (void)testUpdateWithProperties{
    NSError *error = nil;
    
    User *user = [User new];
    user.userName  = @"张三";
    user.birthDate = [NSDate date];
    
    [user kiz_updateWithProperties:@[@"birthDate"] error:&error];
    
    XCTAssert(error == nil);
}

- (void)testSelect{
    NSError *error = nil;
    
    NSArray *users = [User kiz_selectWhere:nil arguments:nil error:&error];
    NSLog(@"%@", users);
    
    XCTAssert(error == nil);

}

- (NSDate *)dateWithFormat:(NSString *)formatDate{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd";
    
    return [formatter dateFromString:formatDate];
}
@end
