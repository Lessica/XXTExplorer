//
// Created by Zheng on 02/05/2017.
// Copyright (c) 2017 Zheng. All rights reserved.
//

#import "XXTMultipleApplicationPicker.h"
#import "XXTApplicationCell.h"
#import "XXTPickerInsetsLabel.h"
#import "XXTExplorerFooterView.h"

#import <objc/runtime.h>
#import "LSApplicationProxy.h"
#import "LSApplicationWorkspace.h"

#import "XXTPickerDefine.h"
#import "XXTPickerFactory.h"
#import "XXTPickerSnippetTask.h"


enum {
    kXXTApplicationPickerCellSectionSelected = 0,
    kXXTApplicationPickerCellSectionUnselected
};

enum {
    kXXTApplicationSearchTypeName = 0,
    kXXTApplicationSearchTypeBundleID
};

#if !(TARGET_OS_SIMULATOR)
CFArrayRef SBSCopyApplicationDisplayIdentifiers(bool onlyActive, bool debuggable);
CFStringRef SBSCopyLocalizedApplicationNameForDisplayIdentifier(CFStringRef displayIdentifier);
CFDataRef SBSCopyIconImagePNGDataForDisplayIdentifier(CFStringRef displayIdentifier);
#else
CFArrayRef SBSCopyApplicationDisplayIdentifiers(bool onlyActive, bool debuggable);
CFStringRef SBSCopyLocalizedApplicationNameForDisplayIdentifier(CFStringRef displayIdentifier);
CFDataRef SBSCopyIconImagePNGDataForDisplayIdentifier(CFStringRef displayIdentifier);
#endif

@interface XXTMultipleApplicationPicker ()
<
UITableViewDelegate,
UITableViewDataSource,
UISearchDisplayDelegate
>

@property(nonatomic, strong) UITableView *tableView;
@property(nonatomic, strong, readonly) UIRefreshControl *refreshControl;

//@property(nonatomic, strong, readonly) NSMutableDictionary <NSString *, NSDictionary *> *applications;

@property(nonatomic, strong, readonly) NSMutableArray <NSDictionary *> *selectedApplications;
@property(nonatomic, strong, readonly) NSMutableArray <NSDictionary *> *unselectedApplications;
@property(nonatomic, strong, readonly) NSMutableArray <NSDictionary *> *displaySelectedApplications;
@property(nonatomic, strong, readonly) NSMutableArray <NSDictionary *> *displayUnselectedApplications;

@property(nonatomic, strong, readonly) LSApplicationWorkspace *applicationWorkspace;

@end

// type
// title
// subtitle

@implementation XXTMultipleApplicationPicker {
    NSString *_pickerSubtitle;
    XXTP_START_IGNORE_PARTIAL
    UISearchDisplayController *_searchDisplayController;
    XXTP_END_IGNORE_PARTIAL
}

@synthesize pickerTask = _pickerTask;
@synthesize pickerMeta = _pickerMeta;

#pragma mark - XXTBasePicker

+ (NSString *)pickerKeyword {
    return @"apps";
}

- (NSArray <NSString *> *)pickerResult {
    NSMutableArray <NSString *> *selectedIdentifiers = [[NSMutableArray alloc] init];
    for (NSDictionary *dict in self.selectedApplications) {
        NSString *bid = dict[kXXTApplicationDetailKeyBundleID];
        if (bid)
        {
            [selectedIdentifiers addObject:bid];
        }
    }
    return [selectedIdentifiers copy];
}

#pragma mark - Default Style

- (UIStatusBarStyle)preferredStatusBarStyle {
    XXTP_START_IGNORE_PARTIAL
    if (self.searchDisplayController.active) {
        return UIStatusBarStyleDefault;
    }
    XXTP_END_IGNORE_PARTIAL
    return UIStatusBarStyleLightContent;
}

- (NSString *)title {
    if (self.pickerMeta[@"title"]) {
        return self.pickerMeta[@"title"];
    } else {
        return NSLocalizedString(@"Applications", nil);
    }
}

#pragma mark - Initializers

- (instancetype)init {
    if (self = [super init]) {
        _selectedApplications = [[NSMutableArray alloc] init];
        _unselectedApplications = [[NSMutableArray alloc] init];
        _displaySelectedApplications = [[NSMutableArray alloc] init];
        _displayUnselectedApplications = [[NSMutableArray alloc] init];
    }
    return self;
}

