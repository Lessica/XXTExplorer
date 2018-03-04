//
//  XXTExplorerViewController.m
//  XXTExplorer
//
//  Created by Zheng on 25/05/2017.
//  Copyright © 2017 Zheng. All rights reserved.
//

#import "XXTExplorerViewController.h"
#import "XXTENetworkDefines.h"

#import "XXTExplorerEntryParser.h"
#import "XXTExplorerEntryService.h"

#import "XXTExplorerHeaderView.h"
#import "XXTExplorerFooterView.h"
#import "XXTExplorerViewCell.h"
#import "XXTExplorerViewHomeCell.h"

#import <PromiseKit/PromiseKit.h>
#import <PromiseKit/NSURLConnection+PromiseKit.h>

#import "XXTExplorerEntryReader.h"
#import "XXTExplorerEntryOpenWithViewController.h"
#import "XXTENavigationController.h"

#import "XXTExplorerViewController+Notification.h"
#import "XXTExplorerViewController+XXTESwipeTableCellDelegate.h"
#import "XXTExplorerViewController+XXTExplorerToolbarDelegate.h"
#import "XXTExplorerViewController+XXTExplorerEntryOpenWithViewControllerDelegate.h"
#import "XXTExplorerViewController+LGAlertViewDelegate.h"
#import "XXTExplorerViewController+ArchiverOperation.h"
#import "XXTExplorerViewController+FileOperation.h"
#import "XXTExplorerViewController+PasteboardOperations.h"
#import "XXTExplorerViewController+SharedInstance.h"

#import "XXTEAppDefines.h"
#import "XXTENotificationCenterDefines.h"
#import "XXTEUserInterfaceDefines.h"
#import "XXTEPermissionDefines.h"

#import "XXTExplorerItemPreviewController.h"
#import "XXTExplorerNavigationController.h"

@interface XXTExplorerViewController ()
<UITableViewDelegate, UITableViewDataSource, UIGestureRecognizerDelegate,
UIViewControllerPreviewingDelegate, XXTExplorerFooterViewDelegate,
XXTExplorerItemPreviewDelegate, XXTExplorerItemPreviewActionDelegate,
XXTExplorerDirectoryPreviewDelegate, XXTExplorerDirectoryPreviewActionDelegate>
@property (nonatomic, strong) id<UIViewControllerPreviewing> previewingContext;

@end

@implementation XXTExplorerViewController {
    BOOL firstTimeLoaded;
}

- (instancetype)init {
    if (self = [super init]) {
        [self setupWithPath:nil];
    }
    return self;
}

- (instancetype)initWithEntryPath:(NSString *)path {
    if (self = [super init]) {
        [self setupWithPath:path];
    }
    return self;
}

- (void)setupWithPath:(NSString *)path {
    _homeEntryList = [[NSMutableArray alloc] init];
    _entryList = [[NSMutableArray alloc] init];
    {
        NSArray *explorerUserDefaults = XXTEBuiltInDefaultsObject(@"EXPLORER_USER_DEFAULTS");
        for (NSDictionary *explorerUserDefault in explorerUserDefaults) {
            NSString *defaultKey = explorerUserDefault[@"key"];
            if (!XXTEDefaultsObject(defaultKey, nil)) {
                id defaultValue = explorerUserDefault[@"default"];
                XXTEDefaultsSetObject(defaultKey, defaultValue);
            }
        }
    }
    {
        if (!path) {
            if (![self.class.explorerFileManager fileExistsAtPath:self.class.initialPath])
            {
                NSError *createDirectoryError = nil;
                BOOL createDirectoryResult = [self.class.explorerFileManager createDirectoryAtPath:self.class.initialPath withIntermediateDirectories:YES attributes:nil error:&createDirectoryError];
                if (!createDirectoryResult) {

                }
            }
            path = self.class.initialPath;
        }
        _entryPath = path;
    }
    {
        XXTExplorerEntry *entry = [[[self class] explorerEntryParser] entryOfPath:path withError:nil];
        _entry = entry;
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if (self.title.length == 0) {
        if (self == [self.navigationController.viewControllers firstObject] && !self.isPreviewed) {
#ifndef APPSTORE
            self.title = NSLocalizedString(@"My Scripts", nil);
#else
            self.title = NSLocalizedString(@"Files", nil);
#endif
        } else {
            NSString *entryPath = self.entryPath;
            if (entryPath) {
                NSString *entryName = [entryPath lastPathComponent];
                self.title = entryName;
            }
        }
    }

    if (!self.isPreviewed)
    {
        self.navigationItem.rightBarButtonItem = self.editButtonItem;
    }
    
    if (@available(iOS 11.0, *)) {
#ifdef APPSTORE
        self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAlways;
#else
        self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
#endif
    }

    _tableView = ({
        CGRect tableViewFrame = CGRectZero;
        if (@available(iOS 11.0, *)) {
            tableViewFrame = self.view.bounds;
        } else {
            tableViewFrame = CGRectMake(0.0, 44.0, CGRectGetWidth(self.view.bounds), CGRectGetHeight(self.view.bounds) - 44.0);
        }
        UITableView *tableView = [[UITableView alloc] initWithFrame:tableViewFrame style:UITableViewStylePlain];
        tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        tableView.delegate = self;
        tableView.dataSource = self;
        tableView.allowsSelection = YES;
        tableView.allowsMultipleSelection = NO;
        tableView.allowsSelectionDuringEditing = YES;
        tableView.allowsMultipleSelectionDuringEditing = YES;
        XXTE_START_IGNORE_PARTIAL
        if (@available(iOS 9.0, *)) {
            tableView.cellLayoutMarginsFollowReadableWidth = NO;
        }
        XXTE_END_IGNORE_PARTIAL
        [tableView registerNib:[UINib nibWithNibName:NSStringFromClass([XXTExplorerViewCell class]) bundle:[NSBundle mainBundle]] forCellReuseIdentifier:XXTExplorerViewCellReuseIdentifier];
        [tableView registerNib:[UINib nibWithNibName:NSStringFromClass([XXTExplorerViewHomeCell class]) bundle:[NSBundle mainBundle]] forCellReuseIdentifier:XXTExplorerViewHomeCellReuseIdentifier];
        UILongPressGestureRecognizer *cellLongPressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(entryCellDidLongPress:)];
        cellLongPressGesture.delegate = self;
        [tableView addGestureRecognizer:cellLongPressGesture];
        tableView;
    });
    [self.view addSubview:self.tableView];

    UITableViewController *tableViewController = [[UITableViewController alloc] init];
    tableViewController.tableView = self.tableView;
    _refreshControl = ({
        UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
        if (@available(iOS 11.0, *)) {
#ifdef APPSTORE
            refreshControl.tintColor = [UIColor whiteColor];
#endif
        }
        [refreshControl addTarget:self action:@selector(refreshControlTriggered:) forControlEvents:UIControlEventValueChanged];
        [tableViewController setRefreshControl:refreshControl];
        refreshControl;
    });
    [self.tableView.backgroundView insertSubview:self.refreshControl atIndex:0];

    [self configureToolbar];
    _footerView = ({
        XXTExplorerFooterView *entryFooterView = [[XXTExplorerFooterView alloc] initWithFrame:CGRectMake(0, 0, self.tableView.bounds.size.width, 48.f)];
        entryFooterView.delegate = self;
        entryFooterView;
    });
    [self.tableView setTableFooterView:self.footerView];

    [self loadEntryListData];
}

