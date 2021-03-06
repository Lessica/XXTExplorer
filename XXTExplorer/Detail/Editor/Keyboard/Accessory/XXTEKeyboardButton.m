//
//  XXTEKeyboardButton.m
//  XXTouchApp
//
//  Created by Zheng on 9/19/16.
//  Copyright © 2016 Zheng. All rights reserved.
//

#import "XXTEKeyboardButton.h"
#import "XXTEKeyboardButtonView.h"
#import "UIImage+ColoredImage.h"


@interface XXTEKeyboardButton ()

@property(nonatomic, strong) UILabel *inputLabel;
@property(nonatomic, strong) XXTEKeyboardButtonView *buttonView;
@property(nonatomic, assign) XXTEKeyboardButtonPosition position;
@property(nonatomic, assign) CGFloat keyCornerRadius UI_APPEARANCE_SELECTOR;

@property(nonatomic, strong) NSMutableArray <UILabel *> *labels;
@property(nonatomic, assign) CGFloat labelWidth;
@property(nonatomic, assign) CGFloat labelHeight;
@property(nonatomic, assign) CGFloat leftInset;
@property(nonatomic, assign) CGFloat rightInset;
@property(nonatomic, assign) CGFloat topInset;
@property(nonatomic, assign) CGFloat bottomInset;
@property(nonatomic, assign) CGFloat fontSize;
@property(nonatomic, assign) CGFloat bigFontSize;
@property(nonatomic, assign) BOOL trackPoint;
@property(nonatomic, assign) BOOL actionPoint;
@property(nonatomic, assign) CGPoint touchBeginPoint;
@property(nonatomic, strong) NSDate *firstTapDate;
@property(nonatomic, assign) CGRect startLocation;

@end

#define TIME_INTERVAL_FOR_DOUBLE_TAP 0.4

@implementation XXTEKeyboardButton

#pragma mark - UIView

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setup];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self setup];
    }
    return self;
}

- (void)setup {
    _tabString = @"\t";
    
    self.backgroundColor = [UIColor clearColor];
    self.clipsToBounds = NO;
    self.layer.masksToBounds = NO;
    self.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;

    if (_style == XXTEKeyboardButtonTypePhone) {
        _labelWidth = 14.f;
        _labelHeight = 14.f;
        _leftInset = 4.f;
        _rightInset = 4.f;
        _topInset = 2.f;
        _bottomInset = 2.5f;
        if (XXTE_IS_IPHONE_6_BELOW)
        {
            _fontSize = 8.f;
            _bigFontSize = 12.f;
        }
        else
        {
            _fontSize = 10.f;
            _bigFontSize = 14.f;
        }
    } else if (_style == XXTEKeyboardButtonTypeTablet) {
        _labelWidth = 20.f;
        _labelHeight = 20.f;
        _leftInset = 9.f;
        _rightInset = 9.f;
        _topInset = 3.f;
        _bottomInset = 8.f;
        _fontSize = 15.f;
        _bigFontSize = 20.f;
    }

    self.labels = [[NSMutableArray alloc] init];
    
    UIColor *highlightColor = [UIColor redColor];

    UILabel *label1 = [[UILabel alloc] initWithFrame:CGRectMake(_leftInset, _topInset, _labelWidth, _labelHeight)];
    label1.textAlignment = NSTextAlignmentLeft;
    [self addSubview:label1];
    [label1 setHighlightedTextColor:highlightColor];
    [self.labels addObject:label1];

    UILabel *label2 = [[UILabel alloc] initWithFrame:CGRectMake(self.frame.size.width - _labelWidth - _rightInset, _topInset, _labelWidth, _labelHeight)];
    label2.textAlignment = NSTextAlignmentRight;
    label2.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self addSubview:label2];
    [label2 setHighlightedTextColor:highlightColor];
    [self.labels addObject:label2];

    UILabel *label3 = [[UILabel alloc] initWithFrame:CGRectIntegral(CGRectMake((self.frame.size.width - _labelWidth - _leftInset - _rightInset) / 2 + _leftInset, (self.frame.size.height - _labelHeight - _topInset - _bottomInset) / 2 + _topInset, _labelWidth, _labelHeight))];
    label3.textAlignment = NSTextAlignmentCenter;
    label3.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self addSubview:label3];
    [label3 setHighlightedTextColor:highlightColor];
    [self.labels addObject:label3];

    UILabel *label4 = [[UILabel alloc] initWithFrame:CGRectMake(_leftInset, (self.frame.size.height - _labelHeight - _bottomInset), _labelWidth, _labelHeight)];
    label4.textAlignment = NSTextAlignmentLeft;
    [self addSubview:label4];
    [label4 setHighlightedTextColor:highlightColor];
    [self.labels addObject:label4];

    UILabel *label5 = [[UILabel alloc] initWithFrame:CGRectMake(self.frame.size.width - _labelWidth - _rightInset, (self.frame.size.height - _labelHeight - _bottomInset), _labelWidth, _labelHeight)];
    label5.textAlignment = NSTextAlignmentRight;
    label5.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self addSubview:label5];
    [label5 setHighlightedTextColor:highlightColor];
    [self.labels addObject:label5];

    _firstTapDate = [[NSDate date] dateByAddingTimeInterval:-1];

    [self updateDisplayStyle];
}

- (void)didMoveToSuperview {
    [self updateButtonPosition];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self setNeedsDisplay];
    [self updateButtonPosition];
}

- (void)setInput:(NSString *)input {
    _input = input;
    
    for (NSUInteger i = 0; i < MIN(input.length, 5); i++) {
        UILabel *currentLabel = self.labels[i];
        NSString *currentChar = [input substringWithRange:NSMakeRange(i, 1)];
        [currentLabel setText:currentChar];
        [currentLabel setAdjustsFontSizeToFitWidth:YES];

        NSString *flag = [input substringToIndex:1];
        if ([flag isEqualToString:@"R"]) {
            self.trackPoint = YES;
            
            if (i != 2)
                [currentLabel setHidden:YES];
            else {
                _font = [UIFont fontWithName:@"fontello" size:self.bounds.size.width * .6f];
                [currentLabel setFont:self.font];
                
                const unichar c = 0xe804; // circle icon
                [currentLabel setText:[[NSString alloc] initWithCharacters:&c length:1]];
                [currentLabel setFrame:self.bounds];
            }
        }
        else if ([flag isEqualToString:@"T"]) {
            self.actionPoint = YES;
            unichar c;
            switch (i) {
                case 0:
                    c = 0xe801;
                    break;
                case 1:
                    c = 0xe802;
                    break;
                case 2:
                    c = 0xe803;
                    break;
                case 3:
                    c = 0xe800;
                    break;
                case 4:
                    c = 0xe805;
                    break;
                default:
                    break;
            }
            if (i == 2) {
                _font = [UIFont fontWithName:@"fontello" size:self.bigFontSize];
            } else {
                _font = [UIFont fontWithName:@"fontello" size:self.fontSize];
            }
            [currentLabel setFont:self.font];
            [currentLabel setText:[[NSString alloc] initWithCharacters:&c length:1]];
        }
        else {
            if (i == 2) {
                _font = [UIFont systemFontOfSize:self.bigFontSize];
            } else {
                _font = [UIFont systemFontOfSize:self.fontSize];
            }
            [currentLabel setFont:self.font];
        }
    }
}

- (void)setStyle:(XXTEKeyboardButtonType)style {
    [self willChangeValueForKey:NSStringFromSelector(@selector(style))];
    _style = style;
    [self didChangeValueForKey:NSStringFromSelector(@selector(style))];

    [self updateDisplayStyle];
}

- (void)setTextInput:(id <UITextInput>)textInput {
    NSAssert([textInput conformsToProtocol:@protocol(UITextInput)], @"<XXTEKeyboardButton> The text input object must conform to the UITextInput protocol!");

    [self willChangeValueForKey:NSStringFromSelector(@selector(textInput))];
    _textInput = textInput;
    [self didChangeValueForKey:NSStringFromSelector(@selector(textInput))];
}

#pragma mark - Internal - UI

- (void)selectLabel:(int)idx {
    if (self.style == XXTEKeyboardButtonTypeTablet) {
        for (UILabel *label in self.labels) {
            [label setHighlighted:NO];
        }
    }
    if (idx == -1) {
        self.output = nil;
    } else {
        if (idx < self.labels.count) {
            UILabel *label = self.labels[(NSUInteger) idx];
            if (self.style == XXTEKeyboardButtonTypeTablet) {
                [label setHighlighted:YES];
            }
            self.output = label.text;
            [self.buttonView setNeedsDisplay];
        }
    }
}

- (void)showInputView {
    [self hideInputView];
    self.buttonView = [[XXTEKeyboardButtonView alloc] initWithKeyboardButton:self];
    [self.window addSubview:self.buttonView];
}

- (void)hideInputView {
    [self.buttonView removeFromSuperview];
    self.buttonView = nil;

    [self setNeedsDisplay];
}

- (void)updateDisplayStyle {
    switch (_style) {
        case XXTEKeyboardButtonTypePhone:
            _keyCornerRadius = 4.f;
            break;

        case XXTEKeyboardButtonTypeTablet:
            _keyCornerRadius = 6.f;
            break;

        default:
            break;
    }

    [self setNeedsDisplay];
}

#pragma mark - Internal - Text Handling

- (void)trackPointStarted {
    _startLocation = [_textInput caretRectForPosition:_textInput.selectedTextRange.start];
}

- (void)trackPointMovedX:(CGFloat)xdiff Y:(CGFloat)ydiff selecting:(BOOL)selecting {
    CGRect loc = _startLocation;

    loc.origin.y += ((UITextView *) _textInput).font.lineHeight;

    UITextPosition *p1 = [_textInput closestPositionToPoint:loc.origin];

    loc.origin.x -= xdiff;
    loc.origin.y -= ydiff;

    UITextPosition *p2 = [_textInput closestPositionToPoint:loc.origin];

    if (!selecting) {
        p1 = p2;
    }
    UITextRange *r = [_textInput textRangeFromPosition:p1 toPosition:p2];

    _textInput.selectedTextRange = r;
}

- (void)insertText:(NSString *)text {
    BOOL shouldInsertText = YES;

    if ([self.textInput isKindOfClass:[UITextView class]]) {
        // Call UITextViewDelegate methods if necessary
        UITextView *textView = (UITextView *) self.textInput;
        NSRange selectedRange = textView.selectedRange;

        if ([textView.delegate respondsToSelector:@selector(textView:shouldChangeTextInRange:replacementText:)]) {
            shouldInsertText = [textView.delegate textView:textView shouldChangeTextInRange:selectedRange replacementText:text];
        }
    } else if ([self.textInput isKindOfClass:[UITextField class]]) {
        // Call UITextFieldDelgate methods if necessary
        UITextField *textField = (UITextField *) self.textInput;
        NSRange selectedRange = [self textInputSelectedRange];

        if ([textField.delegate respondsToSelector:@selector(textField:shouldChangeCharactersInRange:replacementString:)]) {
            shouldInsertText = [textField.delegate textField:textField shouldChangeCharactersInRange:selectedRange replacementString:text];
        }
    }

    if (shouldInsertText) {
        [self.textInput insertText:text];
    }
}

- (NSRange)textInputSelectedRange {
    UITextPosition *beginning = self.textInput.beginningOfDocument;

    UITextRange *selectedRange = self.textInput.selectedTextRange;
    UITextPosition *selectionStart = selectedRange.start;
    UITextPosition *selectionEnd = selectedRange.end;

    const NSInteger location = [self.textInput offsetFromPosition:beginning toPosition:selectionStart];
    const NSInteger length = [self.textInput offsetFromPosition:selectionStart toPosition:selectionEnd];

    return NSMakeRange((NSUInteger) location, (NSUInteger) length);
}

- (void)selectionComplete {
    UIMenuController *menuController = [UIMenuController sharedMenuController];
    UITextRange *selectionRange = [_textInput selectedTextRange];
    CGRect selectionStartRect = [_textInput caretRectForPosition:selectionRange.start];
    CGRect selectionEndRect = [_textInput caretRectForPosition:selectionRange.end];
    CGPoint selectionCenterPoint = (CGPoint) {(selectionStartRect.origin.x + selectionEndRect.origin.x) / 2, (selectionStartRect.origin.y + selectionStartRect.size.height / 2)};
    [menuController setTargetRect:[_textInput caretRectForPosition:[_textInput closestPositionToPoint:selectionCenterPoint withinRange:selectionRange]] inView:(UITextView *) _textInput];
    [menuController setMenuVisible:YES animated:YES];
}

#pragma mark - Internal - Configuration

- (void)updateButtonPosition {
    // Determine the button sposition state based on the superview padding
    CGFloat leftPadding = CGRectGetMinX(self.frame);
    CGFloat rightPadding = CGRectGetMaxX(self.superview.frame) - CGRectGetMaxX(self.frame);
    CGFloat minimumClearance = CGRectGetWidth(self.frame) / 2 + 8;

    if (leftPadding >= minimumClearance && rightPadding >= minimumClearance) {
        self.position = XXTEKeyboardButtonPositionInner;
    } else if (leftPadding > rightPadding) {
        self.position = XXTEKeyboardButtonPositionLeft;
    } else {
        self.position = XXTEKeyboardButtonPositionRight;
    }
}

