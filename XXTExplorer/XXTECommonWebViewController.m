//
//  XXTECommonWebViewController.m
//  XXTExplorer
//
//  Created by Zheng on 03/07/2017.
//  Copyright © 2017 Zheng. All rights reserved.
//

#import "XXTECommonWebViewController.h"

@interface XXTECommonWebViewController ()

@end

@implementation XXTECommonWebViewController

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.loadingBarTintColor = XXTE_COLOR_SUCCESS;
    self.hideWebViewBoundaries = YES;
    self.hidesBottomBarWhenPushed = YES;
    
    self.webView.opaque = NO;
}

- (void)showPlaceholderTitle {
    
}

@end
