//
//  XXTEEditorSearchAccessoryView.m
//  XXTExplorer
//
//  Created by Zheng Wu on 14/12/2017.
//  Copyright © 2017 Zheng. All rights reserved.
//

#import "XXTEEditorSearchAccessoryView.h"

@interface XXTEEditorSearchAccessoryView ()

@property (nonatomic, strong) UIToolbar *toolbar;
@property (nonatomic, strong) UIBarButtonItem *counter;
@property (nonatomic, strong) UIBarButtonItem *fixedSpace;
@property (nonatomic, strong) UIBarButtonItem *flexibleSpace;
@property (nonatomic, strong) NSArray <UIBarButtonItem *> *allItems;

@end

@implementation XXTEEditorSearchAccessoryView

- (instancetype)init {
    if (self = [super initWithFrame:CGRectZero inputViewStyle:UIInputViewStyleKeyboard]) {
        [self setup];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame inputViewStyle:UIInputViewStyleKeyboard]) {
        [self setup];
    }
    return self;
}

- (void)setup {
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    _flexibleSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    
    UILabel *countLabel = [[UILabel alloc] init];
    countLabel.font = [UIFont fontWithName:@"Courier" size:16.0];
    countLabel.textAlignment = NSTextAlignmentRight;
    countLabel.textColor = self.tintColor; // *
    countLabel.text = NSLocalizedString(@"0/0", nil);
    [countLabel sizeToFit];
    _countLabel = countLabel;
    
    _counter = [[UIBarButtonItem alloc] initWithCustomView:countLabel];
    _fixedSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    _fixedSpace.width = 16.0;
    _allItems = @[ self.prevItem, self.nextItem, self.replaceItem, self.replaceAllItem, self.counter, self.dismissItem ];
    
    [self setReplaceMode:NO];
    [self addSubview:self.toolbar];
}

- (void)searchPreviousMatch {
    if ([_accessoryDelegate respondsToSelector:@selector(searchAccessoryViewShouldMatchPrev:)]) {
        [_accessoryDelegate searchAccessoryViewShouldMatchPrev:self];
    }
}

- (void)searchNextMatch {
    if ([_accessoryDelegate respondsToSelector:@selector(searchAccessoryViewShouldMatchNext:)]) {
        [_accessoryDelegate searchAccessoryViewShouldMatchNext:self];
    }
}

- (void)replaceAction {
    if ([_accessoryDelegate respondsToSelector:@selector(searchAccessoryViewShouldReplace:)]) {
        [_accessoryDelegate searchAccessoryViewShouldReplace:self];
    }
}

- (void)replaceAllAction {
    if ([_accessoryDelegate respondsToSelector:@selector(searchAccessoryViewShouldReplaceAll:)]) {
        [_accessoryDelegate searchAccessoryViewShouldReplaceAll:self];
    }
}

- (void)dismissItemTapped:(UIBarButtonItem *)sender {
    if ([_accessoryDelegate respondsToSelector:@selector(searchAccessoryView:didTapDismiss:)]) {
        [_accessoryDelegate searchAccessoryView:self didTapDismiss:sender];
    }
}

- (void)setTintColor:(UIColor *)tintColor {
    [super setTintColor:tintColor];
    UIToolbar *toolbar = self.toolbar;
    toolbar.tintColor = tintColor;
    for (UIBarButtonItem *item in self.allItems) {
        item.tintColor = tintColor;
    }
    self.countLabel.textColor = tintColor;
}

#pragma mark - UIView Getters

- (UIToolbar *)toolbar {
    if (!_toolbar) {
        UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:self.bounds];
        toolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [toolbar setBackgroundColor:[UIColor clearColor]];
        [toolbar setTranslucent:YES];
        _toolbar = toolbar;
    }
    return _toolbar;
}

- (void)setBarStyle:(UIBarStyle)barStyle {
    _barStyle = barStyle;
    UIToolbar *toolbar = self.toolbar;
    toolbar.barStyle = barStyle;
    if (barStyle == UIBarStyleDefault) {
        [toolbar setBackgroundImage:nil
                 forToolbarPosition:UIToolbarPositionAny
                         barMetrics:UIBarMetricsDefault];
    } else if (barStyle == UIBarStyleBlack) {
        [toolbar setBackgroundImage:[UIImage new]
                 forToolbarPosition:UIToolbarPositionAny
                         barMetrics:UIBarMetricsDefault];
    }
    [self reloadReplaceImages];
}