- (void)viewWillAppear:(BOOL)animated {
    [self restoreTheme];
    [super viewWillAppear:animated];
    [self registerNotifications];
    [self updateToolbarStatus];
    [self updateToolbarButton];
    if (firstTimeLoaded) {
        [self loadEntryListData];
        [self.tableView reloadData];
    } else if (!self.isPreviewed) {
        [self refreshControlTriggered:nil];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (!firstTimeLoaded && !self.isPreviewed) {
        firstTimeLoaded = YES;
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self removeNotifications];
    if ([self isEditing]) {
        [self setEditing:NO animated:YES];
    }
}

XXTE_START_IGNORE_PARTIAL
- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if ([self.traitCollection respondsToSelector:@selector(forceTouchCapability)]) {
        if (self.traitCollection.forceTouchCapability == UIForceTouchCapabilityAvailable) {
            // retain the context to avoid registering more than once
            if (!self.previewingContext) {
                self.previewingContext = [self registerForPreviewingWithDelegate:self sourceView:self.tableView];
            }
        } else {
            [self unregisterForPreviewingWithContext:self.previewingContext];
            self.previewingContext = nil;
        }
    }
}
XXTE_END_IGNORE_PARTIAL

- (void)restoreTheme {
    UIColor *backgroundColor = XXTE_COLOR;
    UIColor *foregroundColor = [UIColor whiteColor];
    UINavigationBar *navigationBar = self.navigationController.navigationBar;
    [navigationBar setTitleTextAttributes:@{NSForegroundColorAttributeName : foregroundColor}];
    navigationBar.tintColor = foregroundColor;
    navigationBar.barTintColor = backgroundColor;
    [self setNeedsStatusBarAppearanceUpdate];
}

#pragma mark - Item Picker Inherit

- (BOOL)showsHomeSeries {
    return YES;
}

- (BOOL)shouldDisplayEntry:(NSDictionary *)entryDetail {
    return YES;
}

- (XXTExplorerViewEntryListSortField)explorerSortField {
    if (_historyMode) {
        return _internalSortField;
    }
    return XXTEDefaultsEnum(XXTExplorerViewEntryListSortFieldKey, XXTExplorerViewEntryListSortFieldModificationDate);
}

- (XXTExplorerViewEntryListSortOrder)explorerSortOrder {
    if (_historyMode) {
        return _internalSortOrder;
    }
    return XXTEDefaultsEnum(XXTExplorerViewEntryListSortOrderKey, XXTExplorerViewEntryListSortOrderDesc);
}

- (void)setExplorerSortField:(XXTExplorerViewEntryListSortField)explorerSortField {
    if (self.historyMode) {
        _internalSortField = explorerSortField;
        return;
    }
    XXTEDefaultsSetBasic(XXTExplorerViewEntryListSortFieldKey, explorerSortField);
}

- (void)setExplorerSortOrder:(XXTExplorerViewEntryListSortOrder)explorerSortOrder {
    if (self.historyMode) {
        _internalSortOrder = explorerSortOrder;
        return;
    }
    XXTEDefaultsSetBasic(XXTExplorerViewEntryListSortOrderKey, explorerSortOrder);
}

#pragma mark - NSFileManager

