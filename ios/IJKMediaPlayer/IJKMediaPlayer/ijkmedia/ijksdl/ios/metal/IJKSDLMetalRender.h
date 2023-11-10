//
//  IJKSDLMetalRender.h
//  IJKMediaPlayer
//
//  Created by hejianyuan on 2023/10/25.
//  Copyright © 2023 bilibili. All rights reserved.
//

#import <MetalKit/MetalKit.h>
#include "ijksdl/ijksdl_vout.h"

@class IJKSDLMetalView;

typedef NS_ENUM(NSUInteger, IJKSDLMetalRenderingResizingMode) {
    IJKSDLMetalRenderingResizingModeScale = 0,
    IJKSDLMetalRenderingResizingModeAspect,
    IJKSDLMetalRenderingResizingModeAspectFill,
};

@interface IJKSDLMetalRender : NSObject<MTKViewDelegate>

+ (instancetype)rendererWithOverlay:(SDL_VoutOverlay *)overlay metalView:(IJKSDLMetalView *)metalView;

@property (nonatomic, assign) IJKSDLMetalRenderingResizingMode renderingResizingMode;

@property (nonatomic, assign, readonly, getter=isVaild) BOOL valid;

@property (nonatomic, assign) Uint32 inputFormat;

- (instancetype)initWithMetalKitView:(IJKSDLMetalView *)mtkView;

- (BOOL)display:(SDL_VoutOverlay *)overlay;


@end


