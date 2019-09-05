//
//  BuyfullSDK.m
//  BuyfullSDK
//
//  Created by 叶常青 on 2019/7/12.
//  Copyright © 2019年 buyfull. All rights reserved.
//
@import Foundation;
@import AdSupport;
@import AudioToolbox;
@import AVFoundation;
@import MediaPlayer;

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <sys/utsname.h>
#import "BuyfullSDK.h"

// Constants
#define Pi 3.14159265358979f
#define N_WAVE          (64*1024)	/* dimension of fsin[] */
#define LOG2_N_WAVE     (6+10)		/* log2(N_WAVE) */
#define abs(x) ((x)>0?(x):-(x))
#define SDK_VERSION     @"1.0.1"

const int   RECORD_SAMPLE_RATE = 44100; //默认录音采样率
const float RECORD_PERIOD = 1.2; //录音时长
const float LIMIT_DB = -120; //分贝阈值，低于此值不上传判断
const float THRESHOLD_DB = -150;

float fsin[N_WAVE];
bool hasInited = FALSE;

@interface BuyfullSDK ()<AVAudioRecorderDelegate>
{
    float real[N_WAVE];
    float imag[N_WAVE];
    dispatch_queue_t  queue;
}
@property (nonatomic ,strong) AVAudioRecorder *voiceRecorder;
@property (nonatomic ,strong) NSString *recordFilePath;
@property (nonatomic ,strong) NSString *recordFolderPath;
@property (nonatomic ,strong) BuyfullRecordCallback cb;
@property (nonatomic ,strong) NSString *deviceInfo;
@end

@implementation BuyfullSDK
//提示打开麦克风权限
-(void) goMicroPhoneSet:(NSString*_Nullable)customData callback:(BuyfullDetectCallback _Nonnull)callback
{
    UIAlertController * alert = [UIAlertController alertControllerWithTitle:@"您还没有允许麦克风权限" message:@"去设置一下吧" preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction * cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        callback(LIMIT_DB, nil,[NSError errorWithDomain:@"no record permission" code:2 userInfo:nil]);
    }];
    UIAlertAction * setAction = [UIAlertAction actionWithTitle:@"去设置" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSURL * url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
            //[UIApplication.sharedApplication openURL:url]; //for ios9
            [UIApplication.sharedApplication openURL:url options:[[NSDictionary alloc]init] completionHandler:^(BOOL success) {
                if (success){
                    [self testMicroPhoneAuth:customData callback:callback];
                }else{
                    callback(LIMIT_DB, nil,[NSError errorWithDomain:@"no record permission" code:2 userInfo:nil]);
                }
            }];
        });
    }];
    
    [alert addAction:cancelAction];
    [alert addAction:setAction];
    
    UIViewController *rootViewController = [UIApplication sharedApplication].delegate.window.rootViewController;
    [rootViewController presentViewController:alert animated:YES completion:nil];
}
//检测麦克风权限
-(void) testMicroPhoneAuth:(NSString*_Nullable)customData callback:(BuyfullDetectCallback _Nonnull)callback
{
    AVAuthorizationStatus microPhoneStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
    switch (microPhoneStatus) {
        case AVAuthorizationStatusDenied:
        case AVAuthorizationStatusRestricted:
        {
            // 被拒绝
            self.hasMicPermission = FALSE;
            [self goMicroPhoneSet:customData callback:callback];
        }
            break;
        case AVAuthorizationStatusNotDetermined:
        {
            // 没弹窗
            self.hasMicPermission = FALSE;
            [self requestMicroPhoneAuth:customData callback:callback];
        }
            break;
        case AVAuthorizationStatusAuthorized:
        {
            // 有授权
            self.hasMicPermission = TRUE;
            [self detect:customData callback:callback];
        }
            break;
            
        default:
            break;
    }
}
//申请麦克风
-(void) requestMicroPhoneAuth:(NSString*_Nullable)customData callback:(BuyfullDetectCallback _Nonnull)callback
{
    [AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler:^(BOOL granted) {
        if (granted){
            self.hasMicPermission = TRUE;
            [self detect:customData callback:callback];
        }else{
            self.hasMicPermission = FALSE;
            [self goMicroPhoneSet:customData callback:callback];
        }
    }];
}

