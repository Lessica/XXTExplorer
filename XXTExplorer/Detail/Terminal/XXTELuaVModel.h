//
//  XXTELuaVModel.h
//  XXTouchApp
//
//  Created by Zheng on 31/10/2016.
//  Copyright © 2016 Zheng. All rights reserved.
//

#import "XXTLuaNSValue.h"
#import <Foundation/Foundation.h>

@class XXTELuaVModel;

@protocol XXTELuaVModelDelegate <NSObject>
- (void)virtualMachineDidChangedState:(XXTELuaVModel *)vm;

@end

@interface XXTELuaVModel : NSObject
@property (nonatomic, weak) id<XXTELuaVModelDelegate> delegate;

@property (nonatomic, assign) FILE *stdoutHandler;
@property (nonatomic, assign) FILE *stderrHandler;
@property (nonatomic, assign) FILE *stdinReadHandler;
@property (nonatomic, assign) FILE *stdinWriteHandler;

@property (nonatomic, strong) NSPipe *outputPipe;
@property (nonatomic, strong) NSPipe *inputPipe;
@property (nonatomic, strong) NSPipe *errorPipe;

@property (nonatomic, assign) BOOL running;

- (void)setFakeIOEnabled:(BOOL)enabled;
- (BOOL)loadFileFromPath:(NSString *)path error:(NSError **)error;
- (BOOL)loadBufferFromString:(NSString *)string error:(NSError **)error;
- (BOOL)pcallWithError:(NSError **)error;

@end
