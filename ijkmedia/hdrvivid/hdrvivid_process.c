//
//  hdrvivid_process.c
//  IJKMediaFramework
//
//  Created by hejianyuan on 2023/11/6.
//  Copyright © 2023 bilibili. All rights reserved.
//

#include "hdrvivid_process.h"
#include<math.h>

int initHDRVividMetadata(AVDynamicHDRVivid* sideMetadata, IJKHDRVividMetadata *vividMetadata){
    int errorno = 0;
    
    vividMetadata->system_start_code = sideMetadata->system_start_code;
    int numWindows = 0;
    if (sideMetadata->system_start_code == 1) {
        numWindows = 1;
    }
    
    for (int i = 0; i < numWindows; i++) {
        vividMetadata->minimum_maxrgb =  sideMetadata->params[i].minimum_maxrgb.num;
        vividMetadata->average_maxrgb = sideMetadata->params[i].average_maxrgb.num;
        vividMetadata->variance_maxrgb = sideMetadata->params[i].variance_maxrgb.num;
        vividMetadata->maximum_maxrgb = sideMetadata->params[i].maximum_maxrgb.num;
    }
    
    for (int i = 0; i < numWindows; i++) {
        vividMetadata->tone_mapping_mode = sideMetadata->params[i].tone_mapping_mode_flag;
        if (vividMetadata->tone_mapping_mode) {
            vividMetadata->tone_mapping_param_num = sideMetadata->params[i].tone_mapping_param_num-1;
            vividMetadata->tone_mapping_param_num++;
            
            if (vividMetadata->tone_mapping_param_num > 2) {
                errorno = 1;
                return errorno;
            }
            for (unsigned int j = 0; j < vividMetadata->tone_mapping_param_num; j++) {
                AVHDRVividColorToneMappingParams* tm_params = &(sideMetadata->params[i].tm_params[j]);
                
                vividMetadata->targeted_system_display_maximum_luminance[j] = tm_params->targeted_system_display_maximum_luminance.num;
                vividMetadata->Base_flag[j] = tm_params->base_enable_flag;
                if (vividMetadata->Base_flag[j]) {
                    vividMetadata->Base_param_m_p[j] = tm_params->base_param_m_p.num;
                    vividMetadata->Base_param_m_m[j] = tm_params->base_param_m_m.num;
                    vividMetadata->Base_param_m_a[j] = tm_params->base_param_m_a.num;
                    vividMetadata->Base_param_m_b[j] = tm_params->base_param_m_b.num;
                    vividMetadata->Base_param_m_n[j] = tm_params->base_param_m_n.num;
                    vividMetadata->Base_param_K1[j] = tm_params->base_param_k1;
                    vividMetadata->Base_param_K2[j] = tm_params->base_param_k2;
                    vividMetadata->Base_param_K3[j] = tm_params->base_param_k3;
                    vividMetadata->base_param_Delta_mode[j] = tm_params->base_param_Delta_enable_mode;
                    if (vividMetadata->base_param_Delta_mode[j] == 2 || vividMetadata->base_param_Delta_mode[j] == 6)
                        vividMetadata->base_param_Delta[j] = (-1)*tm_params->base_param_Delta.num;
                    else
                        vividMetadata->base_param_Delta[j] = tm_params->base_param_Delta.num;
                    
                }
                printf(" tm_params-j=%d  metadata.P3Spline_num[j].num=%d \n", j, vividMetadata->P3Spline_num[j]);
                vividMetadata->P3Spline_flag[j] = tm_params->three_Spline_enable_flag;
                if (vividMetadata->P3Spline_flag[j]) {
                    vividMetadata->P3Spline_num[j] = tm_params->three_Spline_num-1;
                    vividMetadata->P3Spline_num[j]++;
                    if (vividMetadata->P3Spline_num[j] > 2) {
                        errorno = 1;
                        return errorno;
                    }
                    printf(" tm_params-j=%d  metadata.P3Spline_num[j].num=%d \n", j, vividMetadata->P3Spline_num[j]);
                    for (unsigned int mode_i = 0; mode_i < vividMetadata->P3Spline_num[j]; mode_i++) {
                        vividMetadata->P3Spline_TH_mode[j][mode_i] = tm_params->three_Spline_TH_mode[mode_i];
                        if ((vividMetadata->P3Spline_TH_mode[j][mode_i] == 0) ||
                            (vividMetadata->P3Spline_TH_mode[j][mode_i] == 2)) {
                            vividMetadata->P3Spline_TH_MB[j][mode_i] = tm_params->three_Spline_TH_enable_MB[mode_i].num;
                        }
                        vividMetadata->P3Spline_TH[j][mode_i][0] = tm_params->three_Spline_TH_enable[mode_i].num;
                        vividMetadata->P3Spline_TH[j][mode_i][1] = tm_params->three_Spline_TH_Delta1[mode_i].num;
                        vividMetadata->P3Spline_TH[j][mode_i][2] = tm_params->three_Spline_TH_Delta2[mode_i].num;
                        
                        vividMetadata->P3Spline_Strength[j][mode_i] = tm_params->three_Spline_enable_Strength[mode_i].num;
                        printf("\n j=%d,mode_i=%d,tm_params->three_Spline_TH_enable.num=%d tm_params->three_Spline_TH_Delta1.num=%d tm_params->three_Spline_TH_Delta2.num=%d tm_params->three_Spline_enable_Strength.num=%d \n",j, mode_i, vividMetadata->P3Spline_TH[j][mode_i][0], vividMetadata->P3Spline_TH[j][mode_i][1]
                               , vividMetadata->P3Spline_TH[j][mode_i][2], vividMetadata->P3Spline_Strength[j][mode_i]);
                    }
                }//if (metadata.P3Spline_flag[j]) {
                else { /////////////yuquanhe//////////////////////
                    vividMetadata->P3Spline_num[j] = 1;
                    vividMetadata->P3Spline_TH_mode[j][0] = 0;
                    vividMetadata->P3Spline_TH_mode[j][1] = 0;
                }
                
            }//for (unsigned int j = 0; j < metadata.tone_mapping_param_num; j++) {
        }//if (metadata.tone_mapping_mode) {
        
        vividMetadata->color_saturation_mapping_flag = sideMetadata->params[i].color_saturation_mapping_flag;
        if (vividMetadata->color_saturation_mapping_flag) {
            vividMetadata->color_saturation_num = sideMetadata->params[i].color_saturation_num;
            if (vividMetadata->color_saturation_num > 8) {
                errorno = 1;
                return errorno;
            }
            for (unsigned int mode_i = 0; mode_i < vividMetadata->color_saturation_num; mode_i++) {
                vividMetadata->color_saturation_gain[mode_i] = sideMetadata->params[i].color_saturation_gain[mode_i].num;
            }
        }
    }
    return errorno;
}



