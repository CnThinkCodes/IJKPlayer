//
//  renderer_yuv420p10le.c
//  IJKMediaPlayer
//
//  Created by hejianyuan on 2023/10/19.
//  Copyright © 2023 bilibili. All rights reserved.
//

#include "internal.h"

static GLboolean yuv420p10le_use(IJK_GLES2_Renderer *renderer){
    ALOGI("use render yuv420p10le\n");
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);

    glUseProgram(renderer->program);            IJK_GLES2_checkError_TRACE("glUseProgram");

    if (0 == renderer->plane_textures[0])
        glGenTextures(3, renderer->plane_textures);

    for (int i = 0; i < 3; ++i) {
        glActiveTexture(GL_TEXTURE0 + i);
        glBindTexture(GL_TEXTURE_2D, renderer->plane_textures[i]);

        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

        glUniform1i(renderer->us2_sampler[i], i);
    }

    glUniformMatrix3fv(renderer->um3_color_conversion, 1, GL_FALSE, IJK_GLES2_getColorMatrix_bt2020());

    return GL_TRUE;
}

static GLsizei yuv420p10le_getBufferWidth(IJK_GLES2_Renderer *renderer, SDL_VoutOverlay *overlay){
    if (!overlay)
        return 0;

    return overlay->pitches[0] / 2;
}

static GLboolean yuv420p10le_uploadTexture(IJK_GLES2_Renderer *renderer, SDL_VoutOverlay *overlay){
    if (!renderer || !overlay)
        return GL_FALSE;

    int     planes[3]    = { 0, 1, 2 };
    const GLubyte *pixels[3] = { overlay->pixels[0],  overlay->pixels[1], overlay->pixels[2]};
    const GLsizei widths[3] = { overlay->pitches[0]/2, overlay->pitches[1]/2, overlay->pitches[2]/2};
    const GLsizei heights[3] = { overlay->h, overlay->h/2, overlay->h/2};
    
    switch (overlay->format) {
        case SDL_FCC_I420P10LE:
            break;
        default:
            ALOGE("[yuv420p10le] unexpected format %x\n", overlay->format);
            return GL_FALSE;
    }
    
    for (int i = 0; i < 3; ++i) {
        int plane = planes[i];

        glBindTexture(GL_TEXTURE_2D, renderer->plane_textures[i]);

        glTexImage2D(GL_TEXTURE_2D,
                     0,
                     GL_LUMINANCE_ALPHA,
                     widths[plane],
                     heights[plane],
                     0,
                     GL_LUMINANCE_ALPHA,
                     GL_UNSIGNED_BYTE,
                     pixels[plane]);
    }

    return GL_TRUE;
}

IJK_GLES2_Renderer *IJK_GLES2_Renderer_create_yuv420p10le(){
    ALOGI("create render yuv420p10le\n");
    IJK_GLES2_Renderer *renderer = IJK_GLES2_Renderer_create_base(IJK_GLES2_getFragmentShader_yuv420p10le());
    if (!renderer)
        goto fail;

    renderer->us2_sampler[0] = glGetUniformLocation(renderer->program, "us2_SamplerX"); IJK_GLES2_checkError_TRACE("glGetUniformLocation(us2_SamplerX)");
    renderer->us2_sampler[1] = glGetUniformLocation(renderer->program, "us2_SamplerY"); IJK_GLES2_checkError_TRACE("glGetUniformLocation(us2_SamplerY)");
    renderer->us2_sampler[2] = glGetUniformLocation(renderer->program, "us2_SamplerZ"); IJK_GLES2_checkError_TRACE("glGetUniformLocation(us2_SamplerZ)");

    renderer->um3_color_conversion = glGetUniformLocation(renderer->program, "um3_ColorConversion"); IJK_GLES2_checkError_TRACE("glGetUniformLocation(um3_ColorConversionMatrix)");

    renderer->func_use            = yuv420p10le_use;
    renderer->func_getBufferWidth = yuv420p10le_getBufferWidth;
    renderer->func_uploadTexture  = yuv420p10le_uploadTexture;

    return renderer;
fail:
    IJK_GLES2_Renderer_free(renderer);
    return NULL;
}
