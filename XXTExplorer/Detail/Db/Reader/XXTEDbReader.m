//
//  XXTEDbReader.m
//  XXTExplorer
//
//  Created by Zheng on 10/01/2018.
//  Copyright © 2018 Zheng. All rights reserved.
//

#import "XXTEDbReader.h"
#import "XXTEDbTableListViewController.h"

@implementation XXTEDbReader

@synthesize metaDictionary = _metaDictionary;
@synthesize entryPath = _entryPath;
@synthesize entryName = _entryName;
@synthesize entryDisplayName = _entryDisplayName;
@synthesize entryIconImage = _entryIconImage;
@synthesize metaKeys = _metaKeys;
@synthesize entryDescription = _entryDescription;
@synthesize entryExtensionDescription = _entryExtensionDescription;
@synthesize entryViewerDescription = _entryViewerDescription;
@synthesize executable = _executable;
@synthesize editable = _editable;
@synthesize encryptionType = _encryptionType;

+ (NSArray <NSString *> *)supportedExtensions {
    return [XXTEDbTableListViewController suggestedExtensions];
}

+ (UIImage *)defaultImage {
    return [UIImage imageNamed:@"XXTEFileReaderType-Db"];
}

+ (Class)relatedEditor {
    return nil;
}

- (instancetype)initWithPath:(NSString *)filePath {
    if (self = [super init]) {
        _entryPath = filePath;
        [self setupWithPath:filePath];
    }
    return self;
}

- (void)setupWithPath:(NSString *)path {
    _executable = NO;
    _editable = NO;
    NSString *entryExtension = [path pathExtension];
    NSString *entryBaseExtension = [entryExtension lowercaseString];
    UIImage *iconImage = [self.class defaultImage];
    {
        UIImage *extensionIconImage = [UIImage imageNamed:[NSString stringWithFormat:kXXTEFileTypeImageNameFormat, entryBaseExtension]];
        if (extensionIconImage) {
            iconImage = extensionIconImage;
        }
    }
    _entryIconImage = iconImage;
    _entryExtensionDescription = @"SQLite Database";
    _entryViewerDescription = [XXTEDbTableListViewController viewerName];
}

@end