////
///
///
#define TPA_NUM      4
float TPA[TPA_NUM][2] = { { 2.5,0.99 },{ 3.5,0.879 },{ 4.5,0.777 },{ 7.5,0.54 } };
float getBaseCurveParameterAdjust(IJKHDRVividCurve* curve)
{
    int index = 0;
    float M_a_T = TPA[0][1];
    for (int i = 0; i < TPA_NUM; i++)
    {
        if (curve->m_p <= TPA[i][0])
        {
            index = i;
            break;
        }
    }
    if ((index == 0) && (curve->m_p < TPA[0][0])) M_a_T = TPA[0][1];
    else if ((index == 0) && (curve->m_p > TPA[(TPA_NUM - 1)][0])) M_a_T = TPA[(TPA_NUM - 1)][1];
    else
    {
        float temp1 = curve->m_p - TPA[index - 1][0];
        float temp2 = TPA[index][0] - curve->m_p;
        M_a_T = TPA[index][1] * temp1 + TPA[index - 1][1] * temp2;
        M_a_T /= (temp1 + temp2);
    }
    curve->curve_adjust = 0;
    if (curve->m_a > M_a_T)
    {
        curve->m_a = curve->m_a_T = M_a_T;
        curve->curve_adjust = 1;
        curve->m_b = 0;
    }
    return curve->curve_adjust;
}
void AdjustVividParameter(float m_maxE,
                          float m_inputMaxE,
                          IJKHDRVividCurve* curve)
{
    if (curve->curve_adjust == 0) return;
    if ((curve->m_m < 2.35) || (curve->m_m > 2.45) || (curve->m_n < 0.95) || (curve->m_n > 1.05))
    {
        return;
    }
    if (m_inputMaxE < m_maxE) m_inputMaxE = m_maxE;
    float temp1 = m_maxE / m_inputMaxE;
    float max1 = (curve->m_p) * pow(m_inputMaxE, curve->m_n);
    float temp = (((curve->m_p) * (curve->K1) - (curve->K2)) * (pow(m_inputMaxE, curve->m_n)) + (curve->K3));
    if (temp)  max1 /= temp;
    max1 = (curve->m_a_T) * pow(max1, curve->m_m) + (curve->m_b);
    float temp2 = max1 / m_inputMaxE;
    
    float WA = temp1 - temp2;
    if (WA < 0) WA = 0;
    WA /= (1 - temp2);
    
    if (curve->curve_mintiao)
    {
        temp = (1 - (curve->DARKcurble_S1)) * WA;
        curve->DARKcurble_S1 += temp;
        
        float TH1temp = curve->TH1;
        float TH2temp = curve->TH2;
        float TH3temp = curve->TH3;
        temp = (m_inputMaxE - (curve->TH1)) * WA;
        curve->TH1 += temp;
        curve->TH2 = curve->TH1 + TH2temp - TH1temp;
        curve->TH3 = curve->TH2 + TH3temp - TH2temp;
        curve->m_b *= (1 - WA);
    }
    else
    {
        
    }
}
float spline_area_spec(float maximum_maxrgb,
                        float average_maxrgb,
                        float tone_mapping_param_m_p,
                        float tone_mapping_param_m_m,
                        float tone_mapping_param_m_a,
                        float* tone_mapping_param_m_b,
                        float tone_mapping_param_m_n,
                        float tone_mapping_param_K1,
                        float tone_mapping_param_K2,
                        float tone_mapping_param_K3,
                        float P3Spline_TH_MB,
                        float P3Spline_TH[3],
                        float P3Spline_Strength,
                        float maxDisplay,
                        float* md1g,
                        float* mc1g,
                        float* mb1g,
                        float* ma1g,
                        float* md2g,
                        float* mc2g,
                        float* mb2g,
                        float* ma2g,
                        float* dark,
                        float* DARKcurble_offset,
                        int* curve_mintiao,
                        unsigned int base_param_Delta_mode)

{
    float threshold1 = 0.0;
    float threshold2 = 0.0;
    float threshold3 = 0.0;
    
    float m_ptemp = tone_mapping_param_m_p;
    float m_mtemp = tone_mapping_param_m_m;
    float m_atemp = tone_mapping_param_m_a;
    float m_btemp = *tone_mapping_param_m_b;
    float m_ntemp = tone_mapping_param_m_n;
    float K1temp = tone_mapping_param_K1;
    float K2temp = tone_mapping_param_K2;
    float K3temp = tone_mapping_param_K3;
    
    float meta_str = P3Spline_Strength;
    float meta_MB = P3Spline_TH_MB;
    float s1 = meta_MB;
    
    threshold1 = P3Spline_TH[0];
    threshold2 = P3Spline_TH[1];
    threshold3 = P3Spline_TH[2];
    
    float threshold3temp = pow(threshold3, m_ntemp);
    float threshold3temp1 = pow(threshold3, (m_ntemp - 1));
    float s2 = (m_ptemp * threshold3temp / ((K1temp * m_ptemp - K2temp) * threshold3temp + K3temp));
    s2 = pow(s2, m_mtemp + 1);
    s2 = (m_atemp * m_mtemp * m_ptemp * K3temp * m_ntemp * threshold3temp1 * s2 * (1 / pow(threshold3temp * m_ptemp, 2)));
    
    float a1 = s1 * threshold1 + *DARKcurble_offset;
    float b1 = s1;
    
    float h1 = threshold2 - threshold1;
    float h2 = threshold3 - threshold2;
    
    float y2 = (m_ptemp * threshold3temp / ((K1temp * m_ptemp - K2temp) * threshold3temp + K3temp));
    y2 = pow(y2, m_mtemp);
    y2 = m_atemp * y2 + m_btemp;
    
    if (y2 > threshold3 && base_param_Delta_mode != 3 && base_param_Delta_mode != 2 && base_param_Delta_mode != 6)
    {
        m_btemp = m_btemp - (y2 - threshold3);
        y2 = threshold3;
        *tone_mapping_param_m_b = m_btemp;
    }
    float a2 = a1 + (y2 - a1) * (threshold2 - threshold1) / (threshold3 - threshold1) + (y2 - a1) * meta_str / 2;
    if (a2 > threshold2 && base_param_Delta_mode != 3 && base_param_Delta_mode != 2 && base_param_Delta_mode != 6)
    {
        a2 = threshold2;
    }
    float y1 = a2;
    
    float b2 = -(3.0 * a1 * h2 * h2 + 3.0 * a2 * h1 * h1 - 3.0 * h1 * h1 * y2 - 3.0 * h2 * h2 * y1 + h1 * h1 * h2 * s2 + b1 * h1 * h2 * h2) / (2.0 * h2 * (h1 * h1 + h2 * h1));
    
    float c1 = (3.0 * y1 - 2.0 * b1 * h1 - 3.0 * a1 - b2 * h1) / (h1 * h1);
    float d1 = (h1 * b1 + h1 * b2 + 2 * a1 - 2.0 * y1) / (h1 * h1 * h1);
    float c2 = c1 + 3.0 * d1 * h1;
    float d2 = -(y2 - a2 - h2 * s2 + c1 * h2 * h2 + 3 * d1 * h1 * h2 * h2) / (2 * h2 * h2 * h2);
    
    P3Spline_TH[0] = threshold1;
    P3Spline_TH[1] = threshold2;
    P3Spline_TH[2] = threshold3;
    *md1g = d1, * mc1g = c1, * mb1g = b1, * ma1g = a1;
    *md2g = d2, * mc2g = c2, * mb2g = b2, * ma2g = a2;
    *dark = s1;
    
    *curve_mintiao = 1;
    return *curve_mintiao;
}

