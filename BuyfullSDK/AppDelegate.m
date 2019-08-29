//
//  AppDelegate.m
//  BuyfullSDK
//
//  Created by 叶常青 on 2019/7/12.
//  Copyright © 2019年 buyfull. All rights reserved.
//

#import "AppDelegate.h"

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // appkey和sandbox请向动听员工询问，tokenURL需要自行布署，此处只是DEMO
    self.buyfullSDK = [[BuyfullSDK alloc]initWithAppkey:@"75ba120532f44aa7a8cd431a2c2a50ef" isSandbox:TRUE tokenURL:@"https://sandbox.buyfull.cc/testycq2/buyfulltoken"];
    // userID或phoneNumber可以做为数据分析标识通过动听后台API返回，请任意设置一个
//    self.buyfullSDK.phoneNumber = @"13xxxxxxxxxxxx";
//    self.buyfullSDK.userID = @"custom user id";
    return YES;
}


- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}


- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