- (BOOL)loadEntryListDataWithError:(NSError **)error {
    
    {
#ifdef DEBUG
        BOOL homeEnabled = XXTEDefaultsBool(XXTExplorerViewEntryHomeEnabledKey, YES);
#else
        BOOL homeEnabled = XXTEDefaultsBool(XXTExplorerViewEntryHomeEnabledKey, NO);
#endif
        [self.homeEntryList removeAllObjects];
        if ([self showsHomeSeries] && homeEnabled &&
            (self == [self.navigationController.viewControllers firstObject]) && !self.isPreviewed) {
            NSArray <NSDictionary *> *entrySeries = XXTEBuiltInDefaultsObject(XXTExplorerViewBuiltHomeSeries);
            if (entrySeries) {
                [self.homeEntryList addObjectsFromArray:entrySeries];
            }
        }
    }

    NSArray <XXTExplorerEntry *> *newEntryList = ({
        NSString *entryPath = self.entryPath;
        promiseFixPermission(entryPath, NO);
        
        BOOL hidesDot = XXTEDefaultsBool(XXTExplorerViewEntryListHideDotItemKey, YES);
        NSError *localError = nil;
        NSArray <NSString *> *entrySubdirectoryPathList = [self.class.explorerFileManager contentsOfDirectoryAtPath:entryPath error:&localError];
        if (localError && error) {
            *error = [NSError errorWithDomain:kXXTErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey: localError.localizedDescription}];
        }
        
        NSMutableArray <XXTExplorerEntry *> *entryDirectoryAttributesList = [[NSMutableArray alloc] init];
        NSMutableArray <XXTExplorerEntry *> *entryBundleAttributesList = [[NSMutableArray alloc] init];
        NSMutableArray <XXTExplorerEntry *> *entryOtherAttributesList = [[NSMutableArray alloc] init];
        
        for (NSString *entrySubdirectoryName in entrySubdirectoryPathList) {
            @autoreleasepool {
                if (hidesDot && [entrySubdirectoryName hasPrefix:@"."]) {
                    continue;
                }
                NSString *entrySubdirectoryPath = [entryPath stringByAppendingPathComponent:entrySubdirectoryName];
                XXTExplorerEntry *entryDetail = [self.class.explorerEntryParser entryOfPath:entrySubdirectoryPath withError:&localError];
                if (localError && error) {
                    continue;
                }
                if ([self shouldDisplayEntry:entryDetail] == NO) {
                    continue;
                }
                if (entryDetail.isMaskedDirectory) {
                    [entryDirectoryAttributesList addObject:entryDetail];
                } else if (entryDetail.isBundle) {
                    [entryBundleAttributesList addObject:entryDetail];
                } else {
                    [entryOtherAttributesList addObject:entryDetail];
                }
            }
        }
        
        XXTExplorerViewEntryListSortField sortField = self.explorerSortField;
        XXTExplorerViewEntryListSortOrder sortOrder = self.explorerSortOrder;
        
        NSString *sortFieldString = [XXTExplorerEntry sortField2AttributeName:sortField];
        NSComparator comparator = ^NSComparisonResult(NSDictionary *_Nonnull obj1, NSDictionary *_Nonnull obj2)
        {
            if (sortOrder == XXTExplorerViewEntryListSortOrderAsc) {
                return [[obj1 valueForKey:sortFieldString] compare:[obj2 valueForKey:sortFieldString]];
            } else {
                return [[obj2 valueForKey:sortFieldString] compare:[obj1 valueForKey:sortFieldString]];
            }
        };
        
        [entryDirectoryAttributesList sortUsingComparator:comparator];
        [entryBundleAttributesList sortUsingComparator:comparator];
        [entryOtherAttributesList sortUsingComparator:comparator];

        NSMutableArray <XXTExplorerEntry *> *entryDetailList = [[NSMutableArray alloc] initWithCapacity:entrySubdirectoryPathList.count];
        
        [entryDetailList addObjectsFromArray:entryDirectoryAttributesList];
        [entryDetailList addObjectsFromArray:entryBundleAttributesList];
        [entryDetailList addObjectsFromArray:entryOtherAttributesList];
        
        entryDetailList;
    });
    [self.entryList removeAllObjects];
    [self.entryList addObjectsFromArray:newEntryList];
    [self reloadFooterView];
    
    if (error && *error) {
        return NO;
    }
    return YES;
}

- (void)loadEntryListData {
    NSError *entryLoadError = nil;
    [self loadEntryListDataWithError:&entryLoadError];
    if (entryLoadError) {
        toastMessage(self, [entryLoadError localizedDescription]);
    }
}

- (void)reloadFooterView {
    NSUInteger itemCount = self.entryList.count;
    if ([self.class.initialPath isEqualToString:self.entryPath] && itemCount == 0) {
        [self.footerView setEmptyMode:YES];
    } else {
        [self.footerView setEmptyMode:NO];
        [self updateFooterView];
    }
}

- (void)updateFooterView {
    NSUInteger itemCount = self.entryList.count;
    NSString *itemCountString = nil;
    if (itemCount == 0) {
        itemCountString = NSLocalizedString(@"No item", nil);
    } else if (itemCount == 1) {
        itemCountString = NSLocalizedString(@"1 item", nil);
    } else {
        itemCountString = [NSString stringWithFormat:NSLocalizedString(@"%lu items", nil), (unsigned long) itemCount];
    }
    NSString *usageString = nil;
    NSError *usageError = nil;
    NSDictionary *fileSystemAttributes = [self.class.explorerFileManager attributesOfFileSystemForPath:[XXTEAppDelegate sharedRootPath] error:&usageError];
    if (!usageError) {
        NSNumber *deviceFreeSpace = fileSystemAttributes[NSFileSystemFreeSize];
        if (deviceFreeSpace != nil) {
            usageString = [NSByteCountFormatter stringFromByteCount:[deviceFreeSpace unsignedLongLongValue] countStyle:NSByteCountFormatterCountStyleFile];
        }
    }
    NSString *finalFooterString = [NSString stringWithFormat:NSLocalizedString(@"%@, %@ free", nil), itemCountString, usageString];
    [self.footerView.footerLabel setText:finalFooterString];
}