float spline_higharea_spec(float maximum_maxrgb,
                            float average_maxrgb,
                            float tone_mapping_param_m_p,
                            float tone_mapping_param_m_m,
                            float tone_mapping_param_m_a,
                            float tone_mapping_param_m_b,
                            float tone_mapping_param_m_n,
                            float tone_mapping_param_K1,
                            float tone_mapping_param_K2,
                            float tone_mapping_param_K3,
                            int   P3Spline_TH_Mode,
                            float P3Spline_TH_MB,
                            float P3Spline_TH[3],
                            float P3Spline_Strength,
                            float maxDisplay,
                            float* md1g,
                            float* mc1g,
                            float* mb1g,
                            float* ma1g,
                            float* md2g,
                            float* mc2g,
                            float* mb2g,
                            float* ma2g,
                            float* dark,
                            int* curve_mintiao_high_area,
                            float Referncedisplay,
                            unsigned int base_param_Delta_mode)
{
    float threshold1 = P3Spline_TH[0];
    float threshold2 = P3Spline_TH[1];
    float threshold3 = P3Spline_TH[2];
    float meta_str = P3Spline_Strength;
    
    float m_ptemp = tone_mapping_param_m_p;
    float m_mtemp = tone_mapping_param_m_m;
    float m_atemp = tone_mapping_param_m_a;
    float m_btemp = tone_mapping_param_m_b;
    float m_ntemp = tone_mapping_param_m_n;
    float K1temp = tone_mapping_param_K1;
    float K2temp = tone_mapping_param_K2;
    float K3temp = tone_mapping_param_K3;
    
    float threshold1temp = pow(threshold1, m_ntemp);
    float threshold1temp1 = pow(threshold1, m_ntemp - 1);
    float s1 = (m_ptemp * threshold1temp / ((K1temp * m_ptemp - K2temp) * threshold1temp + K3temp));
    s1 = pow(s1, m_mtemp + 1);
    s1 = (m_atemp * m_mtemp * m_ptemp * K3temp * m_ntemp * threshold1temp1 * s1 * (1 / pow(threshold1temp * m_ptemp, 2)));
    
    float y1 = (m_ptemp * threshold1temp / ((K1temp * m_ptemp - K2temp) * threshold1temp + K3temp));
    y1 = pow(y1, m_mtemp);
    y1 = m_atemp * y1 + m_btemp;
    
    float a1 = y1;
    float b1 = s1;
    
    float y2 = maxDisplay;
    if (base_param_Delta_mode != 3) {
        y2 = maxDisplay;
    }
    if (base_param_Delta_mode == 3) {
        y2 = Referncedisplay;
    }
    
    if (P3Spline_TH_Mode == 3)
    {
        float max = pow(threshold3, m_ntemp);
        y2 = (m_ptemp * max / ((K1temp * m_ptemp - K2temp) * max + K3temp));
        y2 = pow(y2, m_mtemp);
        y2 = m_atemp * y2 + m_btemp;
    }
    
    if ((P3Spline_TH_Mode == 1 || P3Spline_TH_Mode == 2) && y2 > threshold3 && base_param_Delta_mode != 2 && base_param_Delta_mode != 3 && base_param_Delta_mode != 6)
    {
        threshold3 = y2;
        threshold2 = threshold1 + (threshold3 - threshold1) / 2.0;
    }
    float h1 = threshold2 - threshold1;
    float h2 = threshold3 - threshold2;
    
    float a2 = y1 + (y2 - y1) * (threshold2 - threshold1) / (threshold3 - threshold1) + (y2 - y1) * meta_str / 2;
    
    if ((P3Spline_TH_Mode == 1 || P3Spline_TH_Mode == 2) && a2 > threshold2 && base_param_Delta_mode != 3 && base_param_Delta_mode != 2 && base_param_Delta_mode != 6) {
        a2 = threshold2;
    }
    
    float s2 = 1.0;
    if ((P3Spline_TH_Mode == 2) || (P3Spline_TH_Mode == 3))
    {
        float threshold1temp = pow(threshold3, m_ntemp);
        float threshold1temp0 = pow(threshold3, m_ntemp - 1);
        s2 = (m_ptemp * threshold1temp / ((K1temp * m_ptemp - K2temp) * threshold1temp + K3temp));
        s2 = pow(s2, m_mtemp + 1);
        s2 = (m_atemp * m_mtemp * m_ptemp * K3temp * m_ntemp * threshold1temp0 * s2 * (1 / pow(threshold1temp * m_ptemp, 2)));
        
        if (P3Spline_TH_Mode == 2)
        {
            s2 = s2 - P3Spline_TH_MB;
        }
    }
    else
    {
        float up_T = (y2 - y1) / (threshold3 - threshold2);
        float mid_T = (y2 - y1) / (threshold3 - threshold1);
        float down_T = (y2 - y1) * 0.1 / (threshold3 - threshold1);
        
        down_T = down_T < s1 ? s1 : down_T;
        up_T = up_T < s1 ? s1 : up_T;
        
        s2 = meta_str >= 0 ? (up_T * meta_str + mid_T * (1 - meta_str)) : (down_T * (-meta_str) + mid_T * (1 + meta_str));
        if (s2 > 1.0) s2 = 1.0;
    }
    
    if (threshold3 == y2 && ((P3Spline_TH_Mode == 1) || (P3Spline_TH_Mode == 2)) && base_param_Delta_mode != 2 && base_param_Delta_mode != 3 && base_param_Delta_mode != 6) {
        s2 = 1.0;
    }
    float b2 = -(3.0 * a1 * h2 * h2 + 3.0 * a2 * h1 * h1 - 3.0 * h1 * h1 * y2 - 3.0 * h2 * h2 * a2 + h1 * h1 * h2 * s2 + b1 * h1 * h2 * h2) / (2.0 * h2 * (h1 * h1 + h2 * h1));
    float c1 = (3.0 * a2 - 2.0 * b1 * h1 - 3.0 * a1 - b2 * h1) / (h1 * h1);
    float d1 = (h1 * b1 + h1 * b2 + 2 * a1 - 2.0 * a2) / (h1 * h1 * h1);
    float c2 = c1 + 3.0 * d1 * h1;
    float d2 = -(y2 - a2 - h2 * s2 + c1 * h2 * h2 + 3 * d1 * h1 * h2 * h2) / (2 * h2 * h2 * h2);
    
    P3Spline_TH[0] = threshold1;
    P3Spline_TH[1] = threshold2;
    P3Spline_TH[2] = threshold3;
    *md1g = d1, * mc1g = c1, * mb1g = b1, * ma1g = a1;
    *md2g = d2, * mc2g = c2, * mb2g = b2, * ma2g = a2;
    *curve_mintiao_high_area = 1;
    
    return *curve_mintiao_high_area;
}


