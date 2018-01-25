//
//  XXTEMasterViewController.h
//  XXTExplorer
//
//  Created by Zheng on 25/05/2017.
//  Copyright © 2017 Zheng. All rights reserved.
//

#import <UIKit/UIKit.h>

@class XXTEUpdateHelper, XXTEUpdateAgent;

typedef enum : NSUInteger {
    kMasterViewControllerIndexExplorer = 0,
    kMasterViewControllerIndexCloud,
    kMasterViewControllerIndexMore,
    kMasterViewControllerIndexMax,
} kMasterViewControllerIndex;

@interface XXTEMasterViewController : UITabBarController

- (void)setTabBarVisible:(BOOL)visible animated:(BOOL)animated completion:(void (^)(BOOL))completion;
- (BOOL)tabBarIsVisible;

#ifndef APPSTORE
- (void)checkUpdate;
#endif

@end
