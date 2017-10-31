//
// Created by Zheng on 11/07/2017.
// Copyright (c) 2017 Zheng. All rights reserved.
//

#import <objc/runtime.h>
#import <objc/message.h>
#import <sys/stat.h>
#import "XXTEDownloadViewController.h"
#import "XXTEMoreAddressCell.h"
#import "XXTEMoreLinkNoIconCell.h"
#import <LGAlertView/LGAlertView.h>
#import <PromiseKit/PromiseKit.h>
#import "XXTEAppDefines.h"
#import "XXTEUserInterfaceDefines.h"
#import "XXTENotificationCenterDefines.h"

typedef enum : NSUInteger {
    kXXTExplorerDownloadViewSectionIndexSource = 0,
    kXXTExplorerDownloadViewSectionIndexTarget,
    kXXTExplorerDownloadViewSectionIndexMax
} kXXTExplorerCreateItemViewSectionIndex;

@interface XXTEDownloadViewController () <LGAlertViewDelegate, NSURLConnectionDelegate, NSURLConnectionDataDelegate>

@property (nonatomic, strong) UIBarButtonItem *closeButtonItem;
@property (nonatomic, strong) UIBarButtonItem *downloadButtonItem;

@property (nonatomic, strong, readonly) NSURL *sourceURL;
@property (nonatomic, strong, readonly) NSString *targetPath;

@property (nonatomic, strong, readonly) NSFileManager *downloadFileManager;
//@property (nonatomic, strong, readonly) NSMutableData *downloadData;
@property (nonatomic, strong) NSFileHandle *downloadFileHandle;
@property (nonatomic, strong) NSURLConnection *downloadURLConnection;
@property (nonatomic, weak) LGAlertView *currentAlertView;

@end

@implementation XXTEDownloadViewController {
    BOOL isFirstTimeLoaded;
    NSArray <NSArray <UITableViewCell *> *> *staticCells;
    NSArray <NSString *> *staticSectionTitles;
    NSArray <NSString *> *staticSectionFooters;
    NSArray <NSNumber *> *staticSectionRowNum;
    BOOL busyOperationProgressFlag;
    long long expectedFileSize;
    long long receivedFileSize;
}

- (instancetype)init {
    if (self = [super init]) {
        [self setup];
    }
    return self;
}

- (instancetype) initWithStyle:(UITableViewStyle)style {
    if (self = [super initWithStyle:style]) {
        [self setup];
    }
    return self;
}

- (instancetype)initWithSourceURL:(NSURL *)url targetPath:(NSString *)path {
    if (self = [super initWithStyle:UITableViewStyleGrouped]) {
        _sourceURL = url;
        _targetPath = path;
        [self setup];
    }
    return self;
}

- (void)setup {
    busyOperationProgressFlag = NO;
    _downloadFileManager = [[NSFileManager alloc] init];
//    _downloadData = [[NSMutableData alloc] initWithLength:0];
    _downloadFileHandle = nil;
}

#pragma mark - UIViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    XXTE_START_IGNORE_PARTIAL
    if (@available(iOS 8.0, *)) {
        self.clearsSelectionOnViewWillAppear = self.splitViewController.isCollapsed;
    }
    XXTE_END_IGNORE_PARTIAL
    
    self.title = NSLocalizedString(@"Download", nil);
    
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    
    XXTE_START_IGNORE_PARTIAL
    if (@available(iOS 9.0, *)) {
        self.tableView.cellLayoutMarginsFollowReadableWidth = NO;
    }
    XXTE_END_IGNORE_PARTIAL
    
    if ([self.navigationController.viewControllers firstObject] == self) {
        self.navigationItem.leftBarButtonItem = self.closeButtonItem;
    }
    self.navigationItem.rightBarButtonItem = self.downloadButtonItem;
    
    [self reloadStaticTableViewData];
}

- (void)reloadStaticTableViewData {
    staticSectionTitles = @[ NSLocalizedString(@"Source URL", nil),
                             NSLocalizedString(@"Target Path", nil)
                             ];
    staticSectionFooters = @[ @"", NSLocalizedString(@"Please confirm these information.\n\nThe source is provided by third party script author.\nTap \"Download\" if you can make sure that the source is trusted.", nil) ];
    
    XXTEMoreAddressCell *cell1 = [[[NSBundle mainBundle] loadNibNamed:NSStringFromClass([XXTEMoreAddressCell class]) owner:nil options:nil] lastObject];
    cell1.addressLabel.text = [self.sourceURL absoluteString];
    
    XXTEMoreAddressCell *cell2 = [[[NSBundle mainBundle] loadNibNamed:NSStringFromClass([XXTEMoreAddressCell class]) owner:nil options:nil] lastObject];
    cell2.addressLabel.text = self.targetPath;
    
    staticCells = @[
                    @[ cell1 ],
                    @[ cell2 ]
                    ];
}