float low_area_spline(float maximum_maxrgb,
                       float average_maxrgb,
                       float tone_mapping_param_m_p,
                       float tone_mapping_param_m_m,
                       float tone_mapping_param_m_a,
                       float tone_mapping_param_m_b,
                       float tone_mapping_param_m_n,
                       float tone_mapping_param_K1,
                       float tone_mapping_param_K2,
                       float tone_mapping_param_K3,
                       float P3Spline_TH_MB,
                       float P3Spline_TH[3],
                       float P3Spline_Strength,
                       float maxDisplay,
                       float* md1g,
                       float* mc1g,
                       float* mb1g,
                       float* ma1g,
                       float* md2g,
                       float* mc2g,
                       float* mb2g,
                       float* ma2g,
                       float* dark,
                       float* DARKcurble_offset,
                       int* curve_mintiao,
                       float* m_a,
                       unsigned int base_param_Delta_mode,
                       unsigned int Base_flag,
                       int mode,
                       float m_maxE,
                       float m_inputMaxE)
{
    float threshold1 = 0.0;
    float threshold2 = 0.0;
    float threshold3 = 0.0;
    
    float m_ptemp = tone_mapping_param_m_p;
    float m_mtemp = tone_mapping_param_m_m;
    float m_atemp = tone_mapping_param_m_a;
    float m_btemp = tone_mapping_param_m_b;
    float m_ntemp = tone_mapping_param_m_n;
    float K1temp = tone_mapping_param_K1;
    float K2temp = tone_mapping_param_K2;
    float K3temp = tone_mapping_param_K3;
    
    float s1 = 1.0;
    if (average_maxrgb > 0.6)
    {
        if (mode ==     IJKMetalPostprocessSDR)
        {
            s1 = 0.9;
        }
        else if (mode ==     IJKMetalPostprocessHDR)
        {
            threshold1 = 0.1;
            s1 = 0.96;
        }
    }
    else if (average_maxrgb > 0.3 && average_maxrgb <= 0.6)
    {
        if (mode ==     IJKMetalPostprocessSDR)
        {
            s1 = 1.0 + (average_maxrgb - 0.3) / (0.6 - 0.3) * (0.9 - 1.0);
        }
        else if (mode ==     IJKMetalPostprocessHDR)
        {
            threshold1 = 0.25 + (average_maxrgb - 0.3) / (0.6 - 0.3) * (0.1 - 0.25);
            s1 = 1.0 + (average_maxrgb - 0.3) / (0.6 - 0.3) * (0.96 - 1.0);
        }
    }
    else
    {
        if (mode ==     IJKMetalPostprocessHDR)
        {
            threshold1 = 0.25;
        }
        s1 = 1.0;
    }
    if (mode ==     IJKMetalPostprocessSDR)
    {
        threshold1 = 0.0;
    }
    threshold2 = threshold1 + 0.15;
    threshold3 = threshold2 + (threshold2 - threshold1) / 2.0;
    
    IJKHDRVividCurve curvetemp;
    curvetemp.m_p = tone_mapping_param_m_p;
    curvetemp.m_m = tone_mapping_param_m_m;
    curvetemp.m_b = tone_mapping_param_m_b;
    curvetemp.m_a = tone_mapping_param_m_a;
    curvetemp.m_n = tone_mapping_param_m_n;
    curvetemp.K1 = tone_mapping_param_K1;
    curvetemp.K2 = tone_mapping_param_K2;
    curvetemp.K3 = tone_mapping_param_K3;
    if ((base_param_Delta_mode) < 3 && Base_flag == 1)
    {
        getBaseCurveParameterAdjust(&curvetemp);
    }
    curvetemp.TH1 = threshold1;
    curvetemp.TH2 = threshold2;
    curvetemp.TH3 = threshold3;
    curvetemp.DARKcurble_S1 = s1;
    curvetemp.curve_mintiao = 1;
    if ((base_param_Delta_mode) < 3 && Base_flag == 1) {
        AdjustVividParameter(m_maxE, m_inputMaxE, &curvetemp);
    }
    threshold1 = curvetemp.TH1;
    s1 = curvetemp.DARKcurble_S1;
    
    threshold2 = threshold1 + 0.15;
    threshold3 = threshold2 + (threshold2 - threshold1) / 2.0;
    
    float threshold3temp = pow(threshold3, m_ntemp);
    float ValueT3 = (m_ptemp * threshold3temp / ((K1temp * m_ptemp - K2temp) * threshold3temp + K3temp));
    ValueT3 = pow(ValueT3, m_mtemp);
    ValueT3 = m_atemp * ValueT3 + m_btemp;
    
    float threshold3temp1 = pow(threshold3, (m_ntemp - 1));
    float s2 = (m_ptemp * threshold3temp / ((K1temp * m_ptemp - K2temp) * threshold3temp + K3temp));
    s2 = pow(s2, m_mtemp + 1);
    s2 = (m_atemp * m_mtemp * m_ptemp * K3temp * m_ntemp * threshold3temp1 * s2 * (1 / pow(threshold3temp * m_ptemp, 2)));
    
    float a1 = s1 * threshold1 + *DARKcurble_offset;
    float b1 = s1;
    
    float threshold2temp = pow(threshold2, m_ntemp);
    float a2 = (m_ptemp * threshold2temp / ((K1temp * m_ptemp - K2temp) * threshold2temp + K3temp));
    a2 = pow(a2, m_mtemp);
    a2 = m_atemp * a2 + m_btemp;
    
    float h1 = threshold2 - threshold1;
    float h2 = threshold3 - threshold2;
    float y1 = a2;
    
    float y2 = (m_ptemp * threshold3temp / ((K1temp * m_ptemp - K2temp) * threshold3temp + K3temp));
    y2 = pow(y2, m_mtemp);
    y2 = m_atemp * y2 + m_btemp;
    
    if (mode ==     IJKMetalPostprocessHDR)
    {
        if (threshold3 - threshold1)
        {
            a2 = threshold2 * (y2 - a1) / (threshold3 - threshold1) + (threshold3 * a1 - y2 * threshold1) / (threshold3 - threshold1);
        }
        y1 = a2;
    }
    
    float b2 = -(3.0 * a1 * h2 * h2 + 3.0 * a2 * h1 * h1 - 3.0 * h1 * h1 * y2 - 3.0 * h2 * h2 * y1 + h1 * h1 * h2 * s2 + b1 * h1 * h2 * h2) / (2.0 * h2 * (h1 * h1 + h2 * h1));
    float c1 = (3.0 * y1 - 2.0 * b1 * h1 - 3.0 * a1 - b2 * h1) / (h1 * h1);
    float d1 = (h1 * b1 + h1 * b2 + 2 * a1 - 2.0 * y1) / (h1 * h1 * h1);
    float c2 = c1 + 3.0 * d1 * h1;
    float d2 = -(y2 - a2 - h2 * s2 + c1 * h2 * h2 + 3 * d1 * h1 * h2 * h2) / (2 * h2 * h2 * h2);
    
    P3Spline_TH[0] = threshold1;
    P3Spline_TH[1] = threshold2;
    P3Spline_TH[2] = threshold3;
    *md1g = d1, * mc1g = c1, * mb1g = b1, * ma1g = a1;
    *md2g = d2, * mc2g = c2, * mb2g = b2, * ma2g = a2;
    *dark = s1;
    
    *curve_mintiao = 1;
    return *curve_mintiao;
}
void getCubicSplineParameter(IJKHDRVividMetadata* metadata,
                             float m_maxE,
                             float m_inputMaxE,
                             IJKHDRVividCurve* curve,
                             int mode)
{
    float MaxDisplay = m_maxE;
    float maximum_maxrgbtemp = (float)((metadata->maximum_maxrgb)) / 4095;
    float average_maxrgbtemp = (float)((metadata->average_maxrgb)) / 4095;
    
    int HDRSDRTHMetedata = 2080;
    int MaxDisplayMetedata = (int)(MaxDisplay * ((1 << targeted_system_display_BIT) - 1));
    int i3spline = -1;
    int ibase = -1;
    float Referncedisplay = 0.67658;
    for (int i = 0; i < 2; i++)
    {
        int targetedSystemDisplay = metadata->targeted_system_display_maximum_luminance[i];
        float target = (float)(metadata->targeted_system_display_maximum_luminance[i]) / ((1 << targeted_system_display_BIT) - 1);
        Referncedisplay = target;
        if (((targetedSystemDisplay == HDRSDRTHMetedata) && (MaxDisplayMetedata == HDRSDRTHMetedata) && metadata->P3Spline_flag[i])
            || ((targetedSystemDisplay != HDRSDRTHMetedata) && (MaxDisplayMetedata != HDRSDRTHMetedata) && metadata->P3Spline_flag[i]))
        {
            i3spline = i;
            break;
        }
    }
    
    for (int j = 0; j < 2; j++)
    {
        int targetedSystemDisplay = metadata->targeted_system_display_maximum_luminance[j];
        float target = (float)(metadata->targeted_system_display_maximum_luminance[j]) / ((1 << targeted_system_display_BIT) - 1);
        Referncedisplay = target;
        if (((targetedSystemDisplay == HDRSDRTHMetedata) && (MaxDisplayMetedata == HDRSDRTHMetedata))
            || ((targetedSystemDisplay != HDRSDRTHMetedata) && (MaxDisplayMetedata != HDRSDRTHMetedata)))
        {
            ibase = j;
            break;
        }
    }
    
    int i3splinemode0 = 0;
    if (i3spline >= 0)
    {
        for (int spline_i = 0; spline_i < ((int)metadata->P3Spline_num[i3spline]); spline_i++)
        {
            if (metadata->P3Spline_TH_mode[i3spline][spline_i] == 0)
            {
                i3splinemode0 = 1;
            }
        }
    }
    if (i3spline < 0 || ((i3spline >= 0) && (i3splinemode0 == 0)))
    {
        float P3Spline_TH_MB = 0;
        float P3Spline_TH[3] = { 0,0,0 };
        float P3Spline_Strength = 0;
        float m_a_T = curve->m_a;
        curve->DARKcurble_offset = 0.0;
        unsigned int base_param_Delta_mode = 0;
        unsigned int Base_flag = 0;
        
        if(i3spline >= 0)
        {
            base_param_Delta_mode = metadata->base_param_Delta_mode[i3spline];
            Base_flag = metadata->Base_flag[i3spline];
        }
        else
        {
            if (ibase >= 0)
            {
                base_param_Delta_mode = metadata->base_param_Delta_mode[ibase];
                Base_flag = metadata->Base_flag[ibase];
            }
        }
        
        low_area_spline(maximum_maxrgbtemp,
                        average_maxrgbtemp,
                        curve->m_p,
                        curve->m_m,
                        curve->m_a,
                        curve->m_b,
                        curve->m_n,
                        curve->K1,
                        curve->K2,
                        curve->K3,
                        P3Spline_TH_MB,
                        P3Spline_TH,
                        P3Spline_Strength,
                        MaxDisplay,
                        //output
                        &curve->md1,
                        &curve->mc1,
                        &curve->mb1,
                        &curve->ma1,
                        &curve->md2,
                        &curve->mc2,
                        &curve->mb2,
                        &curve->ma2,
                        &curve->DARKcurble_S1,
                        &curve->DARKcurble_offset,
                        &curve->curve_mintiao,
                        &m_a_T,
                        metadata->base_param_Delta_mode[0],
                        metadata->Base_flag[0],
                        mode,
                        m_maxE,
                        m_inputMaxE);
        
        curve->TH1 = P3Spline_TH[0];
        curve->TH2 = P3Spline_TH[1];
        curve->TH3 = P3Spline_TH[2];
    }
    if (i3spline >= 0)
    {
        for (int spline_i = 0; spline_i < ((int)metadata->P3Spline_num[i3spline]); spline_i++)
        {
            float P3Spline_Strength_org = (float)((metadata->P3Spline_Strength[i3spline][spline_i] * 2)) / ((1 << P3Spline_Strength_BIT) - 1) - 1.0;
            int P3Spline_TH_OFFSET_code = metadata->P3Spline_TH_MB[i3spline][spline_i] & ((1 << P3Spline_TH_OFFSET_BIT) - 1);
            int P3Spline_TH_MB_code = (metadata->P3Spline_TH_MB[i3spline][spline_i] >> P3Spline_TH_OFFSET_BIT);
            float P3Spline_TH_MB = (float)((P3Spline_TH_MB_code * 1)) / ((1 << (P3Spline_TH_MB_BIT - P3Spline_TH_OFFSET_BIT)) - 1);
            if (metadata->P3Spline_TH_mode[i3spline][spline_i] == 0) {
                curve->DARKcurble_offset = (float)(P3Spline_TH_OFFSET_code * 0.1) / ((1 << P3Spline_TH_OFFSET_BIT) - 1);
            }
            if (metadata->P3Spline_TH_mode[i3spline][spline_i] != 0)
            {
                P3Spline_TH_MB = (float)((metadata->P3Spline_TH_MB[i3spline][spline_i] * 1.1)) / ((1 << P3Spline_TH_MB_BIT) - 1);
            }
            float TH1temp = (float)((metadata->P3Spline_TH[i3spline][spline_i][0])) / ((1 << P3Spline_TH1_BIT) - 1);
            float TH2temp = (float)((metadata->P3Spline_TH[i3spline][spline_i][1])) / (((1 << P3Spline_TH2_BIT) - 1) * 4) + TH1temp;
            float TH3temp = (float)((metadata->P3Spline_TH[i3spline][spline_i][2])) / (((1 << P3Spline_TH3_BIT) - 1) * 4) + TH2temp;
            float P3Spline_TH[3] = { TH1temp, TH2temp, TH3temp };
            
            if (metadata->P3Spline_TH_mode[i3spline][spline_i] == 0)
            {
                IJKHDRVividCurve curvetemp;
                memcpy(&curvetemp, curve, sizeof(IJKHDRVividCurve));
                if ((metadata->base_param_Delta_mode[0]) < 3 && metadata->Base_flag[0] == 1)
                    
                {
                    getBaseCurveParameterAdjust(&curvetemp);
                }
                curvetemp.TH1 = P3Spline_TH[0];
                curvetemp.TH2 = P3Spline_TH[1];
                curvetemp.TH3 = P3Spline_TH[2];
                curvetemp.DARKcurble_S1 = P3Spline_TH_MB;
                curvetemp.curve_mintiao = 1;
                if ((metadata->base_param_Delta_mode[0]) < 3 && metadata->Base_flag[0] == 1)
                    
                {
                    AdjustVividParameter(m_maxE,
                                         m_inputMaxE,
                                         &curvetemp);
                }
                P3Spline_TH[0] = curvetemp.TH1;
                P3Spline_TH[1] = curvetemp.TH2;
                P3Spline_TH[2] = curvetemp.TH3;
                curve->m_b = curvetemp.m_b;
                P3Spline_TH_MB = curvetemp.DARKcurble_S1;
                
                float P3Spline_Strength = P3Spline_Strength_org;
                
                float curve_ready1 = spline_area_spec(maximum_maxrgbtemp,
                                                       average_maxrgbtemp,
                                                       curve->m_p,
                                                       curve->m_m,
                                                       curve->m_a,
                                                       &curve->m_b,
                                                       curve->m_n,
                                                       curve->K1,
                                                       curve->K2,
                                                       curve->K3,
                                                       P3Spline_TH_MB,
                                                       P3Spline_TH,
                                                       P3Spline_Strength,
                                                       MaxDisplay,
                                                       //output
                                                       &curve->md1,
                                                       &curve->mc1,
                                                       &curve->mb1,
                                                       &curve->ma1,
                                                       &curve->md2,
                                                       &curve->mc2,
                                                       &curve->mb2,
                                                       &curve->ma2,
                                                       &curve->DARKcurble_S1,
                                                       &curve->DARKcurble_offset,
                                                       &curve->curve_mintiao,
                                                       metadata->base_param_Delta_mode[0]);
                if (curve_ready1)
                {
                    curve->TH1 = P3Spline_TH[0];
                    curve->TH2 = P3Spline_TH[1];
                    curve->TH3 = P3Spline_TH[2];
                }
                
            }
            else if ((metadata->P3Spline_TH_mode[i3spline][spline_i] == 1) || (metadata->P3Spline_TH_mode[i3spline][spline_i] == 2) || (metadata->P3Spline_TH_mode[i3spline][spline_i] == 3))
            {
                float maxContent_in = maximum_maxrgbtemp;
                maxContent_in = m_maxE > maxContent_in ? m_maxE : maxContent_in;
                {
                    float P3Spline_Strength = P3Spline_Strength_org;
                    
                    float threshold1temp = P3Spline_TH[0];
                    float threshold2temp = P3Spline_TH[1];
                    float threshold3temp = P3Spline_TH[2];
                    
                    if (curve->curve_mintiao)
                    {
                        if (threshold3temp <= curve->TH3)
                        {
                            continue;
                        }
                        else if (threshold1temp < curve->TH3)
                        {
                            threshold1temp = curve->TH3;
                            threshold2temp = (threshold1temp + threshold3temp) / 2;
                        }
                    }
                    
                    P3Spline_TH[0] = threshold1temp;
                    P3Spline_TH[1] = threshold2temp;
                    P3Spline_TH[2] = threshold3temp;
                    curve->Light_S1 = P3Spline_TH_MB;
                    float curve_ready1 = spline_higharea_spec(maximum_maxrgbtemp,
                                                               average_maxrgbtemp,
                                                               curve->m_p,
                                                               curve->m_m,
                                                               curve->m_a,
                                                               curve->m_b,
                                                               curve->m_n,
                                                               curve->K1,
                                                               curve->K2,
                                                               curve->K3,
                                                               metadata->P3Spline_TH_mode[i3spline][spline_i],
                                                               P3Spline_TH_MB,
                                                               P3Spline_TH,
                                                               P3Spline_Strength,
                                                               MaxDisplay,
                                                               //output
                                                               &curve->md1_high,
                                                               &curve->mc1_high,
                                                               &curve->mb1_high,
                                                               &curve->ma1_high,
                                                               &curve->md2_high,
                                                               &curve->mc2_high,
                                                               &curve->mb2_high,
                                                               &curve->ma2_high,
                                                               &curve->DARKcurble_S1,
                                                               &curve->curve_mintiao_high_area,
                                                               Referncedisplay,
                                                               metadata->base_param_Delta_mode[0]);
                    
                    if (curve_ready1)
                    {
                        curve->TH1_HIGH = P3Spline_TH[0];
                        curve->TH2_HIGH = P3Spline_TH[1];
                        curve->TH3_HIGH = P3Spline_TH[2];
                        if (metadata->P3Spline_TH_mode[i3spline][spline_i] == 3)
                        {
                            curve->high_area_flag = 1;
                        }
                    }
                }
                
            }
        }
    }
    
}