#pragma mark - View

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if (@available(iOS 11.0, *)) {
        
    } else {
        self.edgesForExtendedLayout = UIRectEdgeLeft | UIRectEdgeBottom | UIRectEdgeRight;
    }
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    _applicationWorkspace = ({
        Class LSApplicationWorkspace_class = objc_getClass("LSApplicationWorkspace");
        SEL selector = NSSelectorFromString(@"defaultWorkspace");
        LSApplicationWorkspace *applicationWorkspace = [LSApplicationWorkspace_class performSelector:selector];
        applicationWorkspace;
    });
#pragma clang diagnostic pop
    
    UISearchBar *searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44.f)];
    searchBar.placeholder = NSLocalizedString(@"Search Application", nil);
    searchBar.scopeButtonTitles = @[
                                    NSLocalizedString(@"Name", nil),
                                    NSLocalizedString(@"Bundle ID", nil)
                                    ];
    searchBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
    searchBar.autocorrectionType = UITextAutocorrectionTypeNo;
    searchBar.spellCheckingType = UITextSpellCheckingTypeNo;
    searchBar.backgroundColor = XXTColorPlainBackground();
    searchBar.barTintColor = XXTColorPlainBackground();
    
    XXTP_START_IGNORE_PARTIAL
    UISearchDisplayController *searchDisplayController = [[UISearchDisplayController alloc] initWithSearchBar:searchBar contentsController:self];
    searchDisplayController.searchResultsDelegate = self;
    searchDisplayController.searchResultsDataSource = self;
    searchDisplayController.delegate = self;
    _searchDisplayController = searchDisplayController;
    XXTP_END_IGNORE_PARTIAL
    
    _tableView = ({
        UITableView *tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
        [tableView registerNib:[UINib nibWithNibName:@"XXTApplicationCell" bundle:[NSBundle mainBundle]] forCellReuseIdentifier:kXXTApplicationCellReuseIdentifier];
        tableView.delegate = self;
        tableView.dataSource = self;
        tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        tableView.tableHeaderView = searchBar;
        XXTP_START_IGNORE_PARTIAL
        if (XXTP_SYSTEM_9) {
            tableView.cellLayoutMarginsFollowReadableWidth = NO;
        }
        XXTP_END_IGNORE_PARTIAL
        [tableView setEditing:YES animated:NO];
        [self.view addSubview:tableView];
        tableView;
    });
    
    UITableViewController *tableViewController = [[UITableViewController alloc] init];
    tableViewController.tableView = self.tableView;
    _refreshControl = ({
        UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
        [refreshControl addTarget:self action:@selector(asyncApplicationList:) forControlEvents:UIControlEventValueChanged];
        [tableViewController setRefreshControl:refreshControl];
        refreshControl;
    });
    [self.tableView.backgroundView insertSubview:self.refreshControl atIndex:0];
    
    UIBarButtonItem *rightItem = NULL;
    if ([self.pickerTask taskFinished]) {
        rightItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(taskFinished:)];
    } else {
        rightItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Next", nil) style:UIBarButtonItemStylePlain target:self action:@selector(taskNextStep:)];
    }
    self.navigationItem.rightBarButtonItem = rightItem;
    
    if (@available(iOS 11.0, *)) {
        self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    }
    
    [self.refreshControl beginRefreshing];
    [self asyncApplicationList:self.refreshControl];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    NSString *subtitle = nil;
    if (self.pickerMeta[@"subtitle"]) {
        subtitle = self.pickerMeta[@"subtitle"];
    } else {
        subtitle = NSLocalizedString(@"Select some applications.", nil);
    }
    [self updateSubtitle:subtitle];
}

