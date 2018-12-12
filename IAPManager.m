//
//  IAPManager.m
//  BunnisEnglish

#import "IAPManager.h"

#import "NetworkServiceManager.h"
#import "SandBoxHelper.h"

static NSString * const kReceiptKey = @"receipt_key";
static NSString * const kDateKey = @"date_key";
static NSString * const kUserTokenKey = @"userToken_key";

@interface IAPManager ()<SKPaymentTransactionObserver, SKProductsRequestDelegate>

/**
 是否正在请求商品信息
 */
@property (nonatomic, assign) BOOL requestingProduct;

/**
 交易成功后得到的 receipt
 */
@property (nonatomic, copy) NSString *receipt;

@end

@implementation IAPManager

#pragma mark - Public

/**
 获取单例
 */
+ (instancetype)sharedManager {
    static IAPManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    
    return sharedInstance;
}


/**
 启动 IAPManager，开始监听内购
 */
- (void)startManager {
    
    /***
     内购支付两个阶段：
     1.app直接向苹果服务器请求商品，支付阶段；
     2.苹果服务器返回凭证，app向公司服务器发送验证，公司再向苹果服务器验证阶段；
     */
    
    /**
     阶段一正在进中,app退出。
     在程序启动时，设置监听，监听是否有未完成订单，有的话恢复订单。
     */
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    
    /**
     阶段二正在进行中,app退出。
     在程序启动时，检测本地是否有receipt文件，有的话，去二次验证。
     */
    [self checkIAPFiles];
}


/**
 停止 IAPManager
 */
- (void)stopManager {
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
}

/**
 购买商品
 */
- (void)purchaseProductWithID:(NSString *)productId {
    if (![SKPaymentQueue canMakePayments]) {
        NSLog(@"应用内付费购买不可用");
        [self callDelegateWithIAPStateCode:IAPStateCodeUserForbid error:nil];
        return;
    }
    
    NSSet *set = [NSSet setWithObject:productId];
    SKProductsRequest *request = [[SKProductsRequest alloc] initWithProductIdentifiers:set];
    request.delegate = self;
    [request start];
    
    self.requestingProduct = YES;
}

/**
 检查本地是否有保存的 App Receipt，如果有，发送给后台进行验证；
 如果验证receipt失败，App启动后再次验证
 */
- (void)checkIAPFiles {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    // 搜索 receipt 文件夹下所有文件
    NSError *error;
    NSArray *filePaths = [fileManager contentsOfDirectoryAtPath:[SandBoxHelper iapReceiptPath] error:&error];
    
    if (error == nil) {
        
        for (NSString *name in filePaths) {
            
            if ([name hasSuffix:@".plist"]){ //如果有plist后缀的文件，说明就是存储的购买凭证
                
                NSString *filePath = [NSString stringWithFormat:@"%@/%@", [SandBoxHelper iapReceiptPath], name];
                
                [self verifyReceiptWithFilePath:filePath];
            }
        }
        
    } else {
        
        NSLog(@"AppStoreInfoLocalFilePath error:%@", [error domain]);
    }
    
}

/**
 已经购买过，恢复内购商品
 */
- (void)restoreProducts:(NSString *)applicationUserName {
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactionsWithApplicationUsername:applicationUserName];
//    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

#pragma mark - Private
- (void)callDelegateWithIAPStateCode:(IAPStateCode)state error:(nullable NSError *)error {
    if (self.delegate && [self.delegate respondsToSelector:@selector(purchaseState:error:)]) {
        [self.delegate purchaseState:state error:error];
    }
}


/**
 获取交易成功后的购买凭证
 */
- (void)getReceipt {
    
    NSURL *receiptUrl = [[NSBundle mainBundle] appStoreReceiptURL];
    
    NSData *receiptData = [NSData dataWithContentsOfURL:receiptUrl];
    
    self.receipt = [receiptData base64EncodedStringWithOptions:0];
}

/**
 存储交易凭证
 */
