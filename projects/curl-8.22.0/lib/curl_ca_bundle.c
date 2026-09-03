/***************************************************************************
 *                                  _   _ ____  _
 *  Project                     ___| | | |  _ \| |
 *                             / __| | | | |_) | |
 *                            | (__| |_| |  _ <| |___
 *                             \___|\___/|_| \_\_____|
 *
 * Copyright (C) Daniel Stenberg, <daniel@haxx.se>, et al.
 *
 * This software is licensed as described in the file COPYING, which
 * you should have received as part of this distribution. The terms
 * are also available at https://curl.se/docs/copyright.html.
 *
 * You may opt to use, copy, modify, merge, publish, distribute and/or sell
 * copies of the Software, and permit persons to whom the Software is
 * furnished to do so, under the terms of the COPYING file.
 *
 * This software is distributed on an "AS IS" basis, WITHOUT WARRANTY OF ANY
 * KIND, either express or implied.
 *
 * SPDX-License-Identifier: curl
 *
 ***************************************************************************/

#include "curl_setup.h"

#include <sys/stat.h>
#include <pthread.h>

#include "curl_ca_bundle.h"

/* Known CA bundle file locations across Linux distributions */
static const char *const ca_bundle_paths[] = {
  "/etc/ssl/certs/ca-certificates.crt",                  /* Debian/Ubuntu */
  "/etc/pki/tls/certs/ca-bundle.crt",                    /* RHEL/Rocky/Fedora */
  "/etc/ssl/ca-bundle.pem",                              /* OpenSUSE */
  "/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem",   /* RHEL 7+ */
  "/etc/ssl/cert.pem",                                   /* Alpine, macOS */
  NULL
};

/* Known CA certificate directory locations */
static const char *const ca_path_dirs[] = {
  "/etc/ssl/certs",
  "/etc/pki/tls/certs",
  NULL
};

static const char *detected_ca_bundle;
static const char *detected_ca_path;
static pthread_once_t ca_detect_once = PTHREAD_ONCE_INIT;

static void ca_detect(void)
{
  struct stat st;
  int i;

#if defined(CURL_CA_BUNDLE)
  detected_ca_bundle = CURL_CA_BUNDLE;
#else
  for(i = 0; ca_bundle_paths[i]; i++) {
    if(stat(ca_bundle_paths[i], &st) == 0 && S_ISREG(st.st_mode)) {
      detected_ca_bundle = ca_bundle_paths[i];
      break;
    }
  }
#endif

#if defined(CURL_CA_PATH)
  detected_ca_path = CURL_CA_PATH;
#else
  for(i = 0; ca_path_dirs[i]; i++) {
    if(stat(ca_path_dirs[i], &st) == 0 && S_ISDIR(st.st_mode)) {
      detected_ca_path = ca_path_dirs[i];
      break;
    }
  }
#endif
}

const char *Curl_ca_bundle(void)
{
  pthread_once(&ca_detect_once, ca_detect);
  return detected_ca_bundle;
}

const char *Curl_ca_path(void)
{
  pthread_once(&ca_detect_once, ca_detect);
  return detected_ca_path;
}
