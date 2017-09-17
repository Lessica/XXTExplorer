//
//  XUIListViewController.m
//  XXTExplorer
//
//  Created by Zheng on 17/07/2017.
//  Copyright © 2017 Zheng. All rights reserved.
//

#import "XUI.h"
#import "XUIListViewController.h"

#import "XUIListHeaderView.h"
#import "XUIGroupCell.h"
#import "XUILinkCell.h"
#import "XUIOptionCell.h"
#import "XUIMultipleOptionCell.h"
#import "XUIOrderedOptionCell.h"
#import "XUITitleValueCell.h"
#import "XUIButtonCell.h"
#import "XUITextareaCell.h"
#import "XUIFileCell.h"

#import "XXTExplorerEntryParser.h"
#import "XXTExplorerEntryService.h"
#import "XXTEUserInterfaceDefines.h"
#import "XXTEDispatchDefines.h"

#import "XUIOptionViewController.h"
#import "XUIMultipleOptionViewController.h"
#import "XUIOrderedOptionViewController.h"
#import "XXTECommonWebViewController.h"
#import "XXTEObjectViewController.h"
#import "XUITextareaViewController.h"

#import "XUICellFactory.h"
#import "XUILogger.h"
#import "XUITheme.h"
#import "XUIAdapter.h"

#import "XXTPickerSnippet.h"
#import "XXTPickerFactory.h"

#import "XXTExplorerItemPicker.h"

@interface XUIListViewController () <XUICellFactoryDelegate, XUIOptionViewControllerDelegate, XUIMultipleOptionViewControllerDelegate, XUIOrderedOptionViewControllerDelegate, XUITextareaViewControllerDelegate, XXTPickerFactoryDelegate, XXTExplorerItemPickerDelegate>

@property (nonatomic, strong) NSMutableArray <XUIBaseCell *> *cellsNeedStore;
@property (nonatomic, assign) BOOL shouldStoreCells;

@property (nonatomic, strong, readonly) XUICellFactory *parser;

@property (nonatomic, strong) XXTPickerFactory *pickerFactory;
@property (nonatomic, strong) XUIBaseCell *pickerCell;

@property (nonatomic, strong) XUIListHeaderView *headerView;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, assign) UIEdgeInsets defaultInsets;

@property (nonatomic, strong) UIBarButtonItem *closeButtonItem;

@end

@implementation XUIListViewController

@synthesize theme = _theme, adapter = _adapter;

+ (XXTExplorerEntryParser *)entryParser {
    static XXTExplorerEntryParser *entryParser = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        if (!entryParser) {
            entryParser = [[XXTExplorerEntryParser alloc] init];
        }
    });
    return entryParser;
}

+ (XXTExplorerEntryService *)entryService {
    static XXTExplorerEntryService *entryService = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        if (!entryService) {
            entryService = [XXTExplorerEntryService sharedInstance];
        }
    });
    return entryService;
}

- (instancetype)initWithPath:(NSString *)path {
    if (self = [super initWithPath:path]) {
        if (!path)
            return nil;
        [self setup];
    }
    return self;
}

- (instancetype)initWithPath:(NSString *)path withBundlePath:(NSString *)bundlePath {
    if (self = [super initWithPath:path]) {
        if (!path || !bundlePath)
            return nil;
        _bundle = [NSBundle bundleWithPath:bundlePath];
        [self setup];
    }
    return self;
}

- (void)setup {
    {
        _cellsNeedStore = [[NSMutableArray alloc] init];
        
        XUIAdapter *adapter = [[XUIAdapter alloc] initWithXUIPath:self.entryPath Bundle:self.bundle];
        if (!adapter) {
            return;
        }
        _adapter = adapter;
        
        NSError *xuiError = nil;
        XUICellFactory *parser = [[XUICellFactory alloc] initWithAdapter:adapter Error:&xuiError];
        if (!xuiError) {
            parser.delegate = self;
            _parser = parser;
            _theme = parser.theme;
        } else {
            [self presentErrorAlertController:xuiError];
        }
        
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSString *entryPath = self.entryPath;
    if (entryPath) {
        NSString *entryName = [entryPath lastPathComponent];
        self.title = entryName;
    }
    
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    
    NSDictionary <NSString *, id> *rootEntry = self.parser.rootEntry;
    
    NSString *listTitle = rootEntry[@"title"];
    if (listTitle) {
        self.title = listTitle;
    }
    
    {
        [self.parser parse];
    }
    
    NSString *listHeader = rootEntry[@"header"];
    NSString *listSubheader = rootEntry[@"subheader"];
    
    if (listHeader && listSubheader) {
        self.headerView.headerText = listHeader;
        self.headerView.subheaderText = listSubheader;
    }
    
    [self setupSubviews];

    if ([self.navigationController.viewControllers firstObject] == self) {
        self.navigationItem.leftBarButtonItem = self.closeButtonItem;
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardDidAppear:) name:UIKeyboardDidShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillDisappear:) name:UIKeyboardWillHideNotification object:nil];
    [super viewWillAppear:animated];
    [self storeCellsIfNecessary];
}

- (void)viewWillDisappear:(BOOL)animated {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardDidShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
    [super viewWillDisappear:animated];
}

- (void)setupSubviews {
    [self.view addSubview:self.tableView];
    if (self.headerView.headerText.length > 0 &&
        self.headerView.subheaderText.length > 0) {
        [self.tableView setTableHeaderView:self.headerView];
        if (XXTE_SYSTEM_8) {
            
        } else {
            [self.headerView setNeedsLayout];
            [self.headerView layoutIfNeeded];
            CGFloat height = [self.headerView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize].height;
            
            // update the header's frame and set it again
            CGRect headerFrame = self.headerView.frame;
            headerFrame.size.height = height;
            self.headerView.frame = headerFrame;
            self.tableView.tableHeaderView = self.headerView;
        }
    }
}

#pragma mark - UIView Getters

- (UIBarButtonItem *)closeButtonItem {
    if (!_closeButtonItem) {
        UIBarButtonItem *closeButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Close", nil) style:UIBarButtonItemStylePlain target:self action:@selector(dismissViewController:)];
        closeButtonItem.tintColor = [UIColor whiteColor];
        _closeButtonItem = closeButtonItem;
    }
    return _closeButtonItem;
}

- (XUIListHeaderView *)headerView {
    if (!_headerView) {
        XUIListHeaderView *headerView = [[XUIListHeaderView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 140.f)];
        _headerView = headerView;
    }
    return _headerView;
}

- (UITableView *)tableView {
    if (!_tableView) {
        UITableView *tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
        tableView.dataSource = self;
        tableView.delegate = self;
        tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        XUI_START_IGNORE_PARTIAL
        if (XUI_SYSTEM_9) {
            tableView.cellLayoutMarginsFollowReadableWidth = NO;
        }
        XUI_END_IGNORE_PARTIAL
        _tableView = tableView;
    }
    return _tableView;
}

#pragma mark - UITableViewDataSource & UITableViewDelegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (tableView == self.tableView) {
        return self.parser.sectionCells.count;
    }
    return 0;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (tableView == self.tableView) {
        return self.parser.otherCells[(NSUInteger) section].count;
    }
    return 0;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 44.f;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView == self.tableView) {
        XUIBaseCell *cell = self.parser.otherCells[(NSUInteger) indexPath.section][(NSUInteger) indexPath.row];
        CGFloat cellHeight = [cell.xui_height floatValue];
        if (cellHeight > 0) {
            return cellHeight;
        } else {
            if (XXTE_SYSTEM_8) {
                return UITableViewAutomaticDimension;
            } else {
                [cell setNeedsUpdateConstraints];
                [cell updateConstraintsIfNeeded];
                
                cell.bounds = CGRectMake(0.0f, 0.0f, CGRectGetWidth(tableView.bounds), CGRectGetHeight(cell.bounds));
                [cell setNeedsLayout];
                [cell layoutIfNeeded];
                
                CGFloat height = [cell.contentView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize].height;
                return (height > 0) ? (height + 1.f) : 44.f;
            }
        }
    }
    return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (tableView == self.tableView) {
        return self.parser.sectionCells[(NSUInteger) section].xui_label;
    }
    return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (tableView == self.tableView) {
        return self.parser.sectionCells[(NSUInteger) section].xui_footerText;
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    XUIBaseCell *cell = self.parser.otherCells[(NSUInteger) indexPath.section][(NSUInteger) indexPath.row];
    if ([cell isKindOfClass:[XUIOptionCell class]]) {
        [self updateLinkListCell:(XUIOptionCell *)cell];
    }
    else if ([cell isKindOfClass:[XUIMultipleOptionCell class]]) {
        [self updateLinkMultipleListCell:(XUIMultipleOptionCell *)cell];
    }
    else if ([cell isKindOfClass:[XUIOrderedOptionCell class]]) {
        [self updateLinkOrderedListCell:(XUIOrderedOptionCell *)cell];
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (tableView == self.tableView) {
        XUIBaseCell *cell = [tableView cellForRowAtIndexPath:indexPath];
        if ([cell isKindOfClass:[XUILinkCell class]]) {
            [self tableView:tableView performLinkCell:cell];
        } else if ([cell isKindOfClass:[XUIOptionCell class]]) {
            [self tableView:tableView performLinkListCell:cell];
        } else if ([cell isKindOfClass:[XUIMultipleOptionCell class]]) {
            [self tableView:tableView performLinkMultipleListCell:cell];
        } else if ([cell isKindOfClass:[XUIOrderedOptionCell class]]) {
            [self tableView:tableView performLinkOrderedListCell:cell];
        } else if ([cell isKindOfClass:[XUITitleValueCell class]]) {
            [self tableView:tableView performTitleValueCell:cell];
        } else if ([cell isKindOfClass:[XUIButtonCell class]]) {
            [self tableView:tableView performButtonCell:cell];
        } else if ([cell isKindOfClass:[XUITextareaCell class]]) {
            [self tableView:tableView performTextareaCell:cell];
        } else if ([cell isKindOfClass:[XUIFileCell class]]) {
            [self tableView:tableView performFileCell:cell];
        }
    }
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    XUIBaseCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    if ([cell isKindOfClass:[XUITitleValueCell class]]) {
        XUITitleValueCell *titleValueCell = (XUITitleValueCell *)cell;
        if (titleValueCell.xui_snippet) {
            NSString *snippetPath = [self.bundle pathForResource:titleValueCell.xui_snippet ofType:nil];
            NSError *snippetError = nil;
            XXTPickerSnippet *snippet = [[XXTPickerSnippet alloc] initWithContentsOfFile:snippetPath Error:&snippetError];
            if (snippetError) {
                [self presentErrorAlertController:snippetError];
                return;
            }
            XXTPickerFactory *factory = [[XXTPickerFactory alloc] init];
            factory.delegate = self;
            [factory executeTask:snippet fromViewController:self];
            self.pickerCell = titleValueCell;
            self.pickerFactory = factory;
        }
    }
}

- (void)tableView:(UITableView *)tableView performFileCell:(UITableViewCell *)cell {
    XUIFileCell *fileCell = (XUIFileCell *)cell;
    NSString *bundlePath = [self.bundle bundlePath];
    NSString *initialPath = fileCell.xui_initialPath;
    // NSString *filePath = fileCell.xui_value;
    if (initialPath) {
        if ([initialPath isAbsolutePath]) {
            
        } else {
            initialPath = [bundlePath stringByAppendingPathComponent:initialPath];
        }
    } else {
        initialPath = bundlePath;
    }
    self.pickerCell = fileCell;
    XXTExplorerItemPicker *itemPicker = [[XXTExplorerItemPicker alloc] initWithEntryPath:initialPath];
    itemPicker.delegate = self;
    itemPicker.allowedExtensions = fileCell.xui_allowedExtensions;
    [self.navigationController pushViewController:itemPicker animated:YES];
}

- (void)tableView:(UITableView *)tableView performButtonCell:(UITableViewCell *)cell {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    XUIButtonCell *buttonCell = (XUIButtonCell *)cell;
    if ([buttonCell.xui_enabled boolValue] && buttonCell.xui_action) {
        NSString *selectorName = buttonCell.xui_action;
        SEL actionSelector = NSSelectorFromString(selectorName);
        if (actionSelector && [self respondsToSelector:actionSelector]) {
            [self performSelector:actionSelector withObject:cell];
        } else {
            [self.parser.logger logMessage:XUIParserErrorUndknownSelector(NSStringFromSelector(actionSelector))];
        }
    }
#pragma clang diagnostic pop
}

- (void)tableView:(UITableView *)tableView performTitleValueCell:(UITableViewCell *)cell {
    XUITitleValueCell *titleValueCell = (XUITitleValueCell *)cell;
    if (titleValueCell.xui_value) {
        id extendedValue = titleValueCell.xui_value;
        XXTEObjectViewController *objectViewController = [[XXTEObjectViewController alloc] initWithRootObject:extendedValue];
        objectViewController.title = titleValueCell.textLabel.text;
        objectViewController.entryBundle = self.bundle;
        [self.navigationController pushViewController:objectViewController animated:YES];
    }
}

- (void)tableView:(UITableView *)tableView performLinkOrderedListCell:(UITableViewCell *)cell {
    XUIOrderedOptionCell *linkListCell = (XUIOrderedOptionCell *)cell;
    if (linkListCell.xui_options)
    {
        XUIOrderedOptionViewController *optionViewController = [[XUIOrderedOptionViewController alloc] initWithCell:linkListCell];
        optionViewController.adapter = self.adapter;
        optionViewController.delegate = self;
        optionViewController.title = linkListCell.xui_label;
        optionViewController.theme = self.parser.theme;
        [self.navigationController pushViewController:optionViewController animated:YES];
    }
}

- (void)tableView:(UITableView *)tableView performLinkMultipleListCell:(UITableViewCell *)cell {
    XUIMultipleOptionCell *linkListCell = (XUIMultipleOptionCell *)cell;
    if (linkListCell.xui_options)
    {
        XUIMultipleOptionViewController *optionViewController = [[XUIMultipleOptionViewController alloc] initWithCell:linkListCell];
        optionViewController.adapter = self.adapter;
        optionViewController.delegate = self;
        optionViewController.title = linkListCell.xui_label;
        optionViewController.theme = self.parser.theme;
        [self.navigationController pushViewController:optionViewController animated:YES];
    }
}

- (void)tableView:(UITableView *)tableView performLinkListCell:(UITableViewCell *)cell {
    XUIOptionCell *linkListCell = (XUIOptionCell *)cell;
    if (linkListCell.xui_options)
    {
        XUIOptionViewController *optionViewController = [[XUIOptionViewController alloc] initWithCell:linkListCell];
        optionViewController.adapter = self.adapter;
        optionViewController.delegate = self;
        optionViewController.title = linkListCell.xui_label;
        optionViewController.theme = self.parser.theme;
        [self.navigationController pushViewController:optionViewController animated:YES];
    }
}

- (void)tableView:(UITableView *)tableView performLinkCell:(UITableViewCell *)cell {
    XUILinkCell *linkCell = (XUILinkCell *)cell;
    NSString *detailUrl = linkCell.xui_url;
    UIViewController *detailController = nil;
    NSURL *detailPathURL = [NSURL URLWithString:detailUrl];
    if ([detailPathURL scheme]) {
        XXTECommonWebViewController *webController = [[XXTECommonWebViewController alloc] initWithURL:detailPathURL];
        detailController = webController;
    } else {
        NSString *detailPathNameExt = [[detailUrl pathExtension] lowercaseString];
        NSString *detailPath = [self.bundle pathForResource:detailUrl ofType:nil];
        if ([[self.class suggestedExtensions] containsObject:detailPathNameExt]) {
            detailController = [[[self class] alloc] initWithPath:detailPath withBundlePath:[self.bundle bundlePath]];
        }
        else {
            NSError *entryError = nil;
            NSDictionary *entryAttributes = [self.class.entryParser entryOfPath:detailPath withError:&entryError];
            if (!entryError && [self.class.entryService hasViewerForEntry:entryAttributes]) {
                UIViewController <XXTEViewer> *viewer = [self.class.entryService viewerForEntry:entryAttributes];
                detailController = viewer;
            }
        }
    }
    if (detailController) {
        detailController.title = linkCell.xui_label;
        [self.navigationController pushViewController:detailController animated:YES];
    }
}

- (void)tableView:(UITableView *)tableView performTextareaCell:(UITableViewCell *)cell {
    XUITextareaCell *textareaCell = (XUITextareaCell *)cell;
    XUITextareaViewController *textareaViewController = [[XUITextareaViewController alloc] initWithCell:textareaCell];
    textareaViewController.adapter = self.adapter;
    textareaViewController.delegate = self;
    textareaViewController.title = textareaCell.xui_label;
    [self.navigationController pushViewController:textareaViewController animated:YES];
}

#pragma mark - XUICellFactoryDelegate

- (void)cellFactoryDidFinishParsing:(XUICellFactory *)parser {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
    });
}

