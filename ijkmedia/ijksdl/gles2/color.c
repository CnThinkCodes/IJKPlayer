/*
 * Copyright (c) 2016 Bilibili
 * copyright (c) 2016 Zhang Rui <bbcallen@gmail.com>
 *
 * This file is part of ijkPlayer.
 *
 * ijkPlayer is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * ijkPlayer is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with ijkPlayer; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 */

#include "internal.h"

// BT.709, which is the standard for HDTV.
// BT.709 limited range YUV to RGB reference
//static void YUVHToRGBReference(int y, int u, int v, int* r, int* g, int* b) {
//  *r = RoundToByte((y - 16) * 1.164 - (v - 128) * -1.793);
//  *g = RoundToByte((y - 16) * 1.164 - (u - 128) * 0.213 - (v - 128) * 0.533);
//  *b = RoundToByte((y - 16) * 1.164 - (u - 128) * -2.112);
//}
static const GLfloat g_bt709[] = {
    1.164,  1.164,  1.164,
    0.0,   -0.213,  2.112,
    1.793, -0.533,  0.0,
};

const GLfloat *IJK_GLES2_getColorMatrix_bt709(){
    return g_bt709;
}


// BT.601
// BT.601 limited range YUV to RGB reference
//static void YUVToRGBReference(int y, int u, int v, int* r, int* g, int* b) {
//  *r = RoundToByte((y - 16) * 1.164 - (v - 128) * -1.596);
//  *g = RoundToByte((y - 16) * 1.164 - (u - 128) * 0.391 - (v - 128) * 0.813);
//  *b = RoundToByte((y - 16) * 1.164 - (u - 128) * -2.018);
//}
static const GLfloat g_bt601[] = {
    1.164,  1.164, 1.164,
    0.0,   -0.391, 2.018,
    1.596, -0.813, 0.0,
};

const GLfloat *IJK_GLES2_getColorMatrix_bt601(){
    return g_bt601;
}


// BT.2020
// BT.2020 limited range YUV to RGB reference
//static void YUVUToRGBReference(int y, int u, int v, int* r, int* g, int* b) {
//  *r = RoundToByte((y - 16) * 1.164384 - (v - 128) * -1.67867);
//  *g = RoundToByte((y - 16) * 1.164384 - (u - 128) * 0.187326 - (v - 128) * 0.65042);
//  *b = RoundToByte((y - 16) * 1.164384 - (u - 128) * -2.14177);
//}
static const GLfloat g_bt2020[] = {
    1.164384,   1.164384,   1.164384,
    0.0,       -0.187326,   2.14177,
    1.67867,   -0.65042,    0.0,
};

const GLfloat *IJK_GLES2_getColorMatrix_bt2020()
{
    return g_bt2020;
}

