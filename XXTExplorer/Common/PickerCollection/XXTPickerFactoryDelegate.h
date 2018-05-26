//
//  XXTPickerFactoryDelegate.h
//  XXTExplorer
//
//  Created by Zheng on 2018/5/27.
//  Copyright © 2018 Zheng. All rights reserved.
//

#import <Foundation/Foundation.h>

@class XXTPickerFactory, XXTPickerSnippetTask;

@protocol XXTPickerFactoryDelegate <NSObject>

- (BOOL)pickerFactory:(XXTPickerFactory *)factory taskShouldEnterNextStep:(XXTPickerSnippetTask *)task;
- (BOOL)pickerFactory:(XXTPickerFactory *)factory taskShouldFinished:(XXTPickerSnippetTask *)task;

@end