- (void)asyncApplicationList:(UIRefreshControl *)refreshControl {
    
    NSArray <NSString *> *defaultIdentifiers = self.pickerMeta[@"default"];
    if (![defaultIdentifiers isKindOfClass:[NSArray class]])
    {
        defaultIdentifiers = @[];
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        
        NSArray <NSString *> *applicationIdentifiers = (NSArray *)CFBridgingRelease(SBSCopyApplicationDisplayIdentifiers(false, false));
        NSMutableArray <LSApplicationProxy *> *allApplications = nil;
        if (applicationIdentifiers) {
            allApplications = [NSMutableArray arrayWithCapacity:applicationIdentifiers.count];
            [applicationIdentifiers enumerateObjectsUsingBlock:^(NSString * _Nonnull bid, NSUInteger idx, BOOL * _Nonnull stop) {
                LSApplicationProxy *proxy = [LSApplicationProxy applicationProxyForIdentifier:bid];
                [allApplications addObject:proxy];
            }];
        } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            SEL selectorAll = NSSelectorFromString(@"allApplications");
            allApplications = [self.applicationWorkspace performSelector:selectorAll];
#pragma clang diagnostic pop
        }
        [self.unselectedApplications removeAllObjects];
        [self.selectedApplications removeAllObjects];
        
        NSString *whiteIconListPath = [[NSBundle mainBundle] pathForResource:@"xxte-white-icons" ofType:@"plist"];
        NSArray <NSString *> *blacklistIdentifiers = [NSDictionary dictionaryWithContentsOfFile:whiteIconListPath][@"xxte-white-icons"];
        NSOrderedSet <NSString *> *blacklistApplications = [[NSOrderedSet alloc] initWithArray:blacklistIdentifiers];
        for (LSApplicationProxy *appProxy in allApplications) {
            @autoreleasepool {
                NSString *applicationBundleID = appProxy.applicationIdentifier;
                BOOL shouldAdd = ![blacklistApplications containsObject:applicationBundleID];
                if (shouldAdd) {
                    NSString *applicationBundlePath = [appProxy.resourcesDirectoryURL path];
                    NSString *applicationContainerPath = nil;
                    NSString *applicationName = CFBridgingRelease(SBSCopyLocalizedApplicationNameForDisplayIdentifier((__bridge CFStringRef)(applicationBundleID)));
                    if (!applicationName) {
                        applicationName = appProxy.localizedName;
                    }
                    NSData *applicationIconImageData = CFBridgingRelease(SBSCopyIconImagePNGDataForDisplayIdentifier((__bridge CFStringRef)(applicationBundleID)));
                    UIImage *applicationIconImage = [UIImage imageWithData:applicationIconImageData];
                    if (XXTP_SYSTEM_8) {
                        if ([appProxy respondsToSelector:@selector(dataContainerURL)]) {
                            applicationContainerPath = [[appProxy dataContainerURL] path];
                        }
                    } else {
                        if ([appProxy respondsToSelector:@selector(containerURL)]) {
                            applicationContainerPath = [[appProxy containerURL] path];
                        }
                    }
                    NSMutableDictionary *applicationDetail = [[NSMutableDictionary alloc] init];
                    if (applicationBundleID) {
                        applicationDetail[kXXTApplicationDetailKeyBundleID] = applicationBundleID;
                    } else {
                        continue;
                    }
                    if (applicationName) {
                        applicationDetail[kXXTApplicationDetailKeyName] = applicationName;
                    }
                    if (applicationBundlePath) {
                        applicationDetail[kXXTApplicationDetailKeyBundlePath] = applicationBundlePath;
                    }
                    if (applicationContainerPath) {
                        applicationDetail[kXXTApplicationDetailKeyContainerPath] = applicationContainerPath;
                    }
                    if (applicationIconImage) {
                        applicationDetail[kXXTApplicationDetailKeyIconImage] = applicationIconImage;
                    }
                    if ([defaultIdentifiers containsObject:applicationBundleID]) {
                        [self.selectedApplications addObject:applicationDetail];
                    } else {
                        [self.unselectedApplications addObject:applicationDetail];
                    }
                }
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.tableView reloadData];
            [self.tableView reloadSections:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, 2)] withRowAnimation:UITableViewRowAnimationAutomatic];
            if (refreshControl && [refreshControl isRefreshing]) {
                [refreshControl endRefreshing];
            }
        });
    });
}

#pragma mark - UITableViewDataSource

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return XXTApplicationCellHeight;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 24.0;
}

- (void)tableView:(UITableView *)tableView reloadHeaderView:(UITableViewHeaderFooterView *)view forSection:(NSInteger)section {
    [self tableView:tableView willDisplayHeaderView:view forSection:section];
}

