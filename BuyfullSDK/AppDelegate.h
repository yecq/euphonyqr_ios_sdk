//
//  AppDelegate.h
//  BuyfullSDK
//
//  Created by 叶常青 on 2019/7/12.
//  Copyright © 2019年 buyfull. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BuyfullSDK.h"


@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (strong, atomic) BuyfullSDK *buyfullSDK;//一个APP中应该只有一个实例

@end

