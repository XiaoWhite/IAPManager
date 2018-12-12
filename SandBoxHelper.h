//
//  SandBoxHelper.h
//  BunnisEnglish


#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SandBoxHelper : NSObject

/**
 程序主目录，可见子目录(3个):Documents、Library、tmp
 */
+ (NSString *)homePath;

/**
 文档目录，需要ITUNES同步备份的数据存这里，可存放用户数据
 */
+ (NSString *)docmentsPath;

/**
 Library 目录
 */
+ (NSString *)libraryPath;

/**
 配置目录，配置文件存这里
 */
+ (NSString *)libPrefPath;

/**
 缓存目录，系统永远不会删除这里的文件，ITUNES会删除
 */
+ (NSString *)libCachePath;

/**
 临时缓存目录，APP退出后，系统可能会删除这里的内容
 */
+ (NSString *)tmpPath;

/**
 用于存储iap内购返回的购买凭证
 */
+ (NSString *)iapReceiptPath;

@end

NS_ASSUME_NONNULL_END