#pragma mark - UIView Getters

- (UIBarButtonItem *)closeButtonItem {
    if (!_closeButtonItem) {
        UIBarButtonItem *closeButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(dismissViewController:)];
        closeButtonItem.tintColor = [UIColor whiteColor];
        _closeButtonItem = closeButtonItem;
    }
    return _closeButtonItem;
}

- (UIBarButtonItem *)downloadButtonItem {
    if (!_downloadButtonItem) {
        UIBarButtonItem *downloadButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave target:self action:@selector(confirmDownload:)];
        downloadButtonItem.tintColor = [UIColor whiteColor];
        _downloadButtonItem = downloadButtonItem;
    }
    return _downloadButtonItem;
}

#pragma mark - UITableViewDelegate & UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return kXXTExplorerDownloadViewSectionIndexMax;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (tableView == self.tableView) {
        return staticCells[(NSUInteger) section].count;
    }
    return 0;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    return 44.f;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView == self.tableView) {
        if (@available(iOS 8.0, *)) {
            return UITableViewAutomaticDimension;
        } else {
            UITableViewCell *cell = staticCells[indexPath.section][indexPath.row];
            [cell setNeedsUpdateConstraints];
            [cell updateConstraintsIfNeeded];
            
            cell.bounds = CGRectMake(0.0f, 0.0f, CGRectGetWidth(tableView.bounds), CGRectGetHeight(cell.bounds));
            [cell setNeedsLayout];
            [cell layoutIfNeeded];
            
            CGFloat height = [cell.contentView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize].height;
            return (height > 0) ? (height + 1.0) : 44.f;
        }
    }
    return 44.f;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (tableView == self.tableView) {
        if (indexPath.section == kXXTExplorerDownloadViewSectionIndexSource) {
            if (indexPath.row == 0) {
                NSString *detailText = ((XXTEMoreAddressCell *)staticCells[indexPath.section][indexPath.row]).addressLabel.text;
                if (detailText && detailText.length > 0) {
                    blockInteractions(self, YES);
                    [PMKPromise new:^(PMKFulfiller fulfill, PMKRejecter reject) {
                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                            [[UIPasteboard generalPasteboard] setString:detailText];
                            fulfill(nil);
                        });
                    }].finally(^() {
                        toastMessage(self, NSLocalizedString(@"Source URL has been copied to the pasteboard.", nil));
                        blockInteractions(self, NO);
                    });
                }
            }
        }
        else if (indexPath.section == kXXTExplorerDownloadViewSectionIndexTarget) {
            if (indexPath.row == 0) {
                NSString *detailText = ((XXTEMoreAddressCell *)staticCells[indexPath.section][indexPath.row]).addressLabel.text;
                if (detailText && detailText.length > 0) {
                    blockInteractions(self, YES);
                    [PMKPromise new:^(PMKFulfiller fulfill, PMKRejecter reject) {
                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                            [[UIPasteboard generalPasteboard] setString:detailText];
                            fulfill(nil);
                        });
                    }].finally(^() {
                        toastMessage(self, NSLocalizedString(@"Target Path has been copied to the pasteboard.", nil));
                        blockInteractions(self, NO);
                    });
                }
            }
        }
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (tableView == self.tableView) {
        return staticSectionTitles[(NSUInteger) section];
    }
    return @"";
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (tableView == self.tableView) {
        return staticSectionFooters[(NSUInteger) section];
    }
    return @"";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView == self.tableView) {
        UITableViewCell *cell = staticCells[(NSUInteger) indexPath.section][(NSUInteger) indexPath.row];
        return cell;
    }
    return [UITableViewCell new];
}

#pragma mark - UIControl Actions

- (void)dismissViewController:(id)sender {
    if (XXTE_PAD) {
        [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:XXTENotificationEvent object:self userInfo:@{XXTENotificationEventType: XXTENotificationEventTypeFormSheetDismissed}]];
    }
    [self dismissViewControllerAnimated:YES completion:^{
        
    }];
}

