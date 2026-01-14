#define GOOLIB_STB_TRUETYPE
#define STB_TRUETYPE_IMPLEMENTATION true
#define STBTT_ifloor(x)    cutil_ifloor(x)
#define STBTT_iceil(x)     cutil_iceil(x)
#define STBTT_sqrt(x)      cutil_sqrt(x)
#define STBTT_pow(x,y)     cutil_pow(x,y)
#define STBTT_fmod(x,y)    cutil_fmod(x,y)
#define STBTT_cos(x)       cutil_cos(x)
#define STBTT_acos(x)      cutil_acos(x)
#define STBTT_fabs(x)      cutil_fabs(x)
#define STBTT_malloc(x,u)  stbtt_malloc(x, u)
#define STBTT_free(x,u)    stbtt_free(x, u)
#define STBTT_assert(x)    cutil_assert(x)
#define STBTT_strlen(x)    cutil_strlen(x)
#define STBTT_memcpy       cutil_memcpy
#define STBTT_memset       cutil_memset
#include "./stb_truetype.h"