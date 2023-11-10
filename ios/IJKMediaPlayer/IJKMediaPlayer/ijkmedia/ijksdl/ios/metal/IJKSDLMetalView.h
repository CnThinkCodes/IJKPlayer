//
//  IJKSDLMetalView.h
//  IJKMediaPlayer
//
//  Created by hejianyuan on 2023/10/25.
//  Copyright © 2023 bilibili. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import "IJKSDLGLViewProtocol.h"
#include "ijksdl/ijksdl_vout.h"

@interface IJKSDLMetalView : MTKView <IJKSDLGLViewProtocol>{
    @public
    MTLClearColor _clearColor;
}

- (id)initWithFrame:(CGRect)frame;

- (void)display:(SDL_VoutOverlay *)overlay;

- (UIImage*)snapshot;

@end