- (void)tableView:(UITableView *)tableView willDisplayFooterView:(nonnull UIView *)view forSection:(NSInteger)section {
    if (tableView.style == UITableViewStylePlain) {
        UITableViewHeaderFooterView *footer = (UITableViewHeaderFooterView *)view;
        footer.textLabel.font = [UIFont systemFontOfSize:12.0];
    }
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section {
    UILabel *label = ((UITableViewHeaderFooterView *)view).textLabel;
    if (label) {
        NSMutableArray <NSDictionary *> *selectedApplications = nil;
        NSMutableArray <NSDictionary *> *unselectedApplications = nil;
        if (tableView == self.tableView) {
            selectedApplications = self.selectedApplications;
            unselectedApplications = self.unselectedApplications;
        } else {
            selectedApplications = self.displaySelectedApplications;
            unselectedApplications = self.displayUnselectedApplications;
        }
        
        NSString *text = nil;
        if (section == kXXTApplicationPickerCellSectionSelected) {
            text = [NSString stringWithFormat:NSLocalizedString(@"Selected Applications (%lu)", nil), (unsigned long)selectedApplications.count];
        } else if (section == kXXTApplicationPickerCellSectionUnselected) {
            text = [NSString stringWithFormat:NSLocalizedString(@"Unselected Applications (%lu)", nil), (unsigned long)unselectedApplications.count];
        }
        if (text) {
            NSAttributedString *attributedText = [[NSAttributedString alloc] initWithString:text attributes:@{ NSFontAttributeName: [UIFont systemFontOfSize:14.0] }];
            label.attributedText = attributedText;
        }
        
        [label sizeToFit];
    }
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    static NSString *kMEWApplicationHeaderViewReuseIdentifier = @"kMEWApplicationHeaderViewReuseIdentifier";
    
    UITableViewHeaderFooterView *applicationHeaderView = [tableView dequeueReusableHeaderFooterViewWithIdentifier:kMEWApplicationHeaderViewReuseIdentifier];
    if (!applicationHeaderView) {
        applicationHeaderView = [[UITableViewHeaderFooterView alloc] initWithReuseIdentifier:kMEWApplicationHeaderViewReuseIdentifier];
    }
    
    return applicationHeaderView;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (tableView == self.tableView) {
        if (section == kXXTApplicationPickerCellSectionSelected) {
            return self.selectedApplications.count;
        } else if (section == kXXTApplicationPickerCellSectionUnselected) {
            return self.unselectedApplications.count;
        }
    } else {
        if (section == kXXTApplicationPickerCellSectionSelected) {
            return self.displaySelectedApplications.count;
        } else if (section == kXXTApplicationPickerCellSectionUnselected) {
            return self.displayUnselectedApplications.count;
        }
    }
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    XXTApplicationCell *cell = [tableView dequeueReusableCellWithIdentifier:kXXTApplicationCellReuseIdentifier];
    if (cell == nil) {
        cell = [[XXTApplicationCell alloc] initWithStyle:UITableViewCellStyleDefault
                                         reuseIdentifier:kXXTApplicationCellReuseIdentifier];
    }
    NSDictionary *appDetail = nil;
    if (tableView == self.tableView) {
        if (indexPath.section == kXXTApplicationPickerCellSectionSelected) {
            appDetail = self.selectedApplications[(NSUInteger) indexPath.row];
        } else if (indexPath.section == kXXTApplicationPickerCellSectionUnselected) {
            appDetail = self.unselectedApplications[(NSUInteger) indexPath.row];
        }
    } else {
        if (indexPath.section == kXXTApplicationPickerCellSectionSelected) {
            appDetail = self.displaySelectedApplications[(NSUInteger) indexPath.row];
        } else if (indexPath.section == kXXTApplicationPickerCellSectionUnselected) {
            appDetail = self.displayUnselectedApplications[(NSUInteger) indexPath.row];
        }
    }
    if (appDetail) {
        [cell setApplicationName:appDetail[kXXTApplicationDetailKeyName]];
        [cell setApplicationBundleID:appDetail[kXXTApplicationDetailKeyBundleID]];
        [cell setApplicationIconImage:appDetail[kXXTApplicationDetailKeyIconImage]];
        [cell setTintColor:XXTColorForeground()];
        [cell setAccessoryType:UITableViewCellAccessoryNone];
        [cell setShowsReorderControl:YES];
        return cell;
    }
    return [UITableViewCell new];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView == self.tableView) {
        if (indexPath.section == kXXTApplicationPickerCellSectionSelected) {
            return YES; // There is no need to change its order.
        }
    }
    return NO;
}