- (void)reloadEntryListView {
    [self loadEntryListData];
    [self.tableView reloadData];
}

- (void)refreshControlTriggered:(UIRefreshControl *)refreshControl {
#ifndef APPSTORE
    
    if ([self.class isFetchingSelectedScript] == NO) {
        [self.class setFetchingSelectedScript:YES];
        [NSURLConnection POST:uAppDaemonCommandUrl(@"get_selected_script_file") JSON:@{}]
        .then(convertJsonString)
        .then(^(NSDictionary *jsonDictionary) {
            if ([jsonDictionary[@"code"] isEqualToNumber:@(0)]) {
                NSString *selectedScriptName = jsonDictionary[@"data"][@"filename"];
                if (selectedScriptName) {
                    NSString *selectedScriptPath = nil;
                    if ([selectedScriptName isAbsolutePath]) {
                        selectedScriptPath = selectedScriptName;
                    } else {
                        selectedScriptPath = [self.class.initialPath stringByAppendingPathComponent:selectedScriptName];
                    }
                    XXTEDefaultsSetObject(XXTExplorerViewEntrySelectedScriptPathKey, selectedScriptPath);
                }
            }
        })
        .catch(^(NSError *serverError) {
            toastDaemonError(self, serverError);
        })
        .finally(^() {
            if (refreshControl && [refreshControl isRefreshing]) {
                [self loadEntryListData];
                [self.tableView reloadData];
                [refreshControl endRefreshing];
            } else {
                UITableView *tableView = self.tableView;
                for (NSIndexPath *indexPath in [tableView indexPathsForVisibleRows]) {
                    [self reconfigureCellAtIndexPath:indexPath];
                }
            }
            [self.class setFetchingSelectedScript:NO];
        });
    }
    
#else
    
    if (refreshControl && [refreshControl isRefreshing]) {
        [self loadEntryListData];
        [self.tableView reloadData];
        [refreshControl endRefreshing];
    } else {
        UITableView *tableView = self.tableView;
        for (NSIndexPath *indexPath in [tableView indexPathsForVisibleRows])
        {
            [self reconfigureCellAtIndexPath:indexPath];
        }
    }
    [self.class setFetchingSelectedScript:NO];
    
#endif
}

#pragma mark - UITableViewDelegate & UITableViewDataSource

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView == self.tableView) {
        if (XXTExplorerViewSectionIndexList == indexPath.section) {
            return YES;
        }
    }
    return NO;
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    if (tableView == self.tableView) {
        if (XXTExplorerViewSectionIndexList == indexPath.section) {
            return indexPath;
        } else if (XXTExplorerViewSectionIndexHome == indexPath.section) {
            return indexPath;
        }
    }
    return nil;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewCellEditingStyleNone;
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView == self.tableView) {
        if (XXTExplorerViewSectionIndexList == indexPath.section) {
            if ([tableView isEditing]) {
                [self updateToolbarStatus];
            }
        }
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView == self.tableView) {
        if (XXTExplorerViewSectionIndexList == indexPath.section) {
            if ([tableView isEditing]) {
                [self updateToolbarStatus];
            } else {
                XXTExplorerEntry *entryDetail = self.entryList[indexPath.row];
                NSString *entryPath = entryDetail.entryPath;
                if (entryDetail.isMaskedDirectory)
                {
                    [tableView deselectRowAtIndexPath:indexPath animated:YES];
                    [self performDictionaryActionForEntry:entryDetail];
                }
                else if (
                         entryDetail.isMaskedRegular ||
                         entryDetail.isBundle)
                {
                    if ([self.class.explorerFileManager isReadableFileAtPath:entryPath]) {
                        if ([self.class.explorerEntryService hasViewerForEntry:entryDetail]) {
                            [tableView deselectRowAtIndexPath:indexPath animated:YES];
                            if (!XXTE_COLLAPSED)
                            {
                                
                            } // TODO: remain selected state when being viewed in collapsed detail view controller
                            [self performViewerActionForEntry:entryDetail];
                        } else {
                            [tableView deselectRowAtIndexPath:indexPath animated:YES];
                            XXTExplorerEntryOpenWithViewController *openWithController = [[XXTExplorerEntryOpenWithViewController alloc] initWithEntry:entryDetail];
                            openWithController.delegate = self;
                            XXTENavigationController *navController = [[XXTENavigationController alloc] initWithRootViewController:openWithController];
                            XXTE_START_IGNORE_PARTIAL
                            if (@available(iOS 8.0, *)) {
                                navController.modalPresentationStyle = UIModalPresentationPopover;
                                UIPopoverPresentationController *popoverController = navController.popoverPresentationController;
                                popoverController.sourceView = tableView;
                                popoverController.sourceRect = [tableView rectForRowAtIndexPath:indexPath];
                                popoverController.backgroundColor = [UIColor whiteColor];
                            }
                            XXTE_END_IGNORE_PARTIAL
                            [self.navigationController presentViewController:navController animated:YES completion:nil];
                        }
                    } else {
                        // TODO: not readable, unlock?
                        [tableView deselectRowAtIndexPath:indexPath animated:YES];
                        toastMessage(self, NSLocalizedString(@"Access denied.", nil));
                    }
                } else if (entryDetail.isBrokenSymlink)
                { // broken symlink
                    [tableView deselectRowAtIndexPath:indexPath animated:YES];
                    toastMessage(self, ([NSString stringWithFormat:NSLocalizedString(@"The alias \"%@\" can't be opened because the original item can't be found.", nil), entryDetail.localizedDisplayName]));
                }
                else
                { // not supported
                    [tableView deselectRowAtIndexPath:indexPath animated:YES];
                    toastMessage(self, NSLocalizedString(@"Only regular file, directory and symbolic link are supported.", nil));
                }
            }
        } else if (XXTExplorerViewSectionIndexHome == indexPath.section) {
            if ([tableView isEditing]) {
                [tableView deselectRowAtIndexPath:indexPath animated:YES];
            } else {
                NSDictionary *entryDetail = self.homeEntryList[indexPath.row];
                [tableView deselectRowAtIndexPath:indexPath animated:YES];
                [self performHomeActionForEntry:entryDetail];
            }
        }
    }
}

