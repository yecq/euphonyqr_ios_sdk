//
//  BuyfullSDK.h
//  BuyfullSDK
//
//  Created by 叶常青 on 2019/7/12.
//  Copyright © 2019年 buyfull. All rights reserved.
//
#ifndef BuyfullSDK_h
#define BuyfullSDK_h


#endif /* BuyfullSDK_h */

typedef void(^BuyfullRecordCallback)(NSData*_Nullable,NSError*_Nullable);
typedef void(^BuyfullDetectCallback)(float,NSDictionary*_Nullable,NSError*_Nullable);//返回分贝数，返回JSON，出错返回NSError

@interface BuyfullSDK : NSObject

@property (assign, atomic) BOOL                 hasMicPermission;
@property (assign, atomic) BOOL                 isDetecting;
@property (assign, atomic) BOOL                 isIniting;
@property (strong, atomic) NSString *_Nullable  token;
@property (strong, atomic) NSString *_Nullable  appKey;
@property (assign, atomic) BOOL                 isSandbox;
@property (strong, atomic) NSString *_Nullable  tokenURL;
@property (strong, atomic) NSString *_Nullable  phoneNumber;
@property (strong, atomic) NSString *_Nullable  userID;          // userID或phoneNumber可以做为数据分析标识通过动听后台API返回，请任意设置一个

/*
 *
 appkey请向动听员工询问，tokenURL需要自行布署
 */
- (instancetype _Nonnull )initWithAppkey:(NSString*_Nonnull)appkey isSandbox:(BOOL)isSandbox tokenURL:(NSString*_Nonnull)tokenURL;
/*
 *
 把下面所有的SDK方法整合执行，用户可以自行参考修改
 customData可以为任何字符串，可以通过返回的requestID在动听后台查询时返回
 */
-(void) detect:(NSString*_Nullable)customData callback:(BuyfullDetectCallback _Nonnull)callback;
/*
 *
 录音并且返回纯pcm数据，默认录音参数为44100,16bit,单声道，时长1.2秒。录音错误返回nil。
 */
-(void) record:(BuyfullRecordCallback _Nonnull )callback;

/*
 *
 检测18k-20k录音分贝数。
 */
-(float) getDB:(NSData* _Nonnull )pcmData
    sampleRate:(int)sampleRate
      channels:(int)channels
          bits:(int)bits
   isLastFrame:(bool)isLastFrame
         error:(NSError*_Nullable*_Nullable)outError;
/*
 *
 将纯pcm采样处理，提取18k-20k音频，返回的BIN用于detect，如果出错返回nil，参数指定源pcm数据格式
 sampleRate: 44100或48000
 bits：16 (Short)或 32 (Float)
 channels：1 (单声道)或 2 (双声道交织)
 录音时长一定要大于1.2秒,超出会截取最后1.2秒
 */
-(NSData*_Nullable) buildBin:(NSData*_Nonnull)pcmData
                  sampleRate:(int)sampleRate
                    channels:(int)channels
                        bits:(int)bits
                       error:(NSError*_Nullable*_Nullable)outError;


/*
 *
 请求TOKEN，有了TOKEN后才能使用BUYFULL SDK
 */
-(NSURLRequest*_Nullable)    requestToken:(NSString*_Nonnull)tokenURL
                                   appkey:(NSString*_Nonnull)appkey
                                isSandbox:(BOOL)isSandbox
                                    error:(NSError*_Nullable*_Nullable)outError;


/*
 *
 将参数打包后返回，可以直接POST给检测服务器
 */
-(NSURLRequest*_Nullable) detectRequest:(NSData*_Nonnull)bin
                                 appkey:(NSString*_Nonnull)appkey
                                  token:(NSString*_Nonnull)token
                              isSandbox:(BOOL)isSandbox
                             deviceInfo:(NSString*_Nonnull)deviceInfo
                            phoneNumber:(NSString*_Nullable)phoneNumber
                                 userID:(NSString*_Nullable)userID
                             customData:(NSString*_Nullable)customData
                                  error:(NSError*_Nullable*_Nullable)outError;


/*
 *
 处理服务器返回的原始JSON，加入一些辅助数据
 */
-(NSDictionary*_Nullable) handleJSONResult:(NSDictionary*_Nonnull)jsonResult
                                     error:(NSError*_Nullable*_Nullable)outError;
@end