/*以下为BUYFULLSDK检测流程的参考实现，可自行修改
总体流程为
 1.申请麦克风权限
 2.向tokenURL(业务服务器)请求TOKEN，tokenURL(业务服务器)需要自行布署
 3.录音1.2秒
 4.判断分贝数，音量太低无效
 5.提取18k-20k音频，压缩
 6.调用API检测后返回检测结果
 7.对返回的JSON进行一些处理
*/
-(void) detect:(NSString*_Nullable)customData callback:(BuyfullDetectCallback _Nonnull)callback{
    __weak BuyfullSDK* weakself = self;
    //以免重复调用
    if (self.token == nil && self.isIniting){
        callback(LIMIT_DB, nil,[NSError errorWithDomain:@"initing buyfull sdk, please wait" code:1 userInfo:nil]);
        return;
    }
    if (self.token != nil && self.isDetecting){
        callback(LIMIT_DB, nil,[NSError errorWithDomain:@"buyfull sdk is detecting, please wait" code:1 userInfo:nil]);
        return;
    }

    //如果没有麦克风权限就去申请
    if (!self.hasMicPermission){
        [self testMicroPhoneAuth:customData callback:callback];
        return;
    }
    
    if (self.token == nil && !self.isIniting){
        //需要先申请TOKEN
        self.isIniting = TRUE;
        __autoreleasing NSError *error = nil;
        
        //如果appkey是在www.euphonyqr.com上申请的，sandbox为FALSE, 否则为TRUE
        //token service url需要自行布署，具体信息请联系动听工作人员
        NSURLRequest* request = [self requestToken:self.tokenURL
                                            appkey:self.appKey
                                         isSandbox:TRUE
                                             error:&error];
        
        NSURLSessionDataTask* dataTask = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            __strong BuyfullSDK* strongself = weakself;
            strongself.isIniting = FALSE;
            if (error != nil || data == nil){
                NSLog(@"Buyfull sdk get token error: %@",[error localizedDescription]);
                callback(LIMIT_DB, nil,error);
                return;
            }
            NSDictionary *tokenResp = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:&error];
            NSString* token = [tokenResp objectForKey:@"token"];
            if (token != nil && [token length] > 0){
//                NSLog(@"Token is %@",token);
                strongself.token = token;//收到token
                [strongself detect:customData callback:callback];//开始录音并上传检测
            }else{
                NSLog(@"Buyfull sdk get token error: %@",[tokenResp debugDescription]);
                callback(LIMIT_DB, nil,[NSError errorWithDomain:@"invalid token response" code:1 userInfo:nil]);
                return;
            }
        }];
        [dataTask resume];
    }

    
    if (self.token != nil && self.hasMicPermission && !self.isDetecting){
        self.isDetecting = TRUE;
        //如果不调用record方法，也可以自行录音后调用buildBin，注意需要纯PCM流，不带wav文件头
        [self record:^(NSData * pcmData, NSError * err) {
            __strong BuyfullSDK* strongself = weakself;
            if (pcmData == nil || err != nil){
                strongself.isDetecting = FALSE;
                NSLog(@"Buyfull sdk return error: %@",[err localizedDescription]);
                return;
            }
            
            __autoreleasing NSError *error = nil;
            
            float pcmDB_start = [strongself getDB:pcmData sampleRate:RECORD_SAMPLE_RATE channels:1 bits:16 isLastFrame:FALSE error:&error];//此处请和PCM流格式一致
            if (error != nil){
                strongself.isDetecting = FALSE;
                callback(pcmDB_start, nil,error);
                return;
            }
//            NSLog(@"pcm db is %f",pcmDB_start);
            //检测分贝数，太低了说明很可能是没信号，后续不检测
            if (pcmDB_start <= LIMIT_DB){
                NSLog(@"pcm db is %f",pcmDB_start);
                NSLog(@"Almost no signal, return");
                strongself.isDetecting = FALSE;
                callback(pcmDB_start, nil,nil);
                return;
            }
            
            float pcmDB = [strongself getDB:pcmData sampleRate:RECORD_SAMPLE_RATE channels:1 bits:16 isLastFrame:TRUE error:&error];//此处请和PCM流格式一致
            if (error != nil){
                strongself.isDetecting = FALSE;
                callback(pcmDB, nil,error);
                return;
            }
//            NSLog(@"pcm db is %f",pcmDB);
            //检测分贝数，太低了说明很可能是没信号，后续不检测
            if (pcmDB <= LIMIT_DB){
                NSLog(@"pcm db is %f",pcmDB);
                NSLog(@"Almost no signal, return");
                strongself.isDetecting = FALSE;
                callback(pcmDB, nil,nil);
                return;
            }
            
            NSData* binData = [strongself buildBin:pcmData sampleRate:RECORD_SAMPLE_RATE channels:1 bits:16 error:&error];//pcm转成bin
            if (error != nil || binData == nil){
                NSLog(@"Build request bin fail: %@",[error localizedDescription]);
                strongself.isDetecting = FALSE;
                callback(pcmDB, nil,error);
                return;
            }
//            NSLog(@"Bin size: %d", [binData length]);
            NSURLRequest* request = [strongself detectRequest:binData
                                                       appkey:strongself.appKey
                                                        token:strongself.token
                                                    isSandbox:strongself.isSandbox
                                                   deviceInfo:strongself.deviceInfo
                                                  phoneNumber:strongself.phoneNumber
                                                       userID:strongself.userID
                                                   customData:customData error:&error];
            if (error != nil || binData == nil){
                NSLog(@"Build detect request fail: %@",[error localizedDescription]);
                strongself.isDetecting = FALSE;
                callback(pcmDB, nil,error);
                return;
            }
            NSURLSessionDataTask* dataTask = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                __strong BuyfullSDK* strongself = weakself;
                strongself.isDetecting = FALSE;
                if (error != nil || data == nil){
                    NSLog(@"Buyfull sdk detect got error: %@",[error localizedDescription]);
                    callback(pcmDB, nil,error);
                    return;
                }
                NSString *json = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
//                NSLog(@"Detect response: %@", json);
                NSDictionary *detectResp = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:&error];
                if (error != nil){
                    NSLog(@"Buyfull sdk detect, server return invalid json");
                    callback(pcmDB, nil,error);
                    return;
                }
                int resultCode = [[detectResp objectForKey:@"code"]intValue];
                NSString* reqID = [detectResp objectForKey:@"reqid"];
                if (resultCode != 0){
                    error = [NSError errorWithDomain:[NSString stringWithFormat:@"request id: %@ return error %d",reqID, resultCode] code:resultCode userInfo:detectResp];
                    NSLog(@"Buyfull sdk detect, server return error: %d", resultCode);
                    callback(pcmDB, nil,error);
                    return;
                }
                NSDictionary* finalResult = [strongself handleJSONResult:detectResp error:&error];
                if (error != nil){
                    NSLog(@"Buyfull sdk detect got error: %@",[error localizedDescription]);
                    callback(pcmDB, nil,error);
                    return;
                }
                if (finalResult == nil){
                    NSLog(@"Buyfull sdk parse result error: %@",json);
                    callback(pcmDB, nil,[NSError errorWithDomain:@"invalide server return" code:1 userInfo:nil]);
                    return;
                }
                callback(pcmDB, finalResult,nil);
                return;
            }];
            [dataTask resume];
        }];
    }
    
}