// Home Action

- (XXTExplorerViewController *)prepareForHomeActionForEntry:(NSDictionary *)entryDetail error:(NSError **)error {
    NSString *directoryRelativePath = entryDetail[@"path"];
    NSString *directoryPath = nil;
    if ([directoryRelativePath isAbsolutePath]) {
        directoryPath = directoryRelativePath;
    } else {
        directoryPath = [[XXTEAppDelegate sharedRootPath] stringByAppendingPathComponent:directoryRelativePath];
    }
    NSError *accessError = nil;
    [self.class.explorerFileManager contentsOfDirectoryAtPath:directoryPath error:&accessError];
    if (accessError) {
        if (error) *error = accessError;
    } else {
        XXTExplorerViewController *explorerViewController = [[XXTExplorerViewController alloc] initWithEntryPath:directoryPath];
        return explorerViewController;
    }
    return nil;
}

- (void)performHomeActionForEntry:(NSDictionary *)entryDetail {
    NSError *prepareError = nil;
    UIViewController *controller = [self prepareForHomeActionForEntry:entryDetail error:&prepareError];
    if (controller) {
        [self.navigationController pushViewController:controller animated:YES];
    } else if (prepareError) {
        toastMessage(self, [prepareError localizedDescription]);
    }
}

// Item Action

- (XXTExplorerItemPreviewController *)prepareForItemPreviewActionForEntry:(XXTExplorerEntry *)entryDetail {
    XXTExplorerItemPreviewController *controller = [[XXTExplorerItemPreviewController alloc] initWithNibName:NSStringFromClass([XXTExplorerItemPreviewController class]) bundle:nil];
    controller.entryPath = entryDetail.entryPath;
    return controller;
}

// Directory Action

- (XXTExplorerViewController *)prepareForDictionaryActionForEntry:(XXTExplorerEntry *)entryDetail error:(NSError **)error {
    NSString *entryPath = entryDetail.entryPath;
    if (entryDetail.isMaskedDirectory)
    { // Directory or Symbolic Link Directory
        // We'd better try to access it before we enter it.
        NSError *accessError = nil;
        [self.class.explorerFileManager contentsOfDirectoryAtPath:entryPath error:&accessError];
        if (accessError) {
            if (error) *error = accessError;
        } else {
            XXTExplorerViewController *explorerViewController = [[XXTExplorerViewController alloc] initWithEntryPath:entryPath];
            return explorerViewController;
        }
    }
    return nil;
}

- (void)performDictionaryActionForEntry:(XXTExplorerEntry *)entryDetail {
    NSError *prepareError = nil;
    UIViewController *controller = [self prepareForDictionaryActionForEntry:entryDetail error:&prepareError];
    if (controller) {
        [self.navigationController pushViewController:controller animated:YES];
    } else if (prepareError) {
        toastMessage(self, [prepareError localizedDescription]);
    }
}

// History Action

- (void)performHistoryActionForEntry:(XXTExplorerEntry *)entryDetail {
    NSString *entryPath = entryDetail.entryPath;
    if (entryDetail.isMaskedDirectory)
    {
        NSError *accessError = nil;
        [self.class.explorerFileManager contentsOfDirectoryAtPath:entryPath error:&accessError];
        if (accessError) {
            toastMessage(self, [accessError localizedDescription]);
        } else {
            XXTExplorerViewController *explorerViewController = [[XXTExplorerViewController alloc] initWithEntryPath:entryPath];
            explorerViewController.historyMode = YES;
            explorerViewController.internalSortField = XXTExplorerViewEntryListSortFieldModificationDate;
            explorerViewController.internalSortOrder = XXTExplorerViewEntryListSortOrderDesc;
            [self.navigationController pushViewController:explorerViewController animated:YES];
        }
    }
}

// Viewer Action

- (void)performViewerActionForEntry:(XXTExplorerEntry *)entryDetail {
    [self performViewerActionForEntry:entryDetail animated:YES];
}

- (void)performViewerActionForEntry:(XXTExplorerEntry *)entryDetail animated:(BOOL)animated {
    UIViewController <XXTEViewer> *viewer = [self.class.explorerEntryService viewerForEntry:entryDetail];
    [self tableView:self.tableView showDetailController:viewer animated:animated];
}

