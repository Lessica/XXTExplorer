//
//  XXTEMasterViewController+Notifications.h
//  XXTExplorer
//
//  Created by Zheng on 06/10/2017.
//  Copyright © 2017 Zheng. All rights reserved.
//

#import "XXTEMasterViewController.h"
#import "XXTEScanViewController.h"

#ifndef APPSTORE

@interface XXTEMasterViewController (Notifications) <XXTEScanViewControllerDelegate>

- (void)registerNotifications;
- (void)removeNotifications;
- (void)presentWebViewControllerWithURL:(NSURL *)url;

@end

#else

@interface XXTEMasterViewController (Notifications)

- (void)registerNotifications;
- (void)removeNotifications;

@end

#endif