-(void) record:(BuyfullRecordCallback)callback{
    __weak BuyfullSDK* weakself = self;
    [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted){
        //check permission
        if (!granted){
            callback(nil,[NSError errorWithDomain:@"no record permission" code:2 userInfo:nil]);
            return ;
        }
        __strong BuyfullSDK* strongself = weakself;
        dispatch_async(strongself->queue, ^{
            __strong BuyfullSDK* strongself = weakself;
            if (strongself.voiceRecorder.isRecording)
                [strongself.voiceRecorder stop];
            //remove existing file and create recorder
            [[NSFileManager defaultManager] removeItemAtPath:strongself.recordFilePath error:nil];
            NSString *recordFileName = @"RecordFileName";
            strongself.recordFilePath = [BuyfullSDK GetPathByFileName:recordFileName ofType:@"wav"];
            NSError* error = nil;
            if (!strongself.voiceRecorder){
                strongself.voiceRecorder = [[AVAudioRecorder alloc]initWithURL:[NSURL fileURLWithPath:strongself.recordFilePath]
                                                                      settings:[BuyfullSDK GetAudioRecorderSettingDict]
                                                                         error:&error];
                if (error != nil){
                    NSLog(@"Error in start record: %@", [error localizedDescription]);
                    callback(nil,[NSError errorWithDomain:@"create recorder fail" code:2 userInfo:nil]);
                    return ;
                }
                strongself.voiceRecorder.delegate = strongself;
            }
            
            [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionMixWithOthers error:&error];
            
            if (error != nil){
                NSLog(@"Error in start record: %@", [error localizedDescription]);
                callback(nil,[NSError errorWithDomain:@"set audio category fail" code:2 userInfo:nil]);
                return ;
            }
            [[AVAudioSession sharedInstance] setActive:YES
                                                 error:&error];
            
            if (error != nil){
                NSLog(@"Error in start record: %@", [error localizedDescription]);
                callback(nil,[NSError errorWithDomain:@"set audio active fail" code:2 userInfo:nil]);
                return ;
            }
            
            if (![strongself.voiceRecorder prepareToRecord]){
                NSLog(@"can't record");
                callback(nil,[NSError errorWithDomain:@"prepare record fail" code:2 userInfo:nil]);
            }
            //强制使用手机内置麦克风
            NSArray* inputArray = [[AVAudioSession sharedInstance] availableInputs];
            for (AVAudioSessionPortDescription* desc in inputArray){
                if ([desc.portType isEqualToString:AVAudioSessionPortBuiltInMic]){
                    [[AVAudioSession sharedInstance] setPreferredInput:desc error:&error];
                    break;
                }
            }
            if (error != nil){
                NSLog(@"Error in start record: %@", [error localizedDescription]);
                callback(nil,[NSError errorWithDomain:@"select builtin mic fail" code:2 userInfo:nil]);
                return ;
            }
            
            if (![strongself.voiceRecorder recordForDuration:RECORD_PERIOD]){
                NSLog(@"Error in start record: %@", [error localizedDescription]);
                callback(nil,[NSError errorWithDomain:@"start recorder fail" code:2 userInfo:nil]);
                return ;
            }
            
            strongself.cb = callback;
        });
    }];
}

