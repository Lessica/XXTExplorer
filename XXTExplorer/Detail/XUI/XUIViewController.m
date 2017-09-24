//
// Created by Zheng on 26/07/2017.
// Copyright (c) 2017 Zheng. All rights reserved.
//

#import "XUIViewController.h"
#import "XUIEntryReader.h"
#import "XUITheme.h"

#import "UIViewController+PreviousViewController.h"

@interface XUIViewController ()

@property (nonatomic, assign) BOOL fromXUIViewController;

@end

@implementation XUIViewController

@synthesize entryPath = _entryPath, awakeFromOutside = _awakeFromOutside;

+ (NSString *)viewerName {
    return NSLocalizedString(@"Interface Viewer", nil);
}

+ (NSArray <NSString *> *)suggestedExtensions {
    return @[@"xui"];
}

+ (Class)relatedReader {
    return [XUIEntryReader class];
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    if (self.theme) {
        if ([self.theme isDarkMode]) {
            return UIStatusBarStyleLightContent;
        } else {
            return UIStatusBarStyleDefault;
        }
    } else {
        return [super preferredStatusBarStyle];
    }
}

- (instancetype)init {
    if (self = [super init]) {
        [self setupXUI];
    }
    return self;
}

- (instancetype)initWithPath:(NSString *)path {
    if (self = [super init]) {
        _entryPath = path;
        [self setupXUI];
    }
    return self;
}

- (void)setupXUI {
    self.hidesBottomBarWhenPushed = YES;
    
    _theme = [[XUITheme alloc] init];
}

- (void)viewWillAppear:(BOOL)animated {
    [self renderNavigationBarTheme:NO];
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (void)willMoveToParentViewController:(UIViewController *)parent {
    if (parent == nil) {
        if (self.fromXUIViewController == NO) {
            [self renderNavigationBarTheme:YES];
        }
    }
    [super willMoveToParentViewController:parent];
}

- (void)didMoveToParentViewController:(UIViewController *)parent {
    if (parent != nil) {
        if ([[self previousViewController] isKindOfClass:[XUIViewController class]]) {
            self.fromXUIViewController = YES;
        }
    }
    [super didMoveToParentViewController:parent];
}

#pragma mark - Navigation Bar Color

- (void)renderNavigationBarTheme:(BOOL)restore {
    if (XXTE_PAD) return;
    UIColor *backgroundColor = XXTE_COLOR;
    UIColor *foregroundColor = [UIColor whiteColor];
    if (restore) {
        [self.navigationController.navigationBar setTitleTextAttributes:@{NSForegroundColorAttributeName : foregroundColor}];
        self.navigationController.navigationBar.tintColor = foregroundColor;
        self.navigationController.navigationBar.barTintColor = backgroundColor;
        self.navigationController.navigationItem.leftBarButtonItem.tintColor = foregroundColor;
        self.navigationController.navigationItem.rightBarButtonItem.tintColor = foregroundColor;
    } else {
        if (self.theme) {
            if (self.theme.navigationTitleColor)
                foregroundColor = self.theme.navigationTitleColor;
            if (self.theme.navigationBarColor)
                backgroundColor = self.theme.navigationBarColor;
        }
        [self.navigationController.navigationBar setTitleTextAttributes:@{NSForegroundColorAttributeName : foregroundColor}];
        self.navigationController.navigationBar.tintColor = foregroundColor;
        self.navigationController.navigationBar.barTintColor = backgroundColor;
        self.navigationController.navigationItem.leftBarButtonItem.tintColor = foregroundColor;
        self.navigationController.navigationItem.rightBarButtonItem.tintColor = foregroundColor;
    }
    [self setNeedsStatusBarAppearanceUpdate];
}

@end