- (void)cellFactory:(XUICellFactory *)parser didFailWithError:(NSError *)error {
    [self presentErrorAlertController:error];
}

- (void)presentErrorAlertController:(NSError *)error {
    @weakify(self);
    dispatch_async(dispatch_get_main_queue(), ^{
        @strongify(self);
        NSString *entryName = [self.entryPath lastPathComponent];
        XXTE_START_IGNORE_PARTIAL
        if (XXTE_SYSTEM_8) {
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"XUI Error", nil) message:[NSString stringWithFormat:NSLocalizedString(@"%@\n%@: %@", nil), entryName, error.localizedDescription, error.localizedFailureReason] preferredStyle:UIAlertControllerStyleAlert];
            [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleCancel handler:nil]];
            [self.navigationController presentViewController:alertController animated:YES completion:nil];
        } else {
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"XUI Error", nil) message:[NSString stringWithFormat:NSLocalizedString(@"%@\n%@: %@", nil), entryName, error.localizedDescription, error.localizedFailureReason] delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", nil) otherButtonTitles:nil];
            [alertView show];
        }
        XXTE_END_IGNORE_PARTIAL
    });
}

#pragma mark - XUIOptionViewControllerDelegate

- (void)optionViewController:(XUIOptionViewController *)controller didSelectOption:(NSInteger)optionIndex {
    [self updateLinkListCell:controller.cell];
    [self.parser.adapter saveDefaultsFromCell:controller.cell];
}

