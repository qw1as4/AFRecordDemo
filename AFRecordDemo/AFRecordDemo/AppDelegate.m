//
//  AppDelegate.m
//  AFRecordDemo
//
//  Created by zkl on 2020/12/15.
//  Copyright © 2020 zkl. All rights reserved.
//

#import "AppDelegate.h"
#import "AFRecordingViewController.h"

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    self.window = [[UIWindow alloc]initWithFrame:[UIScreen mainScreen].bounds];
    self.window.backgroundColor = [UIColor whiteColor];
    AFRecordingViewController *vc = [[AFRecordingViewController alloc]init];
    self.window.rootViewController = vc;
    [self.window makeKeyAndVisible];
    
    return YES;
}




@end
