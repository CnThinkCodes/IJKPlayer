/*
 * Copyright (c) 2003 Bilibili
 * Copyright (c) 2003 Fabrice Bellard
 * Copyright (c) 2015 Zhang Rui <bbcallen@gmail.com>
 *
 * This file is part of ijkPlayer.
 * Based on libavformat/allformats.c
 *
 * FFmpeg is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * FFmpeg is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with FFmpeg; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 */

#include "libavformat/avformat.h"
#include "libavformat/url.h"
#include "libavformat/version.h"
#include "libavformat/avio_internal.h"
#include "libavformat/avformat.h"
#include "libavformat/internal.h"
#include "libavutil/avstring.h"


#define IJK_REGISTER_DEMUXER(x)                                                     \
{                                                                                   \
    extern AVInputFormat ijkff_##x##_demuxer;                                       \
    int ijkav_register_##x##_demuxer(AVInputFormat *demuxer, int demuxer_size);     \
    ijkav_register_##x##_demuxer(&ijkff_##x##_demuxer, sizeof(AVInputFormat));      \
}

#define IJK_REGISTER_PROTOCOL(x)                                                    \
{                                                                                   \
    extern URLProtocol ijkimp_ff_##x##_protocol;                                    \
    int ijkav_register_##x##_protocol(URLProtocol *protocol, int protocol_size);    \
    ijkav_register_##x##_protocol(&ijkimp_ff_##x##_protocol, sizeof(URLProtocol));  \
}

static const struct AVInputFormat *ijkav_find_input_format(const char *iformat_name)
{
    const AVInputFormat *fmt = NULL;
    void *i = 0;
    while ((fmt = av_demuxer_iterate(&i)))
        if (av_match_name(iformat_name, fmt->name))
            return fmt;
    return NULL;
}

static void ijkav_register_input_format(AVInputFormat *iformat)
{
    if (ijkav_find_input_format(iformat->name)) {
        av_log(NULL, AV_LOG_WARNING, "skip     demuxer : %s (duplicated)\n", iformat->name);
    } else {
        av_log(NULL, AV_LOG_INFO,    "register demuxer : %s\n", iformat->name);
    }
    
    if(!ijkav_find_input_format(iformat->name)){
        //    av_register_input_format(iformat);
    }
}


void ijkav_register_all(void){
    static int initialized;

    if (initialized) return;
    
    initialized = 1;

    /* protocols */
    av_log(NULL, AV_LOG_INFO, "===== custom modules begin =====\n");
#ifdef __ANDROID__
    IJK_REGISTER_PROTOCOL(ijkmediadatasource);
#endif
    IJK_REGISTER_PROTOCOL(ijkio);
    IJK_REGISTER_PROTOCOL(async);
    IJK_REGISTER_PROTOCOL(ijklongurl);
    IJK_REGISTER_PROTOCOL(ijktcphook);
    IJK_REGISTER_PROTOCOL(ijkhttphook);
    IJK_REGISTER_PROTOCOL(ijksegment);
    /* demuxers */
    IJK_REGISTER_DEMUXER(ijklivehook);
    IJK_REGISTER_DEMUXER(ijklas);
    av_log(NULL, AV_LOG_INFO, "===== custom modules end =====\n");
}
