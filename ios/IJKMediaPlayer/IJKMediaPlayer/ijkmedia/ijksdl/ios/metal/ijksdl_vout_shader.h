//
//  ijksdl_vout_shader_type.h
//  IJKMediaPlayer
//
//  Created by hejianyuan on 2023/10/25.
//  Copyright © 2023 bilibili. All rights reserved.
//

#ifndef ijksdl_vout_shader_h
#define ijksdl_vout_shader_h

typedef struct {
    vector_float4 position;
    vector_float2 textureCoordinate;
} IJKSDLMetalVertex;

typedef struct{
    float maximumEDRPotentialValue;
}IJKSDLMetalEDRUnit;


NSString* IJK_METAL_SHADER_STRING();

#endif /* ijksdl_vout_shader_h */