- (void)confirmDownload:(id)sender {
    NSString *targetPath = self.targetPath;
    NSString *targetName = [targetPath lastPathComponent];
    struct stat targetStat;
    if (0 == lstat([targetPath UTF8String], &targetStat)) {
        LGAlertView *existsAlertView = [[LGAlertView alloc] initWithTitle:NSLocalizedString(@"Overwrite Confirm", nil)
                                                                  message:[NSString stringWithFormat:NSLocalizedString(@"File \"%@\" exists, overwrite it?", nil), targetName]
                                                                    style:LGAlertViewStyleActionSheet
                                                             buttonTitles:nil
                                                        cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                                   destructiveButtonTitle:NSLocalizedString(@"Yes", nil)
                                                                 delegate:self];
        objc_setAssociatedObject(existsAlertView, @selector(alertView:overwritePath:), targetPath, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [existsAlertView showAnimated];
    } else {
        [self alertView:nil overwritePath:targetPath];
    }
}

- (void)alertViewDestructed:(LGAlertView *)alertView {
    SEL selectors[] = {
        @selector(alertView:overwritePath:)
    };
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    for (int i = 0; i < sizeof(selectors) / sizeof(SEL); i++) {
        SEL selector = selectors[i];
        id obj = objc_getAssociatedObject(alertView, selector);
        if (obj) {
            [self performSelector:selector withObject:alertView withObject:obj];
            break;
        }
    }
#pragma clang diagnostic pop
}

- (void)alertViewCancelled:(LGAlertView *)alertView {
    if (busyOperationProgressFlag) {
        NSURLConnection *currentConnection = self.downloadURLConnection;
        if (currentConnection) {
            [currentConnection cancel];
            [self connection:currentConnection didFailWithError:[NSError errorWithDomain:kXXTErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Download terminated: User interrupt occurred.", nil)}]];
            self.downloadURLConnection = nil;
        }
        busyOperationProgressFlag = NO;
    } else {
        [alertView dismissAnimated];
    }
}

- (void)alertView:(LGAlertView *)alertView clickedButtonAtIndex:(NSUInteger)index title:(NSString *)title
{
    if (index == 0) {
        [alertView dismissAnimated];
        if (XXTE_PAD) {
            [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:XXTENotificationEvent object:self userInfo:@{XXTENotificationEventType: XXTENotificationEventTypeFormSheetDismissed}]];
        }
        [self dismissViewControllerAnimated:YES completion:^{
            
        }];
    }
}

- (void)alertView:(nullable LGAlertView *)alertView overwritePath:(NSString *)path {
    NSURL *sourceURL = self.sourceURL;
    NSString *targetPath = path;
    NSString *targetName = [targetPath lastPathComponent];
    { // Remove old file
        NSError *removeError = nil;
        BOOL removeResult = [self.downloadFileManager removeItemAtPath:targetPath error:&removeError];
        struct stat targetStat;
        if (0 == lstat([targetPath UTF8String], &targetStat) && !removeResult) {
            LGAlertView *removeAlertView = [[LGAlertView alloc] initWithTitle:NSLocalizedString(@"Overwrite Failed", nil)
                                                                      message:[NSString stringWithFormat:NSLocalizedString(@"Cannot overwrite file \"%@\".\n%@", nil), targetName, [removeError localizedDescription]]
                                                                        style:LGAlertViewStyleActionSheet
                                                                 buttonTitles:nil
                                                            cancelButtonTitle:NSLocalizedString(@"Retry", nil)
                                                       destructiveButtonTitle:nil
                                                                     delegate:self];
            if (alertView && alertView.isShowing) {
                [alertView transitionToAlertView:removeAlertView completionHandler:nil];
            } else {
                [removeAlertView showAnimated];
            }
            return;
        }
    }
    { // Create and Open file for writing
        // Create new file
        BOOL createResult = [self.downloadFileManager createFileAtPath:targetPath contents:[NSData data] attributes:nil];
        NSFileHandle *downloadFileHandle = [NSFileHandle fileHandleForUpdatingAtPath:self.targetPath];
        if (!createResult || !downloadFileHandle) {
            LGAlertView *handleAlertView = [[LGAlertView alloc] initWithTitle:NSLocalizedString(@"Creation Failed", nil)
                                                                      message:[NSString stringWithFormat:NSLocalizedString(@"Cannot open file \"%@\" for writing.", nil), targetName]
                                                                        style:LGAlertViewStyleActionSheet
                                                                 buttonTitles:nil
                                                            cancelButtonTitle:NSLocalizedString(@"Retry", nil)
                                                       destructiveButtonTitle:nil
                                                                     delegate:self];
            if (alertView && alertView.isShowing) {
                [alertView transitionToAlertView:handleAlertView completionHandler:nil];
            } else {
                [handleAlertView showAnimated];
            }
            return;
        }
        self.downloadFileHandle = downloadFileHandle;
    }
    { // Start Download Single File
        LGAlertView *downloadAlertView = [[LGAlertView alloc] initWithProgressViewAndTitle:NSLocalizedString(@"Download", nil) message:[NSString stringWithFormat:NSLocalizedString(@"Download \"%@\" from \"%@\".", nil), targetName, [sourceURL host]] style:LGAlertViewStyleActionSheet progress:0.0 progressLabelText:NSLocalizedString(@"Connecting...", nil) buttonTitles:nil cancelButtonTitle:NSLocalizedString(@"Cancel", nil) destructiveButtonTitle:nil delegate:self];
        if (alertView && alertView.isShowing) {
            [alertView transitionToAlertView:downloadAlertView completionHandler:nil];
        } else {
            [downloadAlertView showAnimated];
        }
        self.currentAlertView = downloadAlertView;
        if (busyOperationProgressFlag) {
            return;
        }
        busyOperationProgressFlag = YES;
        NSMutableURLRequest *downloadURLRequest = [NSMutableURLRequest requestWithURL:sourceURL cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:CGFLOAT_MAX];
        NSURLConnection *downloadURLConnection = [[NSURLConnection alloc] initWithRequest:downloadURLRequest delegate:self startImmediately:NO];
        [self performSelector:@selector(startDownloadImmediately:) withObject:downloadURLConnection afterDelay:1.f];
    }
}

- (void)startDownloadImmediately:(NSURLConnection *)connection {
    self.downloadURLConnection = connection;
    [connection scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    [connection start];
}

#pragma mark - NSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    busyOperationProgressFlag = NO;
    self.downloadURLConnection = nil;
    if (self.downloadFileHandle) {
        [self.downloadFileHandle closeFile];
        self.downloadFileHandle = nil;
    }
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    NSURL *sourceURL = self.sourceURL;
    NSString *sourceURLString = [sourceURL absoluteString];
    { // fail with error
        LGAlertView *downloadFailedAlertView = [[LGAlertView alloc] initWithTitle:NSLocalizedString(@"Download Failed", nil) message:[NSString stringWithFormat:NSLocalizedString(@"Cannot download from url \"%@\".\n%@", nil), sourceURLString, [error localizedDescription]] style:LGAlertViewStyleActionSheet buttonTitles:nil cancelButtonTitle:NSLocalizedString(@"Retry", nil) destructiveButtonTitle:nil delegate:self];
        if (self.currentAlertView && self.currentAlertView.isShowing) {
            [self.currentAlertView transitionToAlertView:downloadFailedAlertView completionHandler:nil];
        } else {
            [downloadFailedAlertView showAnimated];
        }
        self.currentAlertView = nil;
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    if (!busyOperationProgressFlag) {
        return;
    }
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    if (httpResponse.statusCode != 200) {
        // TODO: not supported http response
    }
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    {
        [self.downloadFileHandle seekToFileOffset:0];
        expectedFileSize = [response expectedContentLength];
        receivedFileSize = 0.0;
    }
    {
        if (self.currentAlertView && self.currentAlertView.isShowing) {
            [self.currentAlertView setProgress:0.0];
            [self.currentAlertView setProgressLabelText:@"0 %"];
        }
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)receivedData {
    if (!busyOperationProgressFlag) {
        return;
    }
    float progressive = (float)receivedFileSize / (float)expectedFileSize;
    {
        if (self.downloadFileHandle) {
            [self.downloadFileHandle writeData:receivedData];
        }
        receivedFileSize += receivedData.length;
    }
    {
        if (self.currentAlertView && self.currentAlertView.isShowing) {
            [self.currentAlertView setProgress:progressive];
            [self.currentAlertView setProgressLabelText:[NSString stringWithFormat:@"%.2f %%", (float)progressive * 100]];
        }
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    busyOperationProgressFlag = NO;
    self.downloadURLConnection = nil;
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    {
        if (self.downloadFileHandle) {
            [self.downloadFileHandle closeFile];
            self.downloadFileHandle = nil;
        }
    }
    {
        [self downloadFinished:self.currentAlertView];
    }
}

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse {
    return nil;
}

- (void)downloadFinished:(LGAlertView *)alertView {
    NSString *targetPath = self.targetPath;
    NSString *targetName = [targetPath lastPathComponent];
    {
        self.currentAlertView = nil;
        LGAlertView *finishAlertView = [[LGAlertView alloc] initWithTitle:NSLocalizedString(@"Download Finished", nil)
                                                                  message:[NSString stringWithFormat:NSLocalizedString(@"Successfully saved to \"%@\"", nil), targetName]
                                                                    style:LGAlertViewStyleActionSheet
                                                             buttonTitles:@[ NSLocalizedString(@"Done", nil) ]
                                                        cancelButtonTitle:nil
                                                   destructiveButtonTitle:nil
                                                                 delegate:self];
        if (alertView && alertView.isShowing) {
            [alertView transitionToAlertView:finishAlertView];
        } else {
            [finishAlertView showAnimated];
        }
    }
}

#pragma mark - Memory

- (void)dealloc {
#ifdef DEBUG
    NSLog(@"- [XXTEDownloadViewController dealloc]");
#endif
}

@end