#pragma mark - Touch Handling

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch *t = [touches anyObject];
    _touchBeginPoint = [t locationInView:self];

    if (self.trackPoint) {
        _selecting = fabs([_firstTapDate timeIntervalSinceNow]) < TIME_INTERVAL_FOR_DOUBLE_TAP;
        _firstTapDate = [NSDate date];

        [self trackPointStarted];
    }

    if (self.style == XXTEKeyboardButtonTypePhone) {
        [self showInputView];
    }
    
    [self selectLabel:2];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch *t = [touches anyObject];
    CGPoint touchMovePoint = [t locationInView:self];

    CGFloat xdiff = _touchBeginPoint.x - touchMovePoint.x;
    CGFloat ydiff = _touchBeginPoint.y - touchMovePoint.y;
    CGFloat distance = (CGFloat) sqrt(xdiff * xdiff + ydiff * ydiff);

    if (_trackPoint) {
        [self trackPointMovedX:xdiff Y:ydiff selecting:_selecting];
        return;
    }

    if (distance > 250) {
        [self selectLabel:-1];
    } else if (distance > 20) {
        CGFloat angle = (CGFloat) atan2(xdiff, ydiff);

        if (angle >= 0 && angle < M_PI_2) {
            [self selectLabel:0];
        } else if (angle >= 0 && angle >= M_PI_2) {
            [self selectLabel:3];
        } else if (angle < 0 && angle > -M_PI_2) {
            [self selectLabel:1];
        } else if (angle < 0 && angle <= -M_PI_2) {
            [self selectLabel:4];
        }
    } else {
        [self selectLabel:2];
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesEnded:touches withEvent:event];

    if (self.output.length > 0) {
        if (self.trackPoint) {
            if (self.selecting) {
                [self selectionComplete];
            }
        }
        else if (self.actionPoint) {
            [[UIDevice currentDevice] playInputClick];
            unichar actionFlag = [self.output characterAtIndex:0];
            switch (actionFlag) {
                case 0xe800:
                    [_actionDelegate keyboardButton:self didTriggerAction:XXTEKeyboardButtonActionBackspace];
                    break;
                case 0xe801:
                    [_actionDelegate keyboardButton:self didTriggerAction:XXTEKeyboardButtonActionUndo];
                    break;
                case 0xe802:
                    [_actionDelegate keyboardButton:self didTriggerAction:XXTEKeyboardButtonActionRedo];
                    break;
                case 0xe803:
                    [self insertText:self.tabString];
                    break;
                case 0xe805:
                    [_actionDelegate keyboardButton:self didTriggerAction:XXTEKeyboardButtonActionKeyboardDismissal];
                    break;
                default:
                    break;
            }
        }
        else {
            [[UIDevice currentDevice] playInputClick];
            [self insertText:self.output];
        }
    }
    [self selectLabel:-1];

    if (self.style == XXTEKeyboardButtonTypePhone) {
        [self hideInputView];
    }
    
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesCancelled:touches withEvent:event];
    [self selectLabel:-1];
    if (self.style == XXTEKeyboardButtonTypePhone) {
        [self hideInputView];
    }
}

#pragma mark - Drawing

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    UIColor *color = [self isDarkMode] ? [UIColor colorWithWhite:1.f alpha:.3f] : [UIColor whiteColor];

    if (_style == XXTEKeyboardButtonTypeTablet && self.state == UIControlStateHighlighted) {
        color = [UIColor blackColor];
    }

    UIColor *shadow = [self isDarkMode] ? [UIColor clearColor] : [UIColor colorWithRed:136.f / 255.f green:138.f / 255.f blue:142.f / 255.f alpha:1.f];
    CGSize shadowOffset = CGSizeMake(0.1, 1.1);
    CGFloat shadowBlurRadius = 0;

    UIBezierPath *roundedRectanglePath =
            [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, self.frame.size.width, self.frame.size.height - 1) cornerRadius:self.keyCornerRadius];
    CGContextSaveGState(context);
    CGContextSetShadowWithColor(context, shadowOffset, shadowBlurRadius, shadow.CGColor);
    [color setFill];
    [roundedRectanglePath fill];
    CGContextRestoreGState(context);
}

- (void)setColorStyle:(XXTEKeyboardRowStyle)colorStyle {
    _colorStyle = colorStyle;
    UIColor *textColor = (colorStyle == XXTEKeyboardRowStyleDark) ? [UIColor whiteColor] : [UIColor blackColor];
    for (UILabel *label in self.labels) {
        [label setTextColor:textColor];
        [label setTintColor:textColor];
    }
    [self setNeedsDisplay];
}

- (BOOL)isDarkMode {
    return (self.colorStyle == XXTEKeyboardRowStyleDark);
}

@end