- (void)saveReceipt {
    // 当前时间
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    NSString *dateStr = [formatter stringFromDate:[NSDate date]];
    
    // 文件名
    NSString *fileName = [NSUUID UUID].UUIDString;
    
    // 当前用户 token
    NSString *userToken = [User currentUser].token;
    
    // Library/Preference/XXX.plist
    NSString *savedPath = [NSString stringWithFormat:@"%@/%@.plist", [SandBoxHelper iapReceiptPath], fileName];
    
    NSDictionary *dic = @{
                          kReceiptKey : self.receipt,
                          kDateKey : dateStr,
                          kUserTokenKey : userToken
                          };
    
    NSLog(@"%@",savedPath);
    
    [dic writeToFile:savedPath atomically:YES];
    
    XNLog(@"------------ 保存 receipt 成功 ------------");
}


/**
 验证成功后，将本地保存的 receipt 移除
 */
- (void)removeReceipt:(NSString *)path {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    if ([fileManager fileExistsAtPath:path]) {
        
        [fileManager removeItemAtPath:path error:nil];
        XNLog(@"------------ 删除 receipt 成功 ------------");
    }
}

/**
 从本地获取已经保存的 receipt 信息，发送给服务器去验证
 */
- (void)verifyReceiptWithFilePath:(NSString *)path {
    // 获取 receipt
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:path];
    NSString *userToken = [dict valueForKey:kUserTokenKey];
    
    if (![[User currentUser].token isEqualToString:userToken]) {
        // 如果不是当前用户的 receipt，直接返回
        return;
    }
    
    // 调用接口校验购买
    WeakObj(self)
    [[NetworkServiceManager sharedManager] verifyPurchaseWithReceipt:[dict valueForKey:kReceiptKey] success:^(id response) {
        XNLog(@"res = %@", response);
        NSDictionary *resDict = (NSDictionary *)response;
        NSInteger code = [[resDict valueForKey:@"code"] integerValue];
        
        if (code != NetWorkServiceStatusSuccess) {
            XNLog(@"校验接口调用失败");
            [selfWeak callDelegateWithIAPStateCode:IAPStateCodeTransactionVerifyFail error:nil];
            return;
        }
        
        BOOL isSuccess = [[resDict valueForKey:@"success"] boolValue];
        if (isSuccess) {
            // 购买成功
            [selfWeak callDelegateWithIAPStateCode:IAPStateCodeTransactionSuccess error:nil];
            // 发出通知，使相应页面刷新
            [[NSNotificationCenter defaultCenter] postNotificationName:kLessonBuyStatusChange object:nil userInfo:nil];
            
            // 删除本地的 receipt
            [selfWeak removeReceipt:path];
        } else {
            // 验证失败
            [selfWeak callDelegateWithIAPStateCode:IAPStateCodeTransactionVerifyFail error:nil];
        }
        
    } fail:^(NSError *error) {
        // 验证失败
        [selfWeak callDelegateWithIAPStateCode:IAPStateCodeTransactionVerifyFail error:nil];
    }];
}

#pragma mark - 交易处理
// 交易失败处理
- (void)failedTransaction: (SKPaymentTransaction *)transaction{
    
    XNLog(@"失败，%@", transaction.error.userInfo);
    if (transaction.error.code == SKErrorPaymentCancelled) {
        // 用户取消购买
        [self callDelegateWithIAPStateCode:IAPStateCodeTransactionCancel error:nil];
    } else {
        // 购买失败
        [self callDelegateWithIAPStateCode:IAPStateCodeTransactionFail error:transaction.error];
    }
    [[SKPaymentQueue defaultQueue] finishTransaction: transaction];
}


/**
 购买成功后的处理
 */
- (void)completeTransaction: (SKPaymentTransaction *)transaction{
    
    NSLog(@"-----completeTransaction--------");
    // Remove the transaction from the payment queue.
    [[SKPaymentQueue defaultQueue] finishTransaction: transaction];
}