float getBaseCurveParameter(IJKHDRVividMetadata* metadata,
                             float MasterDisplay,
                             float MaxDisplay,
                             float MinDisplay,
                             IJKHDRVividCurve* curve,
                             float* maxE,
                             float* inputE,
                             int mode)
{
    float maximum_maxrgb_noLine = (float)(metadata->maximum_maxrgb) / 4095;
//    float minimum_maxrgb_noLine = (float)(metadata->minimum_maxrgb) / 4095;
    float average_maxrgb_noLine = (float)(metadata->average_maxrgb) / 4095;
    float variance_maxrgb_noLine = (float)(metadata->variance_maxrgb) / 4095;
    
    float meanVar = average_maxrgb_noLine + variance_maxrgb_noLine / 2;
    curve->m_m = 2.4;
    curve->m_n = 1.0;
    curve->m_b = 0.0;
    curve->K1 = 1.0;
    curve->K2 = 1.0;
    curve->K3 = 1.0;
    //std::cout << "10-1-1 " << std::endl;
    float lowThreshold;
    float highThreshold;
    if (mode ==     IJKMetalPostprocessSDR){
        lowThreshold = 0.1;
    }
    else if (mode ==     IJKMetalPostprocessHDR){
        lowThreshold = 0.3;
    }else{
        lowThreshold = 0.1;
    }
    
    if (average_maxrgb_noLine > 0.6)
    {
        curve->m_p = 3.5;
    }
    else if (average_maxrgb_noLine > lowThreshold && average_maxrgb_noLine <= 0.6)
    {
        if (mode ==     IJKMetalPostprocessSDR)
        {
            curve->m_p = 6.0 + (average_maxrgb_noLine - 0.1) / (0.6 - 0.1) * (3.5 - 6.0);
        }
        else if (mode ==     IJKMetalPostprocessHDR)
        {
            curve->m_p = 4.0 + (average_maxrgb_noLine - 0.3) / (0.6 - 0.3) * (3.5 - 4.0);
        }
    }
    else
    {
        if (mode ==     IJKMetalPostprocessSDR)
        {
            curve->m_p = 6.0;
        }
        else if (mode ==     IJKMetalPostprocessHDR)
        {
            curve->m_p = 4.0;
        }
    }
    float MaxDisplaySet = MaxDisplay;
    float MinDisplaySet = MinDisplay;
    float m_maxE = MaxDisplaySet;
    float m_minE = MinDisplaySet;
    
    float m_inputMinE = 0;
    float m_inputMaxE = maximum_maxrgb_noLine;
    m_inputMaxE = 0.8 * meanVar + 0.2 * maximum_maxrgb_noLine;
    
    float ReferfenceDisplay1600 = MasterDisplay;
    
    if (m_inputMaxE > ReferfenceDisplay1600)
    {
        m_inputMaxE = ReferfenceDisplay1600;
    }
    else if (m_inputMaxE < 0.5081)
    {
        m_inputMaxE = 0.5081;
    }
    
    if (m_inputMaxE < m_maxE)
    {
        m_inputMaxE = m_maxE;
    }
    
    if (mode ==     IJKMetalPostprocessSDR)
    {
        lowThreshold = 0.67;
        highThreshold = 0.75;
    }
    else //(mode == PostprocessHDR)
    {
        lowThreshold = 0.75;
        highThreshold = 0.9;
    }
    
    if (m_inputMaxE > highThreshold)
    {
        curve->m_p = curve->m_p + 0.6;
    }
    else if (m_inputMaxE > lowThreshold && m_inputMaxE <= highThreshold)
    {
        if (mode ==     IJKMetalPostprocessSDR)
        {
            curve->m_p = curve->m_p + 0.3 + (m_inputMaxE - 0.67) / (0.75 - 0.67) * (0.6 - 0.3);
        }
        else if (mode ==     IJKMetalPostprocessHDR)
        {
            curve->m_p = curve->m_p + 0.0 + (m_inputMaxE - 0.75) / (0.9 - 0.75) * (0.6 - 0.0);
        }
    }
    else
    {
        if (mode ==     IJKMetalPostprocessSDR)
        {
            curve->m_p = curve->m_p + 0.3;
        }
        else if (mode ==     IJKMetalPostprocessHDR)
        {
            curve->m_p = curve->m_p + 0.0;
        }
    }
    //std::cout << "10-1-3 " << std::endl;
    float input_minE_TM = pow((curve->m_p * m_inputMinE / ((curve->m_p - 1) * m_inputMinE + 1.0)), curve->m_m);
    float input_maxE_TM = pow((curve->m_p * m_inputMaxE / ((curve->m_p - 1) * m_inputMaxE + 1.0)), curve->m_m);
    curve->m_a = (m_maxE - m_minE) / (input_maxE_TM - input_minE_TM);
    curve->m_b = MinDisplaySet;
    //std::cout << "10-1-4 " << std::endl;
    for (int i = 0; i < 2; i++)
    {
        float targeted_system_display = (float)(metadata->targeted_system_display_maximum_luminance[i]) / ((1 << targeted_system_display_BIT) - 1);
        int HDRSDRTHMetedata = 2080;
        int targetedSystemDisplay = metadata->targeted_system_display_maximum_luminance[i];
        int MaxDisplayMetedata = (int)(MaxDisplay * ((1 << targeted_system_display_BIT) - 1));
        if ((metadata->Base_flag[i] == 0) || ((targetedSystemDisplay != HDRSDRTHMetedata) && (MaxDisplayMetedata == HDRSDRTHMetedata) && metadata->Base_flag[i])
            || ((targetedSystemDisplay == HDRSDRTHMetedata) && (MaxDisplayMetedata != HDRSDRTHMetedata) && metadata->Base_flag[i]))
        {
            continue;
        }
        float targeted_system_display_linear = (float)(10000 * PQforward(targeted_system_display));
        float MaxDisplay_linear = (float)(10000 * PQforward(MaxDisplay));
        float deltai = fabs(MaxDisplay_linear - targeted_system_display_linear) / 100;
        deltai = pow(deltai, 0.5);
        curve->base_param_Delta_mode = metadata->base_param_Delta_mode[i];
        
        float param_m_p = curve->m_p;
        float param_m_m = curve->m_m;
        float param_m_n = curve->m_n;
        float param_K1 = curve->K1;
        float param_K2 = curve->K2;
        float param_K3 = curve->K3;
        if (metadata->Base_flag[i])
        {
            curve->m_p = 10 * (float)((metadata->Base_param_m_p[i])) / ((1 << Base_param_m_p_BIT) - 1);
            curve->m_m = (float)((metadata->Base_param_m_m[i])) / (10);
            curve->m_a = (float)((metadata->Base_param_m_a[i])) / ((1 << Base_param_m_a_BIT) - 1);
            curve->m_b = (float)((metadata->Base_param_m_b[i])) / (((1 << Base_param_m_b_BIT) - 1) * 4);
            curve->m_n = (float)((metadata->Base_param_m_n[i])) / (10);
            curve->K1 = (float)((metadata->Base_param_K1[i]));
            curve->K2 = (float)((metadata->Base_param_K2[i]));
            curve->K3 = (float)((metadata->Base_param_K3[i]));
            if (metadata->Base_param_K3[i] == 2) curve->K3 = maximum_maxrgb_noLine;
        }
        if (fabs(targeted_system_display_linear - MaxDisplay_linear) <= 1)
        {
            break;
        }
        if ((metadata->base_param_Delta_mode[i] == 0) || (metadata->base_param_Delta_mode[i] == 2) || (metadata->base_param_Delta_mode[i] == 4) || (metadata->base_param_Delta_mode[i] == 6))
        {
            float deltaDisplay = (float)((metadata->base_param_Delta[i])) / ((1 << Base_param_Delta_BIT) - 1);
            deltaDisplay = (metadata->base_param_Delta_mode[i] == 2 || metadata->base_param_Delta_mode[i] == 6) ? (-deltaDisplay) : deltaDisplay;
            
            float weight = deltai * deltaDisplay;
            curve->m_p += weight;
            curve->m_p = DClip(curve->m_p, 3.0, 7.5);
            curve->m_a *= (MaxDisplay - MinDisplay) / targeted_system_display;
            
            break;
        }
        else if (metadata->base_param_Delta_mode[i] == 1 || (metadata->base_param_Delta_mode[i] == 5))
        {
            float deltaDisplay = (float)((metadata->base_param_Delta[i])) / ((1 << Base_param_Delta_BIT) - 1);
            float weight = deltai * deltaDisplay;
            weight = weight >= 0 ? weight : -weight;
            if (weight > 1) weight = 1;
            float weightp = 1 - weight;
            curve->m_p = weightp * (curve->m_p) + weight * param_m_p;
            curve->m_m = weightp * (curve->m_m) + weight * param_m_m;
            curve->m_n = weightp * (curve->m_n) + weight * param_m_n;
            curve->K1 = weightp * (curve->K1) + weight * param_K1;
            curve->K2 = weightp * (curve->K2) + weight * param_K2;
            curve->K3 = weightp * (curve->K3) + weight * param_K3;
            
            float input_minE_TM = pow((curve->m_p * pow(m_inputMinE, curve->m_n) / ((curve->K1 * curve->m_p - curve->K2) * pow(m_inputMinE, curve->m_n) + curve->K3)), curve->m_m);
            float input_maxE_TM = pow((curve->m_p * pow(m_inputMaxE, curve->m_n) / ((curve->K1 * curve->m_p - curve->K2) * pow(m_inputMaxE, curve->m_n) + curve->K3)), curve->m_m);
            curve->m_a = (m_maxE - m_minE) / (input_maxE_TM - input_minE_TM);
            curve->m_b = m_minE;
            break;
        }
    }
    *maxE = m_maxE;
    *inputE = m_inputMaxE;
    
    return 1;
}

