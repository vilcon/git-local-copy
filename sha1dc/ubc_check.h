/***
 * Copyright 2017 Marc Stevens <marc@marc-stevens.nl>, Dan Shumow <danshu@microsoft.com>
 * Distributed under the MIT Software License.
 * See accompanying file LICENSE.txt or copy at
 * https://opensource.org/licenses/MIT
 ***/

/*
// this file was generated by the 'parse_bitrel' program in the tools section
// using the data files from directory 'tools/data/3565'
//
// sha1_dvs contains a list of SHA-1 Disturbance Vectors (DV) to check
// dvType, dvK and dvB define the DV: I(K,B) or II(K,B) (see the paper)
// dm[80] is the expanded message block XOR-difference defined by the DV
// testt is the step to do the recompression from for collision detection
// maski and maskb define the bit to check for each DV in the dvmask returned by ubc_check
//
// ubc_check takes as input an expanded message block and verifies the unavoidable bitconditions for all listed DVs
// it returns a dvmask where each bit belonging to a DV is set if all unavoidable bitconditions for that DV have been met
// thus one needs to do the recompression check for each DV that has its bit set
*/

#ifndef SHA1DC_UBC_CHECK_H
#define SHA1DC_UBC_CHECK_H

#if defined(__cplusplus)
extern "C"
{
#endif

#ifndef SHA1DC_NO_STANDARD_INCLUDES
    #include <stdint.h>
#endif

#define DVMASKSIZE 1
    typedef struct
    {
        int      dvType;
        int      dvK;
        int      dvB;
        int      testt;
        int      maski;
        int      maskb;
        uint32_t dm[80];
    } dv_info_t;
    extern dv_info_t sha1_dvs[];
    void             ubc_check(const uint32_t W[80], uint32_t dvmask[DVMASKSIZE]);

#define DOSTORESTATE58
#define DOSTORESTATE65

#define CHECK_DVMASK(_DVMASK) (0 != _DVMASK[0])

#if defined(__cplusplus)
}
#endif

#ifdef SHA1DC_CUSTOM_TRAILING_INCLUDE_UBC_CHECK_H
    #include SHA1DC_CUSTOM_TRAILING_INCLUDE_UBC_CHECK_H
#endif

#endif