// Accessory Action

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    if (tableView == self.tableView) {
        if (![tableView isEditing]) {
            if (XXTExplorerViewSectionIndexList == indexPath.section) {
                XXTESwipeTableCell *cell = [tableView cellForRowAtIndexPath:indexPath];
                [cell showSwipe:XXTESwipeDirectionLeftToRight animated:YES];
            }
        }
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView == self.tableView) {
        if (XXTExplorerViewSectionIndexList == indexPath.section) {
            return XXTExplorerViewCellHeight;
        } else if (XXTExplorerViewSectionIndexHome == indexPath.section) {
            return XXTExplorerViewHomeCellHeight;
        }
    }
    return 0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (tableView == self.tableView) {
        if (XXTExplorerViewSectionIndexList == section) {
            return 24.f;
        } // Notice: assume that there will not be any headers for Home section
    }
    return 0;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if (tableView == self.tableView) {
        if (XXTExplorerViewSectionIndexList == section) {
            XXTExplorerHeaderView *entryHeaderView = [tableView dequeueReusableHeaderFooterViewWithIdentifier:XXTExplorerEntryHeaderViewReuseIdentifier];
            if (!entryHeaderView)
            {
                entryHeaderView = [[XXTExplorerHeaderView alloc] initWithReuseIdentifier:XXTExplorerEntryHeaderViewReuseIdentifier];
            }
            NSString *rootPath = [XXTEAppDelegate sharedRootPath];
            NSRange rootRange = [self.entryPath rangeOfString:rootPath];
            if (rootRange.location == 0) {
                NSString *tiledPath = [self.entryPath stringByReplacingCharactersInRange:rootRange withString:@"~"];
                [entryHeaderView.headerLabel setText:tiledPath];
            } else {
                [entryHeaderView.headerLabel setText:self.entryPath];
            }
            entryHeaderView.userInteractionEnabled = YES;
            UITapGestureRecognizer *addressTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(addressLabelTapped:)];
            addressTapGestureRecognizer.delegate = self;
            [entryHeaderView addGestureRecognizer:addressTapGestureRecognizer];
            return entryHeaderView;
        } // Notice: assume that there will not be any headers for Home section
    }
    return nil;
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (tableView == self.tableView) {
        return XXTExplorerViewSectionIndexMax;
    }
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (tableView == self.tableView) {
        if (XXTExplorerViewSectionIndexHome == section) {
            return self.homeEntryList.count;
        } else if (XXTExplorerViewSectionIndexList == section) {
            return self.entryList.count;
        }
    }
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView == self.tableView) {
        if (XXTExplorerViewSectionIndexList == indexPath.section) {
            XXTExplorerEntry *entryDetail = self.entryList[indexPath.row];
            XXTExplorerViewCell *entryCell = [tableView dequeueReusableCellWithIdentifier:XXTExplorerViewCellReuseIdentifier];
            if (!entryCell) {
                entryCell = [[XXTExplorerViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:XXTExplorerViewCellReuseIdentifier];
            }
            [self configureCell:entryCell withEntry:entryDetail];
            return entryCell;
        } else if (XXTExplorerViewSectionIndexHome == indexPath.section) {
            NSDictionary *entryDetail = self.homeEntryList[indexPath.row];
            XXTExplorerViewHomeCell *entryCell = [tableView dequeueReusableCellWithIdentifier:XXTExplorerViewHomeCellReuseIdentifier];
            if (!entryCell) {
                entryCell = [[XXTExplorerViewHomeCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:XXTExplorerViewHomeCellReuseIdentifier];
            }
            [self configureHomeCell:entryCell withEntry:entryDetail];
            return entryCell;
        }
    }
    return [UITableViewCell new];
}

#pragma mark - UILongPressGestureRecognizer

- (void)entryCellDidLongPress:(UILongPressGestureRecognizer *)recognizer {
    if (![self isEditing] && recognizer.state == UIGestureRecognizerStateBegan) {
        CGPoint location = [recognizer locationInView:self.tableView];
        NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:location];
        if (!indexPath) return;
        if (indexPath.section == XXTExplorerViewSectionIndexHome) {
            XXTExplorerViewHomeCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
            [cell becomeFirstResponder];
            UIMenuController *menuController = [UIMenuController sharedMenuController];
            UIMenuItem *hideItem = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"Hide", nil) action:@selector(hideHomeItemTapped:)];
            [menuController setMenuItems:[NSArray arrayWithObjects:hideItem, nil]];
            [menuController setTargetRect:[self.tableView rectForRowAtIndexPath:indexPath] inView:self.tableView];
            [menuController setMenuVisible:YES animated:YES];
        } else {
            [self setEditing:YES animated:YES];
            if (self.tableView.delegate) {
                [self.tableView.delegate tableView:self.tableView willSelectRowAtIndexPath:indexPath];
                [self.tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
                [self.tableView.delegate tableView:self.tableView didSelectRowAtIndexPath:indexPath];
            }
        }
    }
}

#pragma mark - Cell Configuration

- (void)reconfigureCellAtIndexPath:(NSIndexPath *)indexPath {
    if (!indexPath) return;
    if (indexPath.section == XXTExplorerViewSectionIndexList) {
        if (indexPath.row < self.entryList.count) {
            XXTExplorerViewCell *entryCell = [self.tableView cellForRowAtIndexPath:indexPath];
            XXTExplorerEntry *entryDetail = self.entryList[indexPath.row];
            [self configureCell:entryCell withEntry:entryDetail];
        }
    }
    else if (indexPath.section == XXTExplorerViewSectionIndexHome) {
        if (indexPath.row < self.homeEntryList.count) {
            XXTExplorerViewHomeCell *entryCell = [self.tableView cellForRowAtIndexPath:indexPath];
            NSDictionary *entryDetail = self.homeEntryList[indexPath.row];
            [self configureHomeCell:entryCell withEntry:entryDetail];
        }
    }
}