//////////////////////////xuweiwei//////////////////////////////////////////////////////////////////////
#define TPA_NUM      4

void InitParams(float max_display_luminance, IJKHDRVividMetadata *metadata, float MasterDisplay, IJKHDRVividCurve* curve, float* GTMcurve2 , IJKMetalProcessMode mode)
{
    // unsigned char * GTMcurve;
    float m_maxEtemp;
    float m_inputMaxEtemp;
    
    
    memset(curve, 0, sizeof(IJKHDRVividCurve));
    
    float MaxDisplay = (float)(PQinverse(max_display_luminance / 10000.0));
    float MinDisplay = (float)(PQinverse(0.05/10000.00));

    if (mode == IJKMetalPostprocessSDR) {
        MinDisplay = (float)(PQinverse(0.1/10000.00));
    }
    //printf("mintD5*a3ya=%f \n", MinDisplay);
    //HDRVividCurve curve;
    //memset(&curve, 0, sizeof(HDRVividCurve));
    
    getBaseCurveParameter(metadata,
                          MasterDisplay,
                          MaxDisplay,
                          MinDisplay,
                          curve,
                          &m_maxEtemp,
                          &m_inputMaxEtemp,
                          mode);
    
    getCubicSplineParameter(metadata,
                            m_maxEtemp,
                            m_inputMaxEtemp,
                            curve,
                            mode);
    float m_maxEtemp_store = m_maxEtemp;
    //float GTMcurve2[256] = { 0 };
    
    curve->maxEtemp_store = m_maxEtemp;
    curve->inputMaxEtemp_store = m_inputMaxEtemp;
    
    
    MaxDisplay =  curve->maxEtemp_store;
    curve->TML = MaxDisplay;
    curve->TML_linear = (float)(10000 * PQforward(curve->TML));
    curve->RML = metadata->_masterDisplay;

    curve->RML_linear = (float)(10000 * PQforward(curve->RML));
    if (curve->TML_linear > curve->RML_linear) curve->RML_linear = curve->TML_linear;
    if (curve->TML > curve->RML) curve->RML = curve->TML;
    
    
    if(GTMcurve2)
    calc_curveLUT(m_maxEtemp_store, m_maxEtemp,  m_inputMaxEtemp, metadata, curve, GTMcurve2);
    
}
float calc_curve(float max, IJKHDRVividCurve* TMP)
{
    float max1 = max;
    if (TMP->curve_mintiao && TMP->curve_mintiao_high_area)
    {
        if (max <= TMP->TH1) {
            max1 = TMP->DARKcurble_S1 * max + TMP->DARKcurble_offset;
        }
        else if (max > TMP->TH1 && max <= TMP->TH2)
            max1 = TMP->md1 * pow((max - TMP->TH1), 3) + TMP->mc1 * pow((max - TMP->TH1), 2) + TMP->mb1 * pow((max - TMP->TH1), 1) + TMP->ma1;
        else if (max > TMP->TH2 && max <= TMP->TH3)
        {
            max1 = TMP->md2 * pow((max - TMP->TH2), 3) + TMP->mc2 * pow((max - TMP->TH2), 2) + TMP->mb2 * pow((max - TMP->TH2), 1) + TMP->ma2;
        }
        else if (max > TMP->TH1_HIGH && max <= TMP->TH2_HIGH)
        {
            max1 = TMP->md1_high * pow((max - TMP->TH1_HIGH), 3) + TMP->mc1_high * pow((max - TMP->TH1_HIGH), 2) + TMP->mb1_high * pow((max - TMP->TH1_HIGH), 1) + TMP->ma1_high;
        }
        else if (max > TMP->TH2_HIGH && max <= TMP->TH3_HIGH)
        {
            max1 = TMP->md2_high * pow((max - TMP->TH2_HIGH), 3) + TMP->mc2_high * pow((max - TMP->TH2_HIGH), 2) + TMP->mb2_high * pow((max - TMP->TH2_HIGH), 1) + TMP->ma2_high;
        }
        else  if ((max > TMP->TH3_HIGH) && (TMP->high_area_flag == 0))
        {
            max1 = (3 * TMP->md2_high * pow((TMP->TH3_HIGH - TMP->TH2_HIGH), 2) + 2 * TMP->mc2_high * pow((TMP->TH3_HIGH - TMP->TH2_HIGH), 1) + TMP->mb2_high) * (max - TMP->TH3_HIGH)
            + TMP->md2_high * pow((TMP->TH3_HIGH - TMP->TH2_HIGH), 3) + TMP->mc2_high * pow((TMP->TH3_HIGH - TMP->TH2_HIGH), 2) + TMP->mb2_high * pow((TMP->TH3_HIGH - TMP->TH2_HIGH), 1) + TMP->ma2_high;
        }
        else
        {
            max = pow(max, TMP->m_n);
            max1 = (TMP->m_p * max / ((TMP->K1 * TMP->m_p - TMP->K2) * max + TMP->K3));
            max1 = pow(max1, TMP->m_m);
            max1 = TMP->m_a * max1 + TMP->m_b;
        }
    }
    else if (TMP->curve_mintiao)
    {
        if (max <= TMP->TH1) {
            max1 = TMP->DARKcurble_S1 * max + TMP->DARKcurble_offset;
        }
        else if (max > TMP->TH1 && max <= TMP->TH2)
            max1 = TMP->md1 * pow((max - TMP->TH1), 3) + TMP->mc1 * pow((max - TMP->TH1), 2) + TMP->mb1 * pow((max - TMP->TH1), 1) + TMP->ma1;
        else if (max > TMP->TH2 && max <= TMP->TH3)
            max1 = TMP->md2 * pow((max - TMP->TH2), 3) + TMP->mc2 * pow((max - TMP->TH2), 2) + TMP->mb2 * pow((max - TMP->TH2), 1) + TMP->ma2;
        else
        {
            max = pow(max, TMP->m_n);
            max1 = (TMP->m_p * max / ((TMP->K1 * TMP->m_p - TMP->K2) * max + TMP->K3));
            max1 = pow(max1, TMP->m_m);
            max1 = TMP->m_a * max1 + TMP->m_b;
        }
    }
    else if (TMP->curve_mintiao_high_area)
    {
        if (max > TMP->TH1_HIGH && max <= TMP->TH2_HIGH)
            max1 = TMP->md1_high * pow((max - TMP->TH1_HIGH), 3) + TMP->mc1_high * pow((max - TMP->TH1_HIGH), 2) + TMP->mb1_high * pow((max - TMP->TH1_HIGH), 1) + TMP->ma1_high;
        else if (max > TMP->TH2_HIGH && max <= TMP->TH3_HIGH)
            max1 = TMP->md2_high * pow((max - TMP->TH2_HIGH), 3) + TMP->mc2_high * pow((max - TMP->TH2_HIGH), 2) + TMP->mb2_high * pow((max - TMP->TH2_HIGH), 1) + TMP->ma2_high;
        else  if ((max > TMP->TH3_HIGH) && (TMP->high_area_flag == 0))
        {
            max1 = (3 * TMP->md2_high * pow((TMP->TH3_HIGH - TMP->TH2_HIGH), 2) + 2 * TMP->mc2_high * pow((TMP->TH3_HIGH - TMP->TH2_HIGH), 1) + TMP->mb2_high) * (max - TMP->TH3_HIGH)
            + TMP->md2_high * pow((TMP->TH3_HIGH - TMP->TH2_HIGH), 3) + TMP->mc2_high * pow((TMP->TH3_HIGH - TMP->TH2_HIGH), 2) + TMP->mb2_high * pow((TMP->TH3_HIGH - TMP->TH2_HIGH), 1) + TMP->ma2_high;
        }
        else
        {
            max = pow(max, TMP->m_n);
            max1 = (TMP->m_p * max / ((TMP->K1 * TMP->m_p - TMP->K2) * max + TMP->K3));
            max1 = pow(max1, TMP->m_m);
            max1 = TMP->m_a * max1 + TMP->m_b;
        }
    }
    else
    {
        max = pow(max, TMP->m_n);
        max1 = (TMP->m_p * max / ((TMP->K1 * TMP->m_p - TMP->K2) * max + TMP->K3));
        max1 = pow(max1, TMP->m_m);
        max1 = TMP->m_a * max1 + TMP->m_b;
    }
    return max1;
}
float getB(float smCoef, float Y_PQ, float m_inputMaxE, IJKHDRVividMetadata* metadata, IJKHDRVividCurve* tone_mapping_param)
{
    float Yout_pq = calc_curve(Y_PQ, tone_mapping_param);
    float power_used = (float)(metadata->color_saturation_gain[0]) / 128.0;
    float scale = Yout_pq / Y_PQ;
    smCoef = pow(scale, power_used);
    smCoef = dClip(smCoef, 0.8, 1.0);
    
    return smCoef;
}


