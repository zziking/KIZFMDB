//
//  KIZDBClassProperty.h
//  HunLiMaoMerchant
//
//  Created by Eugene on 15/12/3.
//  Copyright © 2015年 hunlimao. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface KIZDBClassProperty : NSObject

/** 声明的属性名称 (不是 ivar 名) */
@property (copy, nonatomic) NSString* name;

/** A property class type  */
@property (assign, nonatomic) Class classType;

/** Struct name if a struct */
@property (strong, nonatomic) NSString* structName;

/** The name of the protocol the property conforms to (or nil) */
//@property (copy, nonatomic) NSString* protocol;

/** If YES - create a mutable object for the value of the property */
@property (assign, nonatomic) BOOL isMutable;

/** getter方法 */
@property (assign, nonatomic) SEL getter;

/** setter方法 */
@property (assign, nonatomic) SEL setter;

/** SQLite数据表中的类型 */
@property (copy, nonatomic) NSString *dbColumnType;

/** property在SQLite数据表中的列名 */
@property (copy, nonatomic) NSString *dbColumnName;

@property (copy, nonatomic) NSString *defaultValue;
@property (copy, nonatomic) NSString *check;
@property (assign, nonatomic) BOOL isNonNull;
@property (assign, nonatomic) BOOL isUnique;
@property (assign, nonatomic) BOOL isPrimarykey;

@end
