//
//  XXTEUIViewController+XUITitleValueCell.m
//  XXTExplorer
//
//  Created by Zheng Wu on 29/09/2017.
//  Copyright © 2017 Zheng. All rights reserved.
//

#import "XXTEUIViewController+XUITitleValueCell.h"
#import "XXTEObjectViewController.h"

#import "XUITitleValueCell.h"
#import "XXTPickerFactory.h"
#import "XXTPickerSnippet.h"
#import "XXTPickerSnippetTask.h"

#import <objc/runtime.h>
#import <XUI/XUICellFactory.h>
#import <XUI/XUITheme.h>

static const void * XUITitleValueCellStorageKey = &XUITitleValueCellStorageKey;

@implementation XXTEUIViewController (XUITitleValueCell)

- (void)tableView:(UITableView *)tableView XUITitleValueCell:(UITableViewCell *)cell {
    XUITitleValueCell *titleValueCell = (XUITitleValueCell *)cell;
    if (titleValueCell.xui_snippet) {
        id <XUIAdapter> adapter = self.adapter;
        NSString *snippetPath = [self.bundle pathForResource:titleValueCell.xui_snippet ofType:nil];
        NSError *snippetError = nil;
        XXTPickerSnippet *snippet = [[XXTPickerSnippet alloc] initWithContentsOfFile:snippetPath Adapter:adapter Error:&snippetError];
        if (snippetError) {
            [self presentErrorAlertController:snippetError];
            return;
        }
        XXTPickerSnippetTask *task = [[XXTPickerSnippetTask alloc] initWithSnippet:snippet];
        XXTPickerFactory *factory = [XXTPickerFactory sharedInstance];
        factory.delegate = self;
        [factory beginTask:task fromViewController:self];
        objc_setAssociatedObject(self, XUITitleValueCellStorageKey, titleValueCell, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } else {
        [self tableView:tableView accessoryXUITitleValueCell:cell];
    }
}

- (void)tableView:(UITableView *)tableView accessoryXUITitleValueCell:(UITableViewCell *)cell {
    XUITitleValueCell *titleValueCell = (XUITitleValueCell *)cell;
    if (titleValueCell.xui_value) {
        id extendedValue = titleValueCell.xui_value;
        XXTEObjectViewController *objectViewController = [[XXTEObjectViewController alloc] initWithRootObject:extendedValue];
        objectViewController.title = titleValueCell.textLabel.text;
        objectViewController.entryBundle = self.bundle;
        objectViewController.tableViewStyle = self.theme.tableViewStyle;
        objectViewController.containerDisplayMode = XXTEObjectContainerDisplayModeCount;
        [self.navigationController pushViewController:objectViewController animated:YES];
    }
}

#pragma mark - XXTPickerFactoryDelegate

- (BOOL)pickerFactory:(XXTPickerFactory *)factory taskShouldEnterNextStep:(XXTPickerSnippetTask *)task {
    return YES;
}

- (void)pickerFactory:(XXTPickerFactory *)factory taskShouldFinished:(XXTPickerSnippetTask *)task responseBlock:(void (^)(BOOL, NSError *))responseCallback {
    UIViewController *blockVC = blockInteractions(self, YES);
    @weakify(self);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        @strongify(self);
        NSError *error = nil;
        id result = [task generateWithError:&error];
        dispatch_async_on_main_queue(^{
            blockInteractions(blockVC, NO);
            if (result) {
                XUITitleValueCell *cell = objc_getAssociatedObject(self, XUITitleValueCellStorageKey);
                if ([cell isKindOfClass:[XUITitleValueCell class]]) {
                    cell.xui_value = result;
                    [self storeCellWhenNeeded:cell];
                }
                objc_setAssociatedObject(self, XUITitleValueCellStorageKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                responseCallback(YES, nil);
            } else {
                // [self presentErrorAlertController:error];
                responseCallback(NO, error);
            }
        });
    });
}

- (void)pickerFactory:(XXTPickerFactory *)factory taskDidFinished:(XXTPickerSnippetTask *)task
{
    [self storeCellsIfNecessary];
}

@end
