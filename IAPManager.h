//
//  IAPManager.h
//  BunnisEnglish


#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, IAPStateCode) {
    /**
     *  苹果返回错误信息
     */
    IAPStateCodeAppleCode = 0,
    
    /**
     *  用户禁止应用内付费购买
     */
    IAPStateCodeUserForbid = 1,
    
    /**
     *  商品为空
     */
    IAPStateCodeEmptyProduct = 2,
    
    /**
     *  无法获取产品信息，请重试
     */
    IAPStateCodeGetProductFail = 3,
    
    /**
     *  购买失败，请重试
     */
    IAPStateCodeTransactionFail = 4,
    
    /**
     *  用户取消交易
     */
    IAPStateCodeTransactionCancel = 5,
    
    /**
     *  购买成功
     */
    IAPStateCodeTransactionSuccess = 6,
    
    /**
     *  支付成功，后台校验失败
     */
    IAPStateCodeTransactionVerifyFail = 7,
    
    /**
     *  恢复内购成功（所有已经购买过的项目）
     */
    IAPStateCodeTransactionRestoreSuccess,
    
    /**
     *  恢复内购失败
     */
    IAPStateCodeTransactionRestoreFail,
};


@protocol IAPManagerDelegate <NSObject>

@optional

/**
 购买过程中的各个状态
 */
- (void)purchaseState:(IAPStateCode)state error:(nullable NSError *)error;

@end


/**
 App 内购 manager
 */
@interface IAPManager : NSObject

@property (nonatomic, weak) id<IAPManagerDelegate> delegate;

/**
 获取单例
 */
+ (instancetype)sharedManager;


/**
 启动 IAPManager，开始监听内购
 */
- (void)startManager;


/**
 停止 IAPManager
 */
- (void)stopManager;

/**
 购买商品

 @param productId 在苹果内购页面配置的ID
 */
- (void)purchaseProductWithID:(NSString *)productId;

/**
 检查本地是否有保存的 App Receipt，如果有，发送给后台进行验证
 */
- (void)checkIAPFiles;

/**
 已经购买过，恢复内购商品

 @param applicationUserName 购买商品发起支付时设置的 applicationUserName，在倍利思英语中使用的是当前登录用户的手机号
 */
- (void)restoreProducts:(NSString *)applicationUserName;

@end

NS_ASSUME_NONNULL_END