- (NSIndexPath *)tableView:(UITableView *)tableView targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)sourceIndexPath toProposedIndexPath:(NSIndexPath *)proposedDestinationIndexPath {
    if (tableView == self.tableView) {
        if (sourceIndexPath.section == kXXTApplicationPickerCellSectionSelected && proposedDestinationIndexPath.section == kXXTApplicationPickerCellSectionSelected) {
            return proposedDestinationIndexPath;
        }
    }
    return sourceIndexPath;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
    if (tableView == self.tableView) {
        if (fromIndexPath.section == kXXTApplicationPickerCellSectionSelected
            && toIndexPath.section == kXXTApplicationPickerCellSectionSelected)
        {
            NSDictionary *dict = self.selectedApplications[fromIndexPath.row];
            if (fromIndexPath.row > toIndexPath.row) {
                [self.selectedApplications insertObject:dict atIndex:toIndexPath.row];
                [self.selectedApplications removeObjectAtIndex:(fromIndexPath.row + 1)];
            }
            else if (fromIndexPath.row < toIndexPath.row) {
                [self.selectedApplications insertObject:dict atIndex:(toIndexPath.row + 1)];
                [self.selectedApplications removeObjectAtIndex:(fromIndexPath.row)];
            }
            [tableView moveRowAtIndexPath:fromIndexPath toIndexPath:toIndexPath];
        }
    }
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == kXXTApplicationPickerCellSectionSelected) {
        return UITableViewCellEditingStyleDelete;
    } else if (indexPath.section == kXXTApplicationPickerCellSectionUnselected) {
        return UITableViewCellEditingStyleInsert;
    }
    return UITableViewCellEditingStyleNone;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    NSDictionary *dict = nil;
    
    NSMutableArray <NSDictionary *> *selectedApplications = nil;
    NSMutableArray <NSDictionary *> *unselectedApplications = nil;
    if (tableView == self.tableView) {
        selectedApplications = self.selectedApplications;
        unselectedApplications = self.unselectedApplications;
    } else {
        selectedApplications = self.displaySelectedApplications;
        unselectedApplications = self.displayUnselectedApplications;
    }
    
    if (indexPath.section == kXXTApplicationPickerCellSectionSelected) {
        dict = selectedApplications[(NSUInteger) indexPath.row];
    } else if (indexPath.section == kXXTApplicationPickerCellSectionUnselected) {
        dict = unselectedApplications[(NSUInteger) indexPath.row];
    }
    
    NSIndexPath *toIndexPath = nil;
    BOOL alreadyExists = dict ? [selectedApplications containsObject:dict] : NO;
    
    if (alreadyExists && editingStyle == UITableViewCellEditingStyleDelete) {
        toIndexPath = [NSIndexPath indexPathForRow:0 inSection:kXXTApplicationPickerCellSectionUnselected];
        if (dict) {
            [selectedApplications removeObject:dict];
            [unselectedApplications insertObject:dict atIndex:0];
            if (tableView != self.tableView) {
                [self.selectedApplications removeObject:dict];
                [self.unselectedApplications insertObject:dict atIndex:0];
            }
        }
    } else if (!alreadyExists && editingStyle == UITableViewCellEditingStyleInsert) {
        toIndexPath = [NSIndexPath indexPathForRow:selectedApplications.count inSection:kXXTApplicationPickerCellSectionSelected];
        if (dict) {
            [unselectedApplications removeObject:dict];
            [selectedApplications addObject:dict];
            if (tableView != self.tableView) {
                [self.unselectedApplications removeObject:dict];
                [self.selectedApplications addObject:dict];
            }
        }
    }
    
    if (toIndexPath) {
        [tableView moveRowAtIndexPath:indexPath toIndexPath:toIndexPath];
        [tableView reloadRowsAtIndexPaths:@[toIndexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
    
    [self tableView:tableView reloadHeaderView:[tableView headerViewForSection:indexPath.section] forSection:indexPath.section];
    [self tableView:tableView reloadHeaderView:[tableView headerViewForSection:toIndexPath.section] forSection:toIndexPath.section];
    
    [self updateSubtitle:[NSString stringWithFormat:NSLocalizedString(@"%lu Application(s) selected.", nil), (unsigned long)self.selectedApplications.count]];
    
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - Task Operations

- (void)taskFinished:(UIBarButtonItem *)sender {
    [self.pickerFactory performFinished:self];
}

- (void)taskNextStep:(UIBarButtonItem *)sender {
    [self.pickerFactory performNextStep:self];
}

- (void)updateSubtitle:(NSString *)subtitle {
    _pickerSubtitle = subtitle;
    [self.pickerFactory performUpdateStep:self];
}

- (NSString *)pickerSubtitle {
    return _pickerSubtitle;
}

#pragma mark - UISearchDisplayDelegate

XXTP_START_IGNORE_PARTIAL
- (void)searchDisplayController:(UISearchDisplayController *)controller willShowSearchResultsTableView:(UITableView *)tableView {
    [tableView setEditing:YES animated:NO];
    [tableView registerNib:[UINib nibWithNibName:@"XXTApplicationCell" bundle:[NSBundle mainBundle]] forCellReuseIdentifier:kXXTApplicationCellReuseIdentifier];
    if (@available(iOS 11.0, *)) {
        tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    }
}
XXTP_END_IGNORE_PARTIAL
XXTE_START_IGNORE_PARTIAL
- (void)searchDisplayController:(UISearchDisplayController *)controller didShowSearchResultsTableView:(UITableView *)tableView {
    [self _findAndHideSearchBarShadowInView:tableView];
}
- (void)_findAndHideSearchBarShadowInView:(UIView *)view {
    NSString *usc = @"_";
    NSString *sb = @"UISearchBar";
    NSString *sv = @"ShadowView";
    NSString *s = [[usc stringByAppendingString:sb] stringByAppendingString:sv];
    
    for (UIView *v in view.subviews)
    {
        if ([v isKindOfClass:NSClassFromString(s)]) {
            v.hidden = YES;
        }
        [self _findAndHideSearchBarShadowInView:v];
    }
}
XXTE_END_IGNORE_PARTIAL
XXTP_START_IGNORE_PARTIAL
- (void)searchDisplayController:(UISearchDisplayController *)controller willHideSearchResultsTableView:(UITableView *)tableView {
    [self.tableView reloadData];
}
XXTP_END_IGNORE_PARTIAL
XXTP_START_IGNORE_PARTIAL
- (void)searchDisplayControllerWillBeginSearch:(UISearchDisplayController *)controller {
    
}
XXTP_END_IGNORE_PARTIAL
XXTP_START_IGNORE_PARTIAL
- (BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *)searchString {
    [self tableViewReloadSearch:controller.searchResultsTableView];
    return YES;
}
XXTP_END_IGNORE_PARTIAL
XXTP_START_IGNORE_PARTIAL
- (BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchScope:(NSInteger)searchOption {
    [self tableViewReloadSearch:controller.searchResultsTableView];
    return YES;
}
XXTP_END_IGNORE_PARTIAL
XXTP_START_IGNORE_PARTIAL
- (void)tableViewReloadSearch:(UITableView *)tableView {
    NSPredicate *predicate = nil;
    if (self.searchDisplayController.searchBar.selectedScopeButtonIndex == kXXTApplicationSearchTypeName) {
        predicate = [NSPredicate predicateWithFormat:@"kXXTApplicationDetailKeyName CONTAINS[cd] %@", self.searchDisplayController.searchBar.text];
    } else if (self.searchDisplayController.searchBar.selectedScopeButtonIndex == kXXTApplicationSearchTypeBundleID) {
        predicate = [NSPredicate predicateWithFormat:@"kXXTApplicationDetailKeyBundleID CONTAINS[cd] %@", self.searchDisplayController.searchBar.text];
    }
    if (predicate) {
        [self.displaySelectedApplications removeAllObjects];
        [self.displayUnselectedApplications removeAllObjects];
        [self.displaySelectedApplications addObjectsFromArray:[self.selectedApplications filteredArrayUsingPredicate:predicate]];
        [self.displayUnselectedApplications addObjectsFromArray:[self.unselectedApplications filteredArrayUsingPredicate:predicate]];
    }
}
XXTP_END_IGNORE_PARTIAL

#pragma mark - Memory

- (void)dealloc {
#ifdef DEBUG
    NSLog(@"- [%@ dealloc]", NSStringFromClass([self class]));
#endif
}

@end
