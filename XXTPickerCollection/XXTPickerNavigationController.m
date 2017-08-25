//
//  XXTPickerNavigationController.m
//  XXTPickerCollection
//
//  Created by Zheng on 29/04/2017.
//  Copyright © 2017 Zheng. All rights reserved.
//

#import "XXTPickerNavigationController.h"
#import "XXTBasePicker.h"
#import "XXTPickerFactory.h"

@interface XXTPickerNavigationController () <UINavigationControllerDelegate>

@end

@implementation XXTPickerNavigationController

- (instancetype)initWithRootViewController:(UIViewController *)rootViewController {
    if (self = [super initWithRootViewController:rootViewController]) {
        self.delegate = self;
        rootViewController.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(dismiss)];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationBar.translucent = NO;
    [self.view addSubview:self.popupBar];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

}

- (void)dismiss {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UIView Getters

- (XXTPickerPreviewBar *)popupBar {
    if (!_popupBar) {
        XXTPickerPreviewBar *popupBar = [[XXTPickerPreviewBar alloc] initWithFrame:CGRectMake(0, self.view.bounds.size.height - 44.f, self.view.bounds.size.width, 44.f)];
        popupBar.userInteractionEnabled = YES;
        popupBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
        UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(previewBarTapped:)];
        [popupBar addGestureRecognizer:tapGesture];
        _popupBar = popupBar;
    }
    return _popupBar;
}

#pragma mark - Preview

- (void)previewBarTapped:(XXTPickerPreviewBar *)sender {
    
}

#pragma mark - UINavigationControllerDelegate

- (void)navigationController:(UINavigationController *)navigationController didShowViewController:(UIViewController *)viewController animated:(BOOL)animated {
    if (navigationController == self) {
        if ([viewController respondsToSelector:@selector(pickerFactory)]) {
            UIViewController *pickerController = viewController;
            [self.view bringSubviewToFront:self.popupBar];
            if ([pickerController respondsToSelector:@selector(tableView)]) {
                UITableViewController *tablePickerController = (UITableViewController *)viewController;
                UIEdgeInsets insets = tablePickerController.tableView.contentInset;
                insets.bottom = self.popupBar.bounds.size.height;
                tablePickerController.tableView.contentInset =
                tablePickerController.tableView.scrollIndicatorInsets = insets;
            }
        }
    }
    if ([viewController conformsToProtocol:@protocol(XXTBasePicker)]) {
        if (YES == self.popupBar.hidden) {
            self.popupBar.hidden = NO;
            [UIView animateWithDuration:.2f animations:^{
                self.popupBar.frame = CGRectMake(0, self.view.bounds.size.height - 44.f, self.view.bounds.size.width, 44.f);
            } completion:^(BOOL finished) {
            }];
        }
    } else {
        if (NO == self.popupBar.hidden) {
            [UIView animateWithDuration:.2f animations:^{
                self.popupBar.frame = CGRectMake(0, self.view.bounds.size.height, self.view.bounds.size.width, 44.f);
            } completion:^(BOOL finished) {
                if (finished) self.popupBar.hidden = YES;
            }];
        }
    }
}

@end