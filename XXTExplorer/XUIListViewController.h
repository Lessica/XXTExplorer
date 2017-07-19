//
//  XUIListViewController.h
//  XXTExplorer
//
//  Created by Zheng on 17/07/2017.
//  Copyright © 2017 Zheng. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface XUIListViewController : UITableViewController

@property (nonatomic, copy, readonly) NSString *entryPath;
- (instancetype)initWithRootEntry:(NSString *)entryPath;

@end