- (UIBarButtonItem *)dismissItem {
    if (!_dismissItem) {
        UIBarButtonItem *dismissItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"XXTEKeyboardDismiss"] style:UIBarButtonItemStylePlain target:self action:@selector(dismissItemTapped:)];
        dismissItem.tintColor = self.tintColor; // *
        dismissItem.enabled = YES;
        _dismissItem = dismissItem;
    }
    return _dismissItem;
}

- (UIBarButtonItem *)prevItem {
    if (!_prevItem) {
        UIBarButtonItem *prevButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"XXTEEditorSearchBarPrevIcon"]
                                                                           style:UIBarButtonItemStylePlain
                                                                          target:self
                                                                          action:@selector(searchPreviousMatch)];
        prevButtonItem.tintColor = self.tintColor; // *
        prevButtonItem.enabled = NO;
        _prevItem = prevButtonItem;
    }
    return _prevItem;
}

- (UIBarButtonItem *)nextItem {
    if (!_nextItem) {
        UIBarButtonItem *nextButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"XXTEEditorSearchBarNextIcon"]
                                                                           style:UIBarButtonItemStylePlain
                                                                          target:self
                                                                          action:@selector(searchNextMatch)];
        nextButtonItem.tintColor = self.tintColor; // *
        nextButtonItem.enabled = NO;
        _nextItem = nextButtonItem;
    }
    return _nextItem;
}

- (UIBarButtonItem *)replaceItem {
    if (!_replaceItem) {
        UIBarButtonItem *replaceItem = [[UIBarButtonItem alloc] initWithImage:[UIImage new] style:UIBarButtonItemStylePlain target:self action:@selector(replaceAction)];
        [replaceItem setBackgroundImage:[UIImage imageNamed:@"XXTEKeyboardReplaceDisabled"] forState:UIControlStateDisabled barMetrics:UIBarMetricsDefault];
        _replaceItem = replaceItem;
    }
    return _replaceItem;
}

- (UIBarButtonItem *)replaceAllItem {
    if (!_replaceAllItem) {
        UIBarButtonItem *replaceAllItem = [[UIBarButtonItem alloc] initWithImage:[UIImage new] style:UIBarButtonItemStylePlain target:self action:@selector(replaceAllAction)];
        [replaceAllItem setBackgroundImage:[UIImage imageNamed:@"XXTEKeyboardReplaceAllDisabled"] forState:UIControlStateDisabled barMetrics:UIBarMetricsDefault];
        _replaceAllItem = replaceAllItem;
    }
    return _replaceAllItem;
}

- (void)reloadReplaceImages {
    if (_barStyle == UIBarStyleDefault) {
        [self.replaceItem setImage:[[UIImage imageNamed:@"XXTEKeyboardReplace"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal]];
        [self.replaceAllItem setImage:[[UIImage imageNamed:@"XXTEKeyboardReplaceAll"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal]];
    } else if (_barStyle == UIBarStyleBlack) {
        [self.replaceItem setImage:[[UIImage imageNamed:@"XXTEKeyboardReplace"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
        [self.replaceAllItem setImage:[[UIImage imageNamed:@"XXTEKeyboardReplaceAll"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
    }
}

#pragma mark - Setters

- (void)setReplaceMode:(BOOL)replaceMode {
    _replaceMode = replaceMode;
}

- (void)setAllowReplacement:(BOOL)allowReplacement {
    _allowReplacement = allowReplacement;
}

#pragma mark - Update

- (void)updateAccessoryView {
    if (_replaceMode == YES) {
        [self.toolbar setItems:@[ self.prevItem, self.fixedSpace, self.nextItem, self.flexibleSpace, self.replaceItem, self.replaceAllItem, self.fixedSpace, self.dismissItem ]];
    } else {
        [self.toolbar setItems:@[ self.prevItem, self.fixedSpace, self.nextItem, self.flexibleSpace, self.counter, self.fixedSpace, self.dismissItem ]];
    }
    if (_allowReplacement) {
        [self.replaceItem setImage:[[UIImage imageNamed:@"XXTEKeyboardReplace"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal]];
        [self.replaceAllItem setImage:[[UIImage imageNamed:@"XXTEKeyboardReplaceAll"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal]];
        [self.replaceItem setEnabled:YES];
        [self.replaceAllItem setEnabled:YES];
    } else {
        [self.replaceItem setImage:[[UIImage imageNamed:@"XXTEKeyboardReplaceDisabled"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal]];
        [self.replaceAllItem setImage:[[UIImage imageNamed:@"XXTEKeyboardReplaceAllDisabled"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal]];
        [self.replaceItem setEnabled:NO];
        [self.replaceAllItem setEnabled:NO];
    }
}

@end