- (void)updateLinkListCell:(XUIOptionCell *)cell {
    NSUInteger optionIndex = 0;
    id rawValue = cell.xui_value;
    if (rawValue) {
        NSUInteger rawIndex = [cell.xui_options indexOfObjectPassingTest:^BOOL(NSDictionary * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([rawValue isEqual:obj[XUIOptionCellValueKey]]) {
                return YES;
            }
            return NO;
        }];
        if ((rawIndex) != NSNotFound) {
            optionIndex = rawIndex;
        }
    }
    if (optionIndex < cell.xui_options.count) {
        NSString *shortTitle = cell.xui_options[optionIndex][XUIOptionCellShortTitleKey];
        cell.detailTextLabel.text = shortTitle;
    }
}

#pragma mark - XUIMultipleOptionViewControllerDelegate

- (void)multipleOptionViewController:(XUIMultipleOptionViewController *)controller didSelectOption:(NSArray <NSNumber *> *)optionIndexes {
    [self updateLinkMultipleListCell:controller.cell];
    [self.parser.adapter saveDefaultsFromCell:controller.cell];
}

- (void)updateLinkMultipleListCell:(XUIMultipleOptionCell *)cell {
    NSArray *optionValues = cell.xui_value;
    NSString *shortTitle = [NSString stringWithFormat:NSLocalizedString(@"%lu Selected", nil), optionValues.count];
    cell.detailTextLabel.text = shortTitle;
}

#pragma mark - XUIOrderedOptionViewControllerDelegate

- (void)orderedOptionViewController:(XUIOrderedOptionViewController *)controller didSelectOption:(NSArray<NSNumber *> *)optionIndexes {
    [self updateLinkOrderedListCell:controller.cell];
    [self.parser.adapter saveDefaultsFromCell:controller.cell];
}

