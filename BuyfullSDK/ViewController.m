//
//  ViewController.m
//  BuyfullSDK
//
//  Created by 叶常青 on 2019/7/12.
//  Copyright © 2019年 buyfull. All rights reserved.
//

#import "ViewController.h"
#import "AppDelegate.h"

@interface ViewController ()

@property (nonatomic ,strong) NSString *lastRequestID;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(IBAction)onDebugUpload:(id)sender{
    //APP要自已申请麦克风权限，申请成功后才能正常调用SDK
    //SDK中自带麦请麦克风权限代码，可以自行修改
    if (self.lastRequestID == nil)
        return;
    AppDelegate* app = (AppDelegate*)[UIApplication sharedApplication].delegate;
    [app.buyfullSDK debugUpload:self.lastRequestID];
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    pasteboard.string = self.lastRequestID;
    self.result.text = @"RequestID 已经在剪切板中，可以在微信中粘贴给工作人员用做查询";
}

-(IBAction)onTest:(id)sender{
    //APP要自已申请麦克风权限，申请成功后才能正常调用SDK
    //SDK中自带麦请麦克风权限代码，可以自行修改
    [self doTest];
}

-(void) doTest{
    //每个APP中只应该有一个BUYFULLSDK的实例
    AppDelegate* app = (AppDelegate*)[UIApplication sharedApplication].delegate;
    // userID或phoneNumber可以做为数据分析标识通过动听后台API返回，请任意设置一个
    app.buyfullSDK.phoneNumber = @"13xxxxxxxxxxxx";
    app.buyfullSDK.userID = @"custom user id";
    //不能在检测未返回时重复调用
    if (app.buyfullSDK.isDetecting){
        NSLog(@"Please wait until last detect return");
        self.result.text = @"Please wait and retry later";
    }else{
        [app.buyfullSDK detect:@"you can add custom data" callback:^(float dB, NSDictionary * jsonResp, NSError * err) {
            //检测回调有可能在非主线程
            dispatch_async(dispatch_get_main_queue(), ^{
                if (err != nil){
                    self.result.text = [err localizedDescription];
                }else if(jsonResp == nil){
                    self.result.text = [NSString stringWithFormat:@"No detect result, signal dB is %f", dB];//音量太低不检测
                }else{
                    NSString* requestID = [jsonResp objectForKey:@"reqid"];//requestID可以用于在动听后台查询日志
                    self.lastRequestID = requestID;
                    int tagCount = [[jsonResp objectForKey:@"count"] intValue];//有效结果个数
                    if (tagCount > 0){
                        NSArray* allTags =  [jsonResp objectForKey:@"allTags"];
                        self.result.text = [NSString stringWithFormat:@"RequestID is: %@\nTest result is:\n %@", requestID, [allTags componentsJoinedByString:@","]];
                    }else{
                        NSArray* sortedResults = [jsonResp objectForKey:@"sortByPowerResult"];
                        NSDictionary* result1 = [sortedResults objectAtIndex:0];
                        NSDictionary* result2 = [sortedResults objectAtIndex:1];
                        self.result.text = [NSString stringWithFormat:@"RequestID is: %@\nTest result is null, power is (dB):\n %f | %f", requestID, [[result1 objectForKey:@"power"] floatValue] , [[result2 objectForKey:@"power"] floatValue]];
                    }
                }
                
            });
        }];
    }
}


@end
