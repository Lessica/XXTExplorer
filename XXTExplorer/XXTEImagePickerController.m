//
//  XXTEImagePickerController.m
//  XXTExplorer
//
//  Created by Zheng on 11/07/2017.
//  Copyright © 2017 Zheng. All rights reserved.
//

#import "XXTEImagePickerController.h"

@interface XXTEImagePickerController ()

@end

@implementation XXTEImagePickerController

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

#pragma mark - Memory

- (void)dealloc {
#ifdef DEBUG
    NSLog(@"- [XXTEImagePickerController dealloc]");
#endif
}

@end