-(float) getDB:(NSData*)pcmData
    sampleRate:(int)sampleRate
      channels:(int)channels
          bits:(int)bits
   isLastFrame:(bool)isLastFrame
         error:(NSError**)outError{
    __autoreleasing NSError *error = nil;
    unsigned char* pcmBytes = (unsigned char*)[pcmData bytes];
    unsigned long long pcmDataSize = [pcmData length];
    int stepCount = 1024;
    int stepSize = channels * (bits / 8);
    
    if (!(sampleRate == 44100 || sampleRate == 48000)){
        error = [NSError errorWithDomain:@"invalid sample rate" code:1 userInfo:nil];
    }else if (channels < 1 || channels > 2){
        error = [NSError errorWithDomain:@"invalid channel count" code:1 userInfo:nil];
    }else if (!(bits == 16 || bits == 32)){
        error = [NSError errorWithDomain:@"invalid bit count" code:1 userInfo:nil];
    }else{
        int minPCMDataSize = stepCount * stepSize;
        if (pcmDataSize < (sampleRate * stepSize)){
            error = [NSError errorWithDomain:@"invalid pcmData length" code:1 userInfo:nil];
        }else{
            pcmBytes += (pcmDataSize - minPCMDataSize);
            if (!isLastFrame){
                pcmBytes -= sampleRate * stepSize;
            }
        }
    }
    
    if (error != nil){
        outError = &error;
        return LIMIT_DB;
    }
    
    bool allZero = true;
    float *re = self->real;
    float *im = self->imag;
    memset(re,0,sizeof(self->real));
    memset(im,0,sizeof(self->imag));
    for (int index = 0;index < stepCount;++index,pcmBytes += stepSize){
        if (bits == 16){
            re[index] = (*((short*)pcmBytes) / 32768.0);
        }else{
            re[index] = (*((float*)pcmBytes));
        }
        if (re[index] != 0){
            allZero = false;
        }
    }
    if (allZero)
        return THRESHOLD_DB;
    
    window_hanning(re, stepCount);
    fft(re,im,10,0);
    int s = 418, l = 45;
    if (sampleRate == 48000){
        s = 384, l = 42;
    }
    double db = 0;
    for (int index = 0;index < l;++index){
        double _re = re[s + index];
        double _im = im[s + index];
        db += sqrt(_re * _re + _im * _im);
    }
    db /= l;
    db = log(db) * (8.6858896380650365530225783783322);
    
    if (isnan(db) || isinf(db)){
        return THRESHOLD_DB;
    }
    return db;
}