- (void)configureCell:(XXTExplorerViewCell *)entryCell withEntry:(XXTExplorerEntry *)entryDetail {
    entryCell.delegate = self;
    entryCell.entryTitleLabel.textColor = [UIColor blackColor];
    entryCell.entrySubtitleLabel.textColor = [UIColor darkGrayColor];
    if (entryDetail.isBrokenSymlink) {
        // broken symlink
        entryCell.entryTitleLabel.textColor = XXTE_COLOR_DANGER;
        entryCell.entrySubtitleLabel.textColor = XXTE_COLOR_DANGER;
        entryCell.flagType = XXTExplorerViewCellFlagTypeBroken;
    } else if (entryDetail.isSymlink) {
        // symlink
        entryCell.entryTitleLabel.textColor = XXTE_COLOR;
        entryCell.entrySubtitleLabel.textColor = XXTE_COLOR;
        entryCell.flagType = XXTExplorerViewCellFlagTypeNone;
    } else {
        entryCell.entryTitleLabel.textColor = [UIColor blackColor];
        entryCell.entrySubtitleLabel.textColor = [UIColor darkGrayColor];
        entryCell.flagType = XXTExplorerViewCellFlagTypeNone;
    }
    if (!entryDetail.isMaskedDirectory &&
        [self.class.selectedScriptPath isEqualToString:entryDetail.entryPath]) {
        // selected script itself
        entryCell.entryTitleLabel.textColor = XXTE_COLOR_SUCCESS;
        entryCell.entrySubtitleLabel.textColor = XXTE_COLOR_SUCCESS;
        entryCell.flagType = XXTExplorerViewCellFlagTypeSelected;
    } else if ((
                entryDetail.isMaskedDirectory ||
                entryDetail.isBundle
                ) &&
               [self.class.selectedScriptPath hasPrefix:entryDetail.entryPath]) {
        // selected script in directory / bundle
        entryCell.entryTitleLabel.textColor = XXTE_COLOR_SUCCESS;
        entryCell.entrySubtitleLabel.textColor = XXTE_COLOR_SUCCESS;
        entryCell.flagType = XXTExplorerViewCellFlagTypeSelectedInside;
    }
    entryCell.entryTitleLabel.text = entryDetail.localizedDisplayName;
    entryCell.entrySubtitleLabel.text = entryDetail.localizedDescription;
    entryCell.entryIconImageView.image = entryDetail.localizedDisplayIconImage;
    if (entryCell.accessoryType != UITableViewCellAccessoryDetailButton)
    {
        entryCell.accessoryType = UITableViewCellAccessoryDetailButton;
    }
}

- (void)configureHomeCell:(XXTExplorerViewHomeCell *)entryCell withEntry:(NSDictionary *)entryDetail {
    entryCell.entryIconImageView.image = [UIImage imageNamed:entryDetail[@"icon"]];
    entryCell.entryTitleLabel.text = entryDetail[@"title"];
    entryCell.entrySubtitleLabel.text = entryDetail[@"subtitle"];
}

#pragma mark - View Attachments

- (void)addressLabelTapped:(UITapGestureRecognizer *)recognizer {
    if (![self isEditing] && recognizer.state == UIGestureRecognizerStateEnded) {
//        NSString *detailText = ((XXTExplorerHeaderView *) recognizer.view).headerLabel.text;
        NSString *detailText = self.entryPath;
        if (detailText && detailText.length > 0) {
            UIViewController *blockVC = blockInteractionsWithDelay(self, YES, 2.0);
            [PMKPromise new:^(PMKFulfiller fulfill, PMKRejecter reject) {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                    [[UIPasteboard generalPasteboard] setString:detailText];
                    fulfill(nil);
                });
            }].finally(^() {
                toastMessage(self, NSLocalizedString(@"Current path has been copied to the pasteboard.", nil));
                blockInteractions(blockVC, NO);
            });
        }
    }
}

- (void)hideHomeItemTapped:(id)sender {
    NSMutableArray <NSIndexPath *> *homeIndexes = [[NSMutableArray alloc] init];
    for (NSUInteger idx = 0; idx < self.homeEntryList.count; idx++) {
        [homeIndexes addObject:[NSIndexPath indexPathForRow:idx inSection:XXTExplorerViewSectionIndexHome]];
    }
    XXTEDefaultsSetBasic(XXTExplorerViewEntryHomeEnabledKey, NO);
    [self loadEntryListData];
    [self.tableView beginUpdates];
    [self.tableView deleteRowsAtIndexPaths:[homeIndexes copy] withRowAnimation:UITableViewRowAnimationAutomatic];
    [self.tableView reloadData];
    [self.tableView endUpdates];
    toastMessage(self, NSLocalizedString(@"\"Home Entries\" has been disabled, you can make it display again in \"More > User Defaults\".", nil));
}

#pragma mark - Gesture Attachments

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)recognizer {
    CGPoint location = [recognizer locationInView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:location];
    if (indexPath.section == XXTExplorerViewSectionIndexList) {
        XXTESwipeTableCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
        return (cell.swipeState == XXTESwipeStateNone);
    }
    return (!self.isEditing);
}

#pragma mark - UIViewController (UIViewControllerEditing)

- (BOOL)isEditing {
    return [super isEditing];
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    [super setEditing:editing animated:animated];
    [self.tableView setEditing:editing animated:animated];
    if (editing) {
        [self.toolbar updateStatus:XXTExplorerToolbarStatusEditing];
    } else {
        [self.toolbar updateStatus:XXTExplorerToolbarStatusDefault];
    }
    [self updateToolbarStatus];
    [self reloadFooterView];
}

#pragma mark - Preview

- (BOOL)isPreviewed {
    return self.previewDelegate != nil;
}

#pragma mark - Scroll to Rect

