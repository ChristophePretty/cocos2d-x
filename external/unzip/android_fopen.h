// Overrides stdio file functions for android, so that assets are searched in the apk if necessary
// based on http://www.50ply.com/blog/2013/01/19/loading-compressed-android-assets-with-file-pointer/#comment-1850768990
//

#ifndef ANDROID_FOPEN_H
#define ANDROID_FOPEN_H

#include "platform/CCPlatformMacros.h"

#if CC_TARGET_PLATFORM == CC_PLATFORM_ANDROID
#include <stdio.h>
#include <android/asset_manager.h>

#ifdef __cplusplus
extern "C" {
#endif

/* hijack fopen and route it through the android asset system so that
   we can pull things out of our packagesk APK */

void android_fopen_set_asset_manager(AAssetManager* manager);
extern FILE* android_fopen(const char* fname, const char* mode);

#define fopen(name, mode) android_fopen(name, mode)

#ifdef __cplusplus
}
#endif

#endif
#endif