-(NSData*) buildBin:(NSData*)pcmData
         sampleRate:(int)sampleRate
           channels:(int)channels
               bits:(int)bits
              error:(NSError**)outError{
    __autoreleasing NSError *error = nil;
    unsigned char* pcmBytes = (unsigned char*)[pcmData bytes];
    unsigned long long pcmDataSize = [pcmData length];
    int stepCount = sampleRate * RECORD_PERIOD;
    int stepSize = channels * (bits / 8);
    int resultSize = stepCount / 8;
    
    if (!(sampleRate == 44100 || sampleRate == 48000)){
        error = [NSError errorWithDomain:@"invalid sample rate" code:1 userInfo:nil];
    }else if (channels < 1 || channels > 2){
        error = [NSError errorWithDomain:@"invalid channel count" code:1 userInfo:nil];
    }else if (!(bits == 16 || bits == 32)){
        error = [NSError errorWithDomain:@"invalid bit count" code:1 userInfo:nil];
    }else{
        int minPCMDataSize = stepCount * stepSize;
        if (pcmDataSize < minPCMDataSize){
            error = [NSError errorWithDomain:@"invalid pcmData length" code:1 userInfo:nil];
        }else{
            pcmBytes += (pcmDataSize - minPCMDataSize);
        }
    }
    
    if (error != nil){
        outError = &error;
        return nil;
    }
    
    float *re = self->real;
    float *im = self->imag;
    memset(re,0,sizeof(self->real));
    memset(im,0,sizeof(self->imag));
    for (int index = 0;index < stepCount;++index,pcmBytes += stepSize){
        if (bits == 16){
            re[index] = *((short*)pcmBytes) / 32768.0;
        }else{
            re[index] = *((float*)pcmBytes);
        }
    }
    fft(re,im,LOG2_N_WAVE,0);
    
    int s = 26112;
    if (sampleRate == 48000){
        s = 24064;
    }
    memcpy(re, re + s , 16384);
    memcpy(im, im + s , 16384);
    memset(re + 4096, 0, 245760);
    memset(im + 4096, 0, 245760);
    fft(re,im,13,1);
    
    NSMutableData* result = [NSMutableData dataWithLength:resultSize + 12];
    char* resultBuffer = [result mutableBytes];
    if (sampleRate == 44100){
        resultBuffer[0] = 1;
    }else{
        resultBuffer[0] = 2;
    }
    compress(re, resultBuffer + 4, resultSize);
    
    return result;
}

