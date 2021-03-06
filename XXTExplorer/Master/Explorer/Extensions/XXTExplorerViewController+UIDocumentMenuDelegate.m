//
//  XXTExplorerViewController+UIDocumentMenuDelegate.m
//  XXTExplorer
//
//  Created by Zheng on 17/09/2017.
//  Copyright © 2017 Zheng. All rights reserved.
//

#import "XXTExplorerViewController+UIDocumentMenuDelegate.h"
#import "XXTExplorerViewController+UIDocumentPickerDelegate.h"

@implementation XXTExplorerViewController (UIDocumentMenuDelegate)

XXTE_START_IGNORE_PARTIAL
- (void)documentMenuWasCancelled:(UIDocumentMenuViewController *)documentMenu {
    
}
XXTE_END_IGNORE_PARTIAL

XXTE_START_IGNORE_PARTIAL
- (void)documentMenu:(UIDocumentMenuViewController *)documentMenu didPickDocumentPicker:(UIDocumentPickerViewController *)documentPicker {
    [[UINavigationBar appearanceWhenContainedIn:[UIDocumentPickerViewController class], nil] setBarTintColor:XXTColorBarTint()];
    documentPicker.delegate = self;
    documentPicker.presentationController.delegate = self;
    [self.navigationController presentViewController:documentPicker animated:YES completion:nil];
}
XXTE_END_IGNORE_PARTIAL

@end