- (NSIndexPath *)indexPathForEntryAtPath:(NSString *)entryPath {
    for (NSUInteger idx = 0; idx < self.entryList.count; idx++) {
        XXTExplorerEntry *entryDetail = self.entryList[idx];
        if ([entryDetail.entryPath isEqualToString:entryPath]) {
            return [NSIndexPath indexPathForRow:idx inSection:XXTExplorerViewSectionIndexList];
        }
    }
    return nil;
}

#pragma mark - XXTExplorerFooterViewDelegate

- (void)footerView:(XXTExplorerFooterView *)view emptyButtonTapped:(UIButton *)sender {
    if (view == self.footerView) {
        NSDictionary *userInfo =
        @{XXTENotificationShortcutInterface: @"cloud",
          XXTENotificationShortcutUserData: @{  }};
        [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:XXTENotificationShortcut object:nil userInfo:userInfo]];
    }
}

#pragma mark - UIViewControllerPreviewingDelegate

XXTE_START_IGNORE_PARTIAL
- (void)previewingContext:(id<UIViewControllerPreviewing>)previewingContext commitViewController:(UIViewController *)viewControllerToCommit {
    UIViewController *presentController = nil;
    if ([viewControllerToCommit isKindOfClass:[self class]])
    {
        presentController = viewControllerToCommit;
    }
    else if ([viewControllerToCommit isKindOfClass:[UINavigationController class]])
    {
        UINavigationController *navController = (UINavigationController *)viewControllerToCommit;
        UIViewController *rootController = [navController.viewControllers firstObject];
        if ([rootController isKindOfClass:[self class]]) {
            XXTExplorerViewController *nextController = (XXTExplorerViewController *)rootController;
            XXTExplorerViewController *newNextController = [[XXTExplorerViewController alloc] initWithEntryPath:nextController.entryPath];
            presentController = newNextController;
        }
    }
    if ([presentController isKindOfClass:[UIViewController class]])
    {
        [self.navigationController pushViewController:presentController animated:NO];
    }
}
XXTE_END_IGNORE_PARTIAL

XXTE_START_IGNORE_PARTIAL
- (UIViewController *)previewingContext:(id<UIViewControllerPreviewing>)previewingContext viewControllerForLocation:(CGPoint)location {
    UITableView *tableView = self.tableView;
    if ([tableView isEditing]) {
        return nil;
    }
    NSIndexPath *indexPath = [tableView indexPathForRowAtPoint:location];
    if (!indexPath) return nil;
    if (@available(iOS 9.0, *)) {
        previewingContext.sourceRect = [tableView rectForRowAtIndexPath:indexPath];
    }
    UITableViewCell *previewCell = [tableView cellForRowAtIndexPath:indexPath];
    NSError *prepareError = nil;
    if (XXTExplorerViewSectionIndexList == indexPath.section) {
        XXTExplorerEntry *entryDetail = self.entryList[indexPath.row];
        XXTExplorerViewController *controller =
        [self prepareForDictionaryActionForEntry:entryDetail error:&prepareError];
        if (controller)
        { // Directory Preview
            controller.previewDelegate = self;
            controller.previewActionDelegate = self;
            controller.previewActionSender = previewCell;
            XXTExplorerNavigationController *navController =
            [[XXTExplorerNavigationController alloc] initWithRootViewController:controller];
            return navController;
        }
        else
        { // Item Preview
            XXTExplorerItemPreviewController *itemController =
            [self prepareForItemPreviewActionForEntry:entryDetail];
            itemController.previewDelegate = self;
            itemController.previewActionDelegate = self;
            itemController.previewActionSender = previewCell;
            return itemController;
        }
    } else if (XXTExplorerViewSectionIndexHome == indexPath.section)
    { // Home Preview
        NSDictionary *entryDetail = self.homeEntryList[indexPath.row];
        XXTExplorerViewController *controller =
        [self prepareForHomeActionForEntry:entryDetail error:&prepareError];
        controller.previewDelegate = self;
        // controller.previewActionDelegate = self;
        // controller.previewActionSender = previewCell;
        // !!! You cannot perform any action in home preview !!!
        XXTExplorerNavigationController *navController =
        [[XXTExplorerNavigationController alloc] initWithRootViewController:controller];
        return navController;
    }
    return nil;
}
XXTE_END_IGNORE_PARTIAL

#pragma mark - XXTExplorerItemPreviewActionDelegate

XXTE_START_IGNORE_PARTIAL
- (NSArray <UIPreviewAction *> *)itemPreviewController:(XXTExplorerItemPreviewController *)controller previewActionsForEntry:(XXTExplorerEntry *)entry
{
    return [self previewActionsForEntry:entry forEntryCell:controller.previewActionSender];
}
XXTE_END_IGNORE_PARTIAL

XXTE_START_IGNORE_PARTIAL
- (NSArray <id <UIPreviewActionItem>> *)previewActionItems {
    if ([_previewActionDelegate respondsToSelector:@selector(itemPreviewController:previewActionsForEntry:)]) {
        return [_previewActionDelegate directoryPreviewController:self previewActionsForEntry:self.entry];
    }
    return @[];
}
XXTE_END_IGNORE_PARTIAL

#pragma mark - XXTExplorerDirectoryPreviewActionDelegate

XXTE_START_IGNORE_PARTIAL
- (NSArray <UIPreviewAction *> *)directoryPreviewController:(XXTExplorerViewController *)controller previewActionsForEntry:(XXTExplorerEntry *)entry
{
    return [self previewActionsForEntry:entry forEntryCell:controller.previewActionSender];
}
XXTE_END_IGNORE_PARTIAL

#pragma mark - Memory

- (void)dealloc {
#ifdef DEBUG
    NSLog(@"- [XXTExplorerViewController dealloc]");
#endif
}

@end
