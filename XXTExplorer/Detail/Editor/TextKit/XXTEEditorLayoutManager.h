//
//  XXTEEditorLayoutManager.h
//  XXTExplorer
//
//  Created by Zheng Wu on 15/08/2017.
//  Copyright © 2017 Zheng. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface XXTEEditorLayoutManager : NSLayoutManager

@property (nonatomic, assign) BOOL showLineNumbers;
@property (nonatomic, assign) BOOL showInvisibleCharacters;
@property (nonatomic, assign) BOOL indentWrappedLines;

@property (nonatomic, strong) UIColor *invisibleColor;
@property (nonatomic, strong) UIFont *invisibleFont;

@property (nonatomic, strong) UIFont *lineNumberFont;
@property (nonatomic, strong) UIColor *lineNumberColor;
@property (nonatomic, assign) NSUInteger numberOfDigits;

@property (nonatomic, assign, readonly) CGFloat gutterWidth;

@property (nonatomic, assign, readonly) UIEdgeInsets lineAreaInset;
@property (nonatomic, assign, readonly) CGFloat fontPointSize;
@property (nonatomic, assign, readonly) CGFloat lineHeightScale;

//- (UIEdgeInsets)insetsForLineStartingAtCharacterIndex:(NSUInteger)characterIndex;
- (UIEdgeInsets)insetsForLineStartingAtCharacterIndex:(NSUInteger)characterIndex textContainer:(NSTextContainer *)container;

@end