float saturation_modify(float Y_PQ, float m_maxEtemp, float m_inputMaxEtemp, float MasterDisplay, IJKHDRVividMetadata* metadata, IJKHDRVividCurve* tone_mapping_param)
{
    float m_inputMaxEtemp_store = m_inputMaxEtemp;
    float m_maxEtemp_store = m_maxEtemp;
    
    
    
    float MaxDisplay = m_maxEtemp_store;
    float TML = MaxDisplay;
    float TML_linear = (float)(10000 * PQforward(TML));
    float RML = MasterDisplay;
    float RML_linear = (float)(10000 * PQforward(RML));
    if (TML_linear > RML_linear) RML_linear = TML_linear;
    if (TML > RML) RML = TML;
    
    
    
    float smCoef = 0.0;
    if (metadata->color_saturation_mapping_flag == 0)
    {
        smCoef = 1.0;
        return smCoef;
    }
    //apply C0
    float Yin_pq = Y_PQ;
    //std::cout << Yin_pq << std::endl;
    float Yout_pq = calc_curve(Yin_pq, tone_mapping_param);
    
    
    float power_used = (float)(metadata->color_saturation_gain[0]) / 128.0;
    float scale = Yout_pq / Yin_pq;
    smCoef = pow(scale, power_used);
    smCoef = dClip(smCoef, 0.8, 1.0);
    float B = getB(smCoef, MaxDisplay, m_inputMaxEtemp_store, metadata, tone_mapping_param);
    
    
    //apply C1
    float SATR = 0.4;
    float C1 = 0.0;
    float C2 = 1.0;
    
    if ((metadata->color_saturation_mapping_flag) && (metadata->color_saturation_num > 1))
    {
        C1 = (float)(metadata->color_saturation_gain[1] & 0xFC) / 128.0;
        C2 = (float)(metadata->color_saturation_gain[1] & 0x3);
        C2 = pow(2, C2);
    }
    if (C1 == 0.0)
    {
        return smCoef;
    }
    float Sca = 1.0;
    if (Yin_pq >= RML)
    {
        if (B >= C1 * SATR) Sca = B - C1 * SATR;
        else Sca = 0;
        smCoef = Sca;
    }
    else if (Yin_pq >= TML)
    {
        float ratioC = (Yin_pq - TML) / (RML - TML);
        ratioC = pow(ratioC, C2);
        if (B >= C1 * SATR * ratioC)    Sca = B - C1 * SATR * ratioC;
        else Sca = 0;
        smCoef = Sca;
    }
    return smCoef;
}

