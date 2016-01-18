//
//  KIZDBProtocol.h
//  HunLiMaoMerchant
//
//  Created by Eugene on 15/12/2.
//  Copyright © 2015年 hunlimao. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FMResultSet.h"
@class FMDatabaseQueue;

typedef void(^KIZDBOperateCompletion)(NSError *error);

/** 属性是一对一关联对象 */
@protocol KIZOneToOne <NSObject>
@end


@protocol KIZDBTableProtocol <NSObject>

@optional
#pragma mark- table
/**
 *  返回数据表名称，如果返回nil，将使用class name作为表名
 *  @return
 */
+ (NSString *)kiz_tableName;

/**
 *  class property 与数据表column name的映射关系
 *  @return
 */
+ (NSDictionary<NSString *, NSString *> *)kiz_tableColumnPropertyMap;

/**
 *  建立数据表时，忽略的属性，readOnly的属性将自动忽略
 *
 *  @return
 */
+ (NSArray<NSString *> *)kiz_tableIgnoreProperties;

/**
 *  建立数据表时，如果需要把祖先类的属性也添加到表中，则在此方法返回祖先类，将往上追溯到该类，且不包含NSObject类的属性
 *  默认不会添加祖先类的属性到表中
 *  @return
 */
+ (Class)kiz_tableColumnTrackToParentClass;

/** 非空的属性, 建立数据表时添加非空约束  */
+ (NSArray<NSString *> *)kiz_nonNullProperties;
/** 值唯一属性，建立数据表时添加唯一约束 */
+ (NSArray<NSString *> *)kiz_uniqueProperties;
/** 自增长属性，建立数据表时，列设为自增长 */
+ (NSArray<NSString *> *)kiz_autoIncrementProperties;
/** 属性-默认值, 注意只在创建表时才有效，ALTER TABLE 时不支持设置默认值 */
+ (NSDictionary<NSString *, NSString *> *)kiz_propertyDefaultValues;

/** 关联对象的外键 */
+ (NSString *)kiz_forieignKeyForProperty:(NSString *)property;

@required
/**
 *  数据表主键,
 *  注意：返回的主键必须是类的属性名称
 *  @return
 */
+ (NSArray<NSString *> *)kiz_primaryKeys;

/** 同步创建数据表 创建数据表，如果数据表不存在，则创建数据表*/
+ (BOOL)kiz_createTableWithError:(NSError **)error;
/** 异步 创建数据表，如果数据表不存在，则创建数据表*/
+ (void)kiz_createTableWithCompletion:(KIZDBOperateCompletion)completion;


@end


#pragma mark- 

@protocol KIZDBProtocol <KIZDBTableProtocol>

@optional



#pragma mark-
/** 同步保存到数据库 */
- (BOOL)kiz_saveWithError:(NSError **)error;
- (void)kiz_save:(KIZDBOperateCompletion)completion;
/** 同步 SaveOrUpdate */
- (BOOL)kiz_saveOrUpdateWithError:(NSError **)error;
- (void)kiz_saveOrUpdate:(KIZDBOperateCompletion)completion;
/** 同步 更新 */
- (BOOL)kiz_updateWithError:(NSError **)error;
/** 更新对象的指定属性到数据库 */
- (BOOL)kiz_updateWithProperties:(NSArray<NSString *> *)properties error:(NSError **)error;
- (void)kiz_update:(KIZDBOperateCompletion)completion;
/** 同步 删除当前记录，根据主键来删除，需要确保主键的值不为空 */
- (BOOL)kiz_removeWithError:(NSError **)error;
- (void)kiz_remove:(KIZDBOperateCompletion)completion;

/** 同步 批量插入数据 */
+ (BOOL)kiz_batchSave:(NSArray<id<KIZDBProtocol>> *)objects error:(NSError **)error;
+ (void)kiz_batchSave:(NSArray<id<KIZDBProtocol>> *)objects completion:(KIZDBOperateCompletion)completion;
/** 同步 批量更新 */
+ (BOOL)kiz_batchUpdate:(NSArray<id<KIZDBProtocol>> *)objects error:(NSError **)error;
+ (void)kiz_batchUpdate:(NSArray<id<KIZDBProtocol>> *)objects completion:(KIZDBOperateCompletion)completion;
/** 同步 批量SaveOrUpdate */
+ (BOOL)kiz_batchSaveOrUpdate:(NSArray<id<KIZDBProtocol>> *)objects error:(NSError **)error;
+ (void)kiz_batchSaveOrUpdate:(NSArray<id<KIZDBProtocol>> *)objects completion:(KIZDBOperateCompletion)completion;
+ (void)kiz_batchRemove:(NSArray<id<KIZDBProtocol>> *)objects completion:(KIZDBOperateCompletion)completion;
+ (void)kiz_removeAll:(KIZDBOperateCompletion)completion;

/**
 *  删除符合条件的记录，实际实行SQL语句：
 *  @code
 *  DELETE FROM [table name] WHERE [column1 = ? and column2 = ?]
 *  @endcode
 *  @param where     SQL WHERE 字句：例如[column1 = ? and column2 > ?]
 *  @param arguments 参数，[value1, value2]
 */
+ (void)kiz_removeWhere:(NSString *)where arguments:(NSArray *)arguments completion:(KIZDBOperateCompletion)completion;

/** 同步SELECT*/
+ (NSArray *)kiz_selectWhere:(NSString *)where arguments:(NSArray *)arguments error:(NSError **)error;
+ (void)kiz_selectWhere:(NSString *)where arguments:(NSArray *)arguments completion:(void(^)(NSArray *results, NSError *error))completion;
+ (void)kiz_select:(NSString *)select where:(NSString *)where arguments:(NSArray *)arguments completion:(void(^)(NSArray<NSDictionary *>  *resultArray, NSError *error))completion;

@end
