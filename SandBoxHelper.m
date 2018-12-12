//
//  SandBoxHelper.m
//  BunnisEnglish


#import "SandBoxHelper.h"

@implementation SandBoxHelper

#pragma mark - Public

+ (NSString *)homePath {
    return NSHomeDirectory();
}

/**
 文档目录，需要ITUNES同步备份的数据存这里，可存放用户数据
 */
+ (NSString *)docmentsPath {
    NSArray * paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    return [paths objectAtIndex:0];
}

/**
 Library 目录
 */
+ (NSString *)libraryPath {
    NSArray * paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    return [paths objectAtIndex:0];
}

+ (NSString *)libPrefPath {
    return [[self libraryPath] stringByAppendingFormat:@"/Preferences"];
}

+ (NSString *)libCachePath {
    NSArray * paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    return [paths objectAtIndex:0];
}

+ (NSString *)tmpPath {
    return NSTemporaryDirectory();
}

+ (NSString *)iapReceiptPath {
    NSString *path = [[self libPrefPath] stringByAppendingFormat:@"/receipt.%@",[[NSBundle mainBundle] bundleIdentifier]];
    // 如果不存在，创建路径
    [self hasLive:path];
    return path;
}

#pragma mark - Private
// 路径是否存在
+ (BOOL)hasLive:(NSString *)path
{
    if ( NO == [[NSFileManager defaultManager] fileExistsAtPath:path] )
    {
        return [[NSFileManager defaultManager] createDirectoryAtPath:path
                                         withIntermediateDirectories:YES
                                                          attributes:nil
                                                               error:NULL];
    }
    
    return YES;
}

@end