void calc_curveLUT(float m_maxEtemp_store, float m_maxEtemp, float m_inputMaxEtemp, IJKHDRVividMetadata * metadata, IJKHDRVividCurve* curve, float* GTMcurve22) {
    
    if(GTMcurve22 == NULL) return;
    
    //HDRVividCurve tonemappingparam;
    //HDRVividMetadata metadata;
    float GTMcurve1[CURVELEN] = { 0 };
    float GTMcurve2[CURVELEN] = { 0 };
    float GTMcurve3[CURVELEN] = { 0 };
    float GTMcurve4[CURVELEN] = { 0 };
    for (int i = 0; i < CURVELEN; ++i) {
        //    auto valTempInputPq = static_cast<float>(i) / (CURVELEN-1); // 0.032258=32/992
        float valTempInputPq = (float)i / (CURVELEN - 1);
        float valTempOutputPq = calc_curve(valTempInputPq, curve);
        // valTempOutputPq = FClip(valTempOutputPq, minDisplay, maxDisplay); // MinDisplay��Ϊ0
        // 1023.0Ϊ2^10��PQ����10bit������PQ��ı���ֵ
        //    printf("HDR Vivid information: valTempOutputPq =%f  curve->m_a=%f,\n", valTempOutputPq, curve->m_a);
        GTMcurve1[i] = (float)((valTempOutputPq * (float)(CURVELEN-1.0)) + 0.5);
    }
    
    for (int i = 0; i < CURVELEN; ++i) {
        //auto valTempInputPq1 = static_cast<float>(i) / (CURVELEN-1); // 0.032258=32/992
        float valTempInputPq1 = (float)(i) / (CURVELEN - 1);
        GTMcurve3[i] = (float)(valTempInputPq1);
        float valTempOutputPq1 = saturation_modify(valTempInputPq1, m_maxEtemp, m_inputMaxEtemp, m_maxEtemp_store, metadata, curve);
        
        GTMcurve4[i] = (float)((valTempOutputPq1));
        GTMcurve2[i] = (float)((valTempOutputPq1 * (float)(CURVELEN - 1.0)) + 0.5);
        
    }
    
    for (int i = 0; i < CURVELEN; i++) {
        GTMcurve22[i] =GTMcurve1[i];
        //printf("HDR Vivid information: GTMcurve1[i]=%f,\n", GTMcurve22[i]);
        //    printf("HDR Vivid information: valTempOutputPq =%f  curve->m_a=%f, curve->m_p=%f,curve->md2=%f,curve->md1_high=%f,  curve->TH2=%f, curve->TH2_HIGH=%f,curve->base_param_Delta_mode=%d,curve->base_param_Delta=%f,curve->curve->P3Spline_TH_MB[0] = % f, curve->P3Spline_TH_MB[1] = % f \n",
        //    GTMcurve22[i], curve->m_a, curve->m_p, curve->md2, curve->md1_high, curve->TH2,curve->TH2_HIGH, curve->base_param_Delta_mode,curve->base_param_Delta, curve->P3Spline_TH_MB[0], curve->P3Spline_TH_MB[1]);
        
        //    printf("HDR Vivid information:curve->curve_mintiao=%d,  curve->curve_mintiao_high_area = % d \n", curve->curve_mintiao, curve->curve_mintiao_high_area);
        //    printf("HDR Vivid information:curve->TH1=%f,  curve->TH2 = % f ,  curve->TH3 = % f \n", curve->TH1, curve->TH2, curve->TH3 );
    }
    
}

void InitCurve(IJKHDRVividCurve* curve)
{
    curve->m_m = 2.4;
    curve->m_n = 1.0;
    curve->m_b = 0.0;
    curve->K1 = 1.0;
    curve->K2 = 1.0;
    curve->K3 = 1.0;
    curve->m_p = 4.433;
    curve->m_a = 0.7351;
    
    //curve->m_p = 3.817460;  //100nit
    //curve->m_a = 0.645728;   //100nit
    
    //curve->m_a = 0.0;
    curve->m_b = 0.0;
    curve->TH1 = 0.0000000000000000;
    curve->TH2 = 0.12487781036168133;
    curve->TH3 = 0.24975562072336266;
    curve->curve_mintiao = 0;
    curve->md1 = 17.82619679935;
    curve->mc1 = -5.745618709;
    curve->mb1 = 0.88888888888888884;
    curve->ma1 = 0.0000000000000000;
    curve->md2 = 3.11576828;
    curve->mc2 = 0.9326705584;
    curve->mb2 = 0.28785846239;
    curve->ma2 = 0.056117422;
    curve->DARKcurble_S1 = 0.88888888888888884;
    curve->DARKcurble_offset = 0.0000000000000000;
    curve->md1_high = 0.0000000000000000;
    curve->mc1_high = 0.0000000000000000;
    curve->mb1_high = 0.0000000000000000;
    curve->ma1_high = 0.0000000000000000;
    curve->md2_high = 0.0000000000000000;
    curve->mc2_high = 0.0000000000000000;
    curve->mb2_high = 0.0000000000000000;
    curve->ma2_high = 0.0000000000000000;
    curve->TH1_HIGH = 0.0000000000000000;
    curve->TH2_HIGH = 0.0000000000000000;
    curve->TH3_HIGH = 0.0000000000000000;
    curve->curve_mintiao_high_area = 0;
    curve->high_area_flag = 0;
}