-(NSURLRequest*)    requestToken:(NSString*)tokenURL
                          appkey:(NSString*)appkey
                       isSandbox:(BOOL)isSandbox
                           error:(NSError**)outError{
    NSString*   url = [NSString stringWithFormat:@"%@?appkey=%@",tokenURL, appkey];
    return [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
}

-(NSURLRequest*_Nullable) detectRequest:(NSData*_Nonnull)bin
                                 appkey:(NSString*_Nonnull)appkey
                                  token:(NSString*_Nonnull)token
                              isSandbox:(BOOL)isSandbox
                             deviceInfo:(NSString*_Nonnull)deviceInfo
                            phoneNumber:(NSString*_Nullable)phoneNumber
                                 userID:(NSString*_Nullable)userID
                             customData:(NSString*_Nullable)customData
                                  error:(NSError*_Nullable*_Nullable)outError{
    
    NSMutableDictionary *params = [[NSMutableDictionary alloc]init];
    [params setValue:appkey forKey:@"appkey"];
    [params setValue:token forKey:@"buyfulltoken"];
    [params setValue:[NSNumber numberWithBool:isSandbox] forKey:@"sandbox"];
    [params setValue:SDK_VERSION forKey:@"sdkversion"];
    [params setValue:deviceInfo forKey:@"deviceinfo"];
    
    if (phoneNumber != nil){
        [params setValue:phoneNumber forKey:@"phone"];
    }
    if (userID != nil){
        [params setValue:userID forKey:@"userid"];
    }
    if (customData != nil){
        [params setValue:customData forKey:@"customdata"];
    }
    
    NSData *data = [NSJSONSerialization dataWithJSONObject:params options:NSJSONWritingPrettyPrinted error:outError];
    NSString *json = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
//    NSLog(@"%@", json);
    NSString* cmd = [NSString stringWithFormat:@"soundtag-decode/decodev6/iOS/BIN/%@", [self URLEncodedString:json]];
//    NSString* url = [NSString stringWithFormat:@"https://api.euphonyqr.com/api/decode2?cmd=%@",cmd];
//    NSString* url = [NSString stringWithFormat:@"http://192.168.110.3:8081/api/decode2?cmd=%@",cmd];
    NSString* url = [NSString stringWithFormat:@"https://testeast.euphonyqr.com/test/api/decode_test?cmd=%@",cmd];
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    [request setHTTPMethod:@"POST"];
    [request setHTTPBody:bin];
    [request setValue:@"audio/mpeg" forHTTPHeaderField:@"content-type"];
    
    return request;
}

-(NSDictionary*_Nullable) handleJSONResult:(NSDictionary*_Nonnull)jsonResult
                                     error:(NSError*_Nullable*_Nullable)outError{
    NSArray* oldResult = [jsonResult objectForKey:@"result"];
    NSString* requestID = [jsonResult objectForKey:@"reqid"];
    if (oldResult == nil || requestID == nil || [requestID isEqualToString:@""]){
        return nil;
    }
    NSMutableSet* validTagset = [[NSMutableSet alloc] init];
    NSMutableArray* allTags = [[NSMutableArray alloc] init];
    NSMutableArray* rawResults = [[NSMutableArray alloc] init];
    NSMutableArray* sortedResults = [[NSMutableArray alloc] init];
    NSMutableArray* validResults = [[NSMutableArray alloc] init];
    for (int index = 0;index < [oldResult count]; ++index){
        NSMutableDictionary* raw_result = [[oldResult objectAtIndex:index] mutableCopy];
        [raw_result setObject:[NSNumber numberWithInt:index] forKey:@"channel"];
        [rawResults addObject:raw_result];
        int insertIndex = 0;
        BOOL insert = FALSE;
        if ([sortedResults count] > 0){
            float power = [[raw_result objectForKey:@"power"] floatValue];
            for (int index2 = 0;index2 < [sortedResults count];++index2){
                float topPower = [[[sortedResults objectAtIndex:index2] objectForKey:@"power"] floatValue];
                if (power > topPower){
                    insertIndex = index2;
                    insert = TRUE;
                    break;
                }
            }
        }
        if (!insert){
            [sortedResults addObject:raw_result];
        }else{
            [sortedResults insertObject:raw_result atIndex:insertIndex];
        }
    }
    for (int index = 0; index < [sortedResults count]; ++index){
        NSArray* tags = [[sortedResults objectAtIndex:index] objectForKey:@"tags"];
        if ([tags count] > 0){
            [validResults addObject:[sortedResults objectAtIndex:index]];

            for (int index2 = 0;index2 < [tags count];++index2){
                NSString* tag = [tags objectAtIndex:index2];
                if (![validTagset containsObject:tag]){
                    [allTags addObject:tag];
                    [validTagset addObject:tag];
                }
            }
        }
    }
    
    NSMutableDictionary* result = [[NSMutableDictionary alloc] init];
    
    [result setObject:requestID forKey:@"reqid"];
    [result setObject:rawResults forKey:@"rawResult"];
    [result setObject:sortedResults forKey:@"sortByPowerResult"];
    [result setObject:validResults forKey:@"result"];
    [result setObject:[NSNumber numberWithLong:[allTags count]] forKey:@"count"];
    [result setObject:allTags forKey:@"allTags"];
    return result;
}

-(void)debugUpload:(NSString*_Nonnull)requestID{
    NSError* err = nil;
    NSData* wavData = [NSData dataWithContentsOfFile:self.recordFilePath options:NSDataReadingUncached error:&err];
    if (err != nil){
        NSLog(@"debugUpload fail:%@", [err localizedDescription]);
        return;
    }
    NSString* cmd = [NSString stringWithFormat:@"soundtag-decode/debugupload/%@_iOS", requestID];
    NSString* url = [NSString stringWithFormat:@"https://testeast.euphonyqr.com/test/api/decode_test?cmd=%@",cmd];
//    NSString* url = [NSString stringWithFormat:@"http://192.168.110.3:8081/api/decode2?cmd=%@",cmd];
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    [request setHTTPMethod:@"POST"];
    [request setHTTPBody:wavData];
    [request setValue:@"audio/wav" forHTTPHeaderField:@"content-type"];
    NSURLSessionDataTask* dataTask = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error != nil){
            NSLog(@"debugUpload fail:%@", [error localizedDescription]);
        }else{
            NSDictionary *tokenResp = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:&error];
            NSLog(@"debugUpload success:%@\n%@", requestID, [tokenResp description]);
        }
    }];
    [dataTask resume];
}
/////////////////////////////////////////
- (instancetype _Nonnull )initWithAppkey:(NSString*_Nonnull)appkey isSandbox:(BOOL)isSandbox tokenURL:(NSString*_Nonnull)tokenURL{
    self = [super init];
    if (self) {
        if (!hasInited){
            hasInited = TRUE;
            for (int i=0; i<N_WAVE; i++)
                fsin[i] = sinf(2*Pi/N_WAVE*i);
        }
        
        queue= dispatch_queue_create("sound process", NULL);
        [self createFolder];
        struct utsname systemInfo;
        uname(&systemInfo);
        NSString* deviceType = [NSString stringWithCString:systemInfo.machine encoding:NSASCIIStringEncoding];
        NSString* osVersion = [[UIDevice currentDevice] systemVersion];
        NSString* idfa = [[[ASIdentifierManager sharedManager] advertisingIdentifier] UUIDString];
        NSMutableDictionary *deviceInfo = [[NSMutableDictionary alloc] init];
        [deviceInfo setValue:idfa forKey:@"idfa"];
        [deviceInfo setValue:deviceType forKey:@"model"];
        [deviceInfo setValue:osVersion forKey:@"version"];
        NSData *data = [NSJSONSerialization dataWithJSONObject:deviceInfo options:NSJSONWritingPrettyPrinted error:nil];
        self.deviceInfo = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
        self.appKey = appkey;
        self.isSandbox = isSandbox;
        self.tokenURL = tokenURL;
        AVAuthorizationStatus microPhoneStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
        if (microPhoneStatus == AVAuthorizationStatusAuthorized){
            self.hasMicPermission = TRUE;
        }
    }
    return self;
}

