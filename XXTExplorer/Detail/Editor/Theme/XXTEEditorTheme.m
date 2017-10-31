//
//  XXTEEditorTheme.m
//  XXTExplorer
//
//  Created by Zheng Wu on 11/08/2017.
//  Copyright © 2017 Zheng. All rights reserved.
//

#import "XXTEEditorTheme.h"
#import "UIColor+SKColor.h"

#import "SKTheme.h"

@interface XXTEEditorTheme ()

@property (nonatomic, strong) NSParagraphStyle *paragraphStyle;

@end

@implementation XXTEEditorTheme

- (instancetype)initWithName:(NSString *)name font:(UIFont *)font {
    if (self = [super init]) {
        _font = font ? font : [UIFont systemFontOfSize:14.0];
        _name = name ? name : @"";
        _backgroundColor = UIColor.whiteColor;
        _foregroundColor = UIColor.blackColor;
        _caretColor = XXTE_COLOR;
        _selectionColor = XXTE_COLOR;
        _invisibleColor = UIColor.blackColor;
        
        NSString *themeMetasPath = [[NSBundle mainBundle] pathForResource:@"SKTheme" ofType:@"plist"];
        assert(themeMetasPath);
        NSArray *themeMetas = [[NSArray alloc] initWithContentsOfFile:themeMetasPath];
        assert([themeMetas isKindOfClass:[NSArray class]]);
        BOOL registered = NO;
        for (NSDictionary *themeMeta in themeMetas) {
            if ([themeMeta[@"name"] isEqualToString:name]) {
                registered = YES;
                break;
            }
        }
        assert(registered);
        
        NSString *themePath = [[NSBundle mainBundle] pathForResource:name ofType:@"tmTheme"];
        assert(themePath);
        NSDictionary *themeDictionary = [[NSDictionary alloc] initWithContentsOfFile:themePath];
        assert([themeDictionary isKindOfClass:[NSDictionary class]]);
        NSArray <NSDictionary *> *themeSettings = themeDictionary[@"settings"];
        assert([themeSettings isKindOfClass:[NSArray class]]);
        NSDictionary *globalTheme = nil;
        for (NSDictionary *themeSetting in themeSettings) {
            if (!themeSetting[@"scope"]) {
                globalTheme = themeSetting[@"settings"];
                break;
            }
        }
        assert([globalTheme isKindOfClass:[NSDictionary class]]);
        [self setupWithDictionary:globalTheme];
        
        SKTheme *rawTheme = [[SKTheme alloc] initWithDictionary:themeDictionary font:font];
        assert(rawTheme);
        _rawTheme = rawTheme;
    }
    return self;
}

- (void)setupWithDictionary:(NSDictionary *)dictionary {
    UIColor *backgroundColor = [UIColor colorWithHex:dictionary[@"background"]];
    _backgroundColor = backgroundColor;
    
    UIColor *foregroundColor = [UIColor colorWithHex:dictionary[@"foreground"]];
    _foregroundColor = foregroundColor;
    
    UIColor *caretColor = [UIColor colorWithHex:dictionary[@"caret"]];
    _caretColor = caretColor;
    
    UIColor *selectionColor = [UIColor colorWithHex:dictionary[@"selection"]];
    _selectionColor = selectionColor;
    
    UIColor *invisibleColor = [UIColor colorWithHex:dictionary[@"invisibles"]];
    _invisibleColor = invisibleColor;
    
    UIFont *font = self.font;
    NSDictionary *defaultAttributes = @{
                                        NSForegroundColorAttributeName: foregroundColor,
                                        NSBackgroundColorAttributeName: backgroundColor,
                                        NSFontAttributeName: font,
                                        };
    _tabWidth = [@" " sizeWithAttributes:defaultAttributes].width;
    
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
//    paragraphStyle.minimumLineHeight = font.pointSize;
//    paragraphStyle.maximumLineHeight = font.pointSize;
    paragraphStyle.lineBreakMode = NSLineBreakByWordWrapping;
    paragraphStyle.alignment = NSTextAlignmentLeft;
    _paragraphStyle = [paragraphStyle copy];
    
    
}

- (NSDictionary *)defaultAttributes {
    return @{
             NSForegroundColorAttributeName: self.foregroundColor,
             NSBackgroundColorAttributeName: self.backgroundColor,
             NSFontAttributeName: self.font,
             NSParagraphStyleAttributeName: self.paragraphStyle,
             };
}

@end