// 记录交易
- (void)recordTransaction:(NSString *)product{
    NSLog(@"-----记录交易--------");
    
}

// 处理下载内容
- (void)provideContent:(NSString *)product{
    NSLog(@"-----下载--------");
}


/**
 恢复已购买的商品
 */
- (void)restoreTransaction: (SKPaymentTransaction *)transaction{
    NSLog(@" 交易恢复处理");
    
    NSLog(@"productId = %@, applicationUserName = %@ -------- ", transaction.payment.productIdentifier, transaction.originalTransaction.payment.applicationUsername);
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
}


#pragma mark - SKProductsRequestDelegate
- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response{
    
    self.requestingProduct = NO;
    
    NSLog(@"-----------收到产品反馈信息--------------");
    NSArray *myProduct = response.products;
    NSLog(@"产品付费数量: %d", (int)[myProduct count]);
    
    if (myProduct.count == 0) {
        // 没有请求到商品信息
        [self callDelegateWithIAPStateCode:IAPStateCodeEmptyProduct error:nil];
        return;
    }
    
    for(SKProduct *product in myProduct){
        NSLog(@"product info");
        NSLog(@"SKProduct 描述信息%@", [product description]);
        NSLog(@"产品标题 %@" , product.localizedTitle);
        NSLog(@"产品描述信息: %@" , product.localizedDescription);
        NSLog(@"价格: %@" , product.price);
        NSLog(@"Product id: %@" , product.productIdentifier);
        
    }
    
    SKMutablePayment *payment = [SKMutablePayment paymentWithProduct:myProduct[0]];
    payment.applicationUsername = [User currentUser].phoneNum;
    NSLog(@"---------发送购买请求------------");
    
    [[SKPaymentQueue defaultQueue] addPayment:payment];
}

- (void)requestDidFinish:(SKRequest *)request{
    NSLog(@"----------反馈信息结束--------------");
    self.requestingProduct = NO;
    
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error{
    self.requestingProduct = NO;
    
    NSLog(@"-------弹出错误信息----------");
    [self callDelegateWithIAPStateCode:IAPStateCodeGetProductFail error:error];
    
    // 隐藏 loading
//    [self.view hideLoading];
//    [self showMessageWithAlertTitle:@"" message:[error localizedDescription]];
}

#pragma mark - SKPaymentTransactionObserver
//----监听购买结果
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions//交易结果
{
    
    NSLog(@"-----paymentQueue--------");
    
    for (SKPaymentTransaction *transaction in transactions) {
        switch (transaction.transactionState) {
            case SKPaymentTransactionStatePurchased:
            {
                
                [self getReceipt]; //获取交易成功后的购买凭证
                
                [self saveReceipt]; //存储交易凭证
                
                [self checkIAPFiles]; //把保存下来的 receipt 发送到服务器验证是否有效
                
                [self completeTransaction:transaction]; //交易完成
                
                XNLog(@"-----交易完成 --------");
                
                break;
            }
            case SKPaymentTransactionStateFailed://交易失败
            {
                XNLog(@"-----交易失败 --------");
                [self failedTransaction:transaction];
                break;
            }
                
            case SKPaymentTransactionStateRestored://已经购买过该商品
            {
                XNLog(@"-----已经购买过该商品 --------");
                [self restoreTransaction:transaction];
                break;
            }
            case SKPaymentTransactionStatePurchasing:
            {
                //商品添加进列表
                XNLog(@"-----商品添加进列表 --------");
                break;
            }
            default:
                break;
        }
    }
}


- (void)paymentQueue:(SKPaymentQueue *) paymentQueue restoreCompletedTransactionsFailedWithError:(NSError *)error{
    NSLog(@"-------paymentQueue----");
}

- (void)paymentQueueRestoreCompletedTransactionsFinished: (SKPaymentTransaction *)transaction{
    NSLog(@"---------交易结束------------");
    [self callDelegateWithIAPStateCode:IAPStateCodeTransactionRestoreSuccess error:nil];
}


@end