- (void)dealloc{
    if (self.voiceRecorder.isRecording)
        [self.voiceRecorder stop];
    self.voiceRecorder = nil;
    
    [self deleteRecordFile:self.recordFolderPath];
    queue = nil;
}


- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag
{
    BuyfullRecordCallback callback = self.cb;
    self.cb = nil;
    if (callback == nil){
        NSLog(@"callback is nil");
        return;
    }
    if (flag){
        [self processWav:callback];
    }else{
        callback(nil,[NSError errorWithDomain:@"record finish fail" code:5 userInfo:nil]);
    }
}

- (void)audioRecorderEncodeErrorDidOccur:(AVAudioRecorder *)recorder error:(NSError *)error
{
    NSLog(@"record error %@", [error localizedDescription]);
    BuyfullRecordCallback callback = self.cb;
    self.cb = nil;
    if (callback == nil){
        NSLog(@"callback is nil");
        return;
    }
    NSLog(@"record fail");
    callback(nil,error);
}

-(void)processWav:(BuyfullRecordCallback)callback{
    __weak id weakself = self;
    dispatch_async(self->queue, ^{
        __strong BuyfullSDK* strongself = weakself;
        [strongself.voiceRecorder stop];
        NSData* wavData = [NSData dataWithContentsOfFile:strongself.recordFilePath options:NSDataReadingUncached error:nil];
        unsigned char* rawData = ((unsigned char*)wavData.bytes) + 44;
        unsigned long rawDataSize = wavData.length - 44;
        //skip to data chunk
        int offset = 0;
        while(offset < (rawDataSize - 8) && !(rawData[offset] == 'd' && rawData[offset + 1] == 'a' && rawData[offset + 2] == 't' && rawData[offset + 3] == 'a'))
            ++offset;
        
        if (offset < (rawDataSize - 8))
            offset += 8;
        
        rawDataSize -= offset;
        rawData = rawData + offset;
        offset = 0;
        NSError* error = nil;
        NSData* pcmData = [NSData dataWithBytes:rawData length:rawDataSize];
        
        callback(pcmData, error);
    });
}

//////////////////////////////////////////////////////////////

