//
//  yuv420p10le.fsh.c
//  IJKMediaPlayer
//
//  Created by hejianyuan on 2023/10/19.
//  Copyright © 2023 bilibili. All rights reserved.
//

#include "ijksdl/gles2/internal.h"

static const char g_shader[] = IJK_GLES_STRING(
    precision highp float;
    varying   highp vec2 vv2_Texcoord;
    uniform         mat3 um3_ColorConversion;
    uniform   lowp  sampler2D us2_SamplerX;
    uniform   lowp  sampler2D us2_SamplerY;
    uniform   lowp  sampler2D us2_SamplerZ;

    void main()
    {
        mediump vec3 yuv_l;
        mediump vec3 yuv_h;
        mediump vec3 yuv;
        lowp    vec3 rgb;

        yuv_l.x = texture2D(us2_SamplerX, vv2_Texcoord).r;
        yuv_h.x = texture2D(us2_SamplerX, vv2_Texcoord).a;
        yuv_l.y = texture2D(us2_SamplerY, vv2_Texcoord).r;
        yuv_h.y = texture2D(us2_SamplerY, vv2_Texcoord).a;
        yuv_l.z = texture2D(us2_SamplerZ, vv2_Texcoord).r;
        yuv_h.z = texture2D(us2_SamplerZ, vv2_Texcoord).a;

        yuv = (yuv_l * 255.0 + yuv_h * 255.0 * 256.0) / (1023.0) - vec3(16.0 / 255.0, 0.5, 0.5);
        rgb = um3_ColorConversion * yuv;
        
        gl_FragColor = vec4(rgb, 1);
    }
);


const char *IJK_GLES2_getFragmentShader_yuv420p10le(){
    return g_shader;
}