- (void)updateLinkOrderedListCell:(XUIOrderedOptionCell *)cell {
    NSArray *optionValues = cell.xui_value;
    NSString *shortTitle = [NSString stringWithFormat:NSLocalizedString(@"%lu Selected", nil), optionValues.count];
    cell.detailTextLabel.text = shortTitle;
}

#pragma mark - XUITextareaViewControllerDelegate

- (void)textareaViewControllerTextDidChanged:(XUITextareaViewController *)controller {
    [self storeCellWhenNeeded:controller.cell];
}

#pragma mark - XXTPickerFactoryDelegate

- (BOOL)pickerFactory:(XXTPickerFactory *)factory taskShouldEnterNextStep:(XXTPickerSnippet *)task {
    return YES;
}

- (BOOL)pickerFactory:(XXTPickerFactory *)factory taskShouldFinished:(XXTPickerSnippet *)task {
    blockUserInteractions(self, YES, 0);
    @weakify(self);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        @strongify(self);
        NSError *error = nil;
        id result = [task generateWithError:&error];
        dispatch_async_on_main_queue(^{
            blockUserInteractions(self, NO, 0);
            if (result) {
                if ([self.pickerCell isKindOfClass:[XUITitleValueCell class]]) {
                    XUITitleValueCell *cell = (XUITitleValueCell *)self.pickerCell;
                    cell.xui_value = result;
                    [self storeCellWhenNeeded:cell];
                    [self storeCellsIfNecessary];
                }
            } else {
                [self presentErrorAlertController:error];
            }
        });
    });
    return YES;
}

#pragma mark - XXTExplorerItemPickerDelegate

- (void)itemPicker:(XXTExplorerItemPicker *)picker didSelectItemAtPath:(NSString *)path {
    XUIFileCell *cell = (XUIFileCell *)self.pickerCell;
    cell.xui_value = path;
    [self storeCellWhenNeeded:cell];
    [self storeCellsIfNecessary];
    [self.navigationController popToViewController:self animated:YES];
}

#pragma mark - Store

- (void)storeCellWhenNeeded:(XUIBaseCell *)cell {
    if (![self.cellsNeedStore containsObject:cell]) {
        [self.cellsNeedStore addObject:cell];
    }
    [self setNeedsStoreCells];
}

- (void)setNeedsStoreCells {
    if (self.shouldStoreCells == NO) {
        self.shouldStoreCells = YES;
    }
}

- (void)storeCellsIfNecessary {
    if (self.shouldStoreCells) {
        self.shouldStoreCells = NO;
        for (XUIBaseCell *cell in self.cellsNeedStore) {
            [self.parser.adapter saveDefaultsFromCell:cell];
        }
    }
}

#pragma mark - UIControl Actions

- (void)dismissViewController:(id)dismissViewController {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Keyboard

// Called when the UIKeyboardDidShowNotification is sent.
- (void)keyboardDidAppear:(NSNotification *)aNotification
{
    NSDictionary* info = [aNotification userInfo];
    CGSize kbSize = [info[UIKeyboardFrameEndUserInfoKey] CGRectValue].size;
    
    UIEdgeInsets contentInsets = UIEdgeInsetsMake(0.0, 0.0, kbSize.height, 0.0);
    self.tableView.contentInset = contentInsets;
    self.tableView.scrollIndicatorInsets = contentInsets;
}

// Called when the UIKeyboardWillHideNotification is sent
- (void)keyboardWillDisappear:(NSNotification *)aNotification
{
    UITableView *tableView = self.tableView;
    UIEdgeInsets contentInsets = XXTE_PAD ? UIEdgeInsetsZero : UIEdgeInsetsMake(0.0, 0.0, self.tabBarController.tabBar.bounds.size.height, 0.0);
    tableView.contentInset = contentInsets;
    tableView.scrollIndicatorInsets = contentInsets;
}

#pragma mark - Memory

- (void)dealloc {
#ifdef DEBUG
    NSLog(@"- [XUIListViewController dealloc]");
#endif
}

@end