- (NSString *)URLEncodedString:(NSString *)str {
    NSString *encodedString = [str stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    return encodedString;
}

+ (NSDictionary*)GetAudioRecorderSettingDict{
    NSDictionary *recordSetting = [[NSDictionary alloc] initWithObjectsAndKeys:
                                   [NSNumber numberWithFloat: RECORD_SAMPLE_RATE],AVSampleRateKey, //采样率
                                   [NSNumber numberWithInt: kAudioFormatLinearPCM],AVFormatIDKey,
                                   [NSNumber numberWithInt:16],AVLinearPCMBitDepthKey,//采样位数 默认 16
                                   [NSNumber numberWithInt: 1], AVNumberOfChannelsKey,//通道的数目
                                   [NSNumber numberWithBool:NO],AVLinearPCMIsBigEndianKey,//大端还是小端 是内存的组织方式
                                   [NSNumber numberWithBool:NO],AVLinearPCMIsNonInterleaved,//Interleaved
                                   [NSNumber numberWithBool:NO],AVLinearPCMIsFloatKey,//采样信号是整数还是浮点数
                                   [NSNumber numberWithInt: AVAudioQualityHigh],AVEncoderAudioQualityKey,//音频编码质量
                                   nil];
    return recordSetting;
}


- (void)createFolder{
    NSString *directoryPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES)lastObject];
    NSString *directory = [directoryPath stringByAppendingString:@"/Caches"];
    NSString *folderPath = [directory stringByAppendingString:@"/_buyfull_recordFiles"];
    
    self.recordFolderPath = folderPath;
    [[NSFileManager defaultManager] removeItemAtPath:folderPath error:nil];
    [[NSFileManager defaultManager] createDirectoryAtPath:folderPath withIntermediateDirectories:NO attributes:nil error:nil];
    
    
    
}
#pragma mark - 生成文件路径
+ (NSString*)GetPathByFileName:(NSString *)_fileName ofType:(NSString *)_type{
    NSString *directoryPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES)lastObject];
    NSString *directory = [directoryPath stringByAppendingString:@"/Caches/_buyfull_recordFiles"];
    
    NSString* fileDirectory = [[directory stringByAppendingPathComponent:_fileName]
                               stringByAppendingPathExtension:_type];
    //    NSLog(@"%@,%s",fileDirectory,__func__);
    return fileDirectory;
}

#pragma mark - 删除录音文件
-(void)deleteRecordFile:(NSString *)_deleteFileName{
    
    NSFileManager* fileManager=[NSFileManager defaultManager];
    NSString *deleteRecordFile = _deleteFileName;
    [fileManager removeItemAtPath:deleteRecordFile error:nil];
}

int fft(float* fr, float* fi, int m, int inv){
    int mr,nn,i,j,l,k,istep,n,scale,shift;
    float qr,qi,tr,ti,wr,wi;
    
    n = 1<<m;
    
    if(n > N_WAVE)
        return -1;
    
    mr = 0;
    nn = n - 1;
    scale = 0;
    
    for(m=1; m<=nn; ++m) {
        l = n;
        do {
            l >>= 1;
        } while(mr+l > nn);
        mr = (mr & (l-1)) + l;
        
        if(mr <= m) continue;
        tr = fr[m];
        fr[m] = fr[mr];
        fr[mr] = tr;
        ti = fi[m];
        fi[m] = fi[mr];
        fi[mr] = ti;
    }
    
    l = 1;
    k = LOG2_N_WAVE-1;
    while(l < n) {
        if(inv) {
            shift = 0;
        } else {
            shift = 1;
        }
        
        istep = l << 1;
        float h = 0.5f;
        for(m=0; m<l; ++m) {
            j = m << k;
            wr =  fsin[j+N_WAVE/4];
            wi = -fsin[j];
            if(inv)
                wi = -wi;
            if(shift) {
                wr *= h;
                wi *= h;
            }
            for(i=m; i<n; i+=istep) {
                j = i + l;
                tr = wr*fr[j]-wi*fi[j];
                ti = wr*fi[j]+wi*fr[j];
                qr = fr[i];
                qi = fi[i];
                if(shift) {
                    qr *= h;
                    qi *= h;
                }
                fr[j] = qr - tr;
                fi[j] = qi - ti;
                fr[i] = qr + tr;
                fi[i] = qi + ti;
            }
        }
        --k;
        l = istep;
    }
    
    return scale;
}

void window_hanning(float* fr, unsigned int n) {
    int j = N_WAVE/n;
    for(int i=0, k=N_WAVE/4; i<n; ++i,k+=j)
        fr[i] *= 0.5f-0.5f*fsin[k%N_WAVE];
}

int compress(float *input, char *output, unsigned int numberOfSamples){
    float max = -9999999999, min = 9999999999;
    
    for (int index = 0;index < numberOfSamples;++index){
        float temp = input[index];
        if (temp > max)
            max = temp;
        if (temp < min)
            min = temp;
    }
    float range = (max - min);
    float average = (max + min) / 2;
    float factor = range / 256;
    
    float* floatOutput = (float*)output;
    floatOutput[0] = average * 2;
    floatOutput[1] = factor * 2;
    for (int index = 0;index < numberOfSamples;++index){
        float temp = input[index] - average;
        int result = (temp / factor);
        if (result > 127)
            result = 127;
        else if (result < -128)
            result = -128;
        output[8+index] = result;
    }
    return 8+numberOfSamples;
}
@end

