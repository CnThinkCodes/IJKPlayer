//
//  ijksdl_vout_ios_samplebuffer_displaylayer.h
//  IJKMediaPlayer
//
//  Created by hejianyuan on 2023/10/20.
//  Copyright © 2023 bilibili. All rights reserved.
//

#include "ijksdl/ijksdl_stdinc.h"
#include "ijksdl/ijksdl_vout.h"

@class IJKSDLGLView;

SDL_Vout *SDL_VoutIos_CreateForGLES2();
void SDL_VoutIos_SetGLView(SDL_Vout *vout, IJKSDLGLView *view);
