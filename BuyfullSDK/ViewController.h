//
//  ViewController.h
//  BuyfullSDK
//
//  Created by 叶常青 on 2019/7/12.
//  Copyright © 2019年 buyfull. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController

@property (nonatomic, retain) IBOutlet UILabel *result;
@property (nonatomic, retain) IBOutlet UIButton *test;

-(IBAction)onTest:(id)sender;
-(IBAction)onDebugUpload:(id)sender;
@end

