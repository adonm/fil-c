
/* DO NOT EDIT! GENERATED AUTOMATICALLY! */

#define P11_VIRTUAL_FIXED_FUNCTIONS(fixed_index)        \
static CK_RV \
fixed ## fixed_index ## _C_Initialize (CK_VOID_PTR init_args) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_Initialize (funcs, \
                                    init_args); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_Finalize (CK_VOID_PTR pReserved) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_Finalize (funcs, \
                                  pReserved); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_GetInfo (CK_INFO_PTR pInfo) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_GetInfo (funcs, \
                                 pInfo); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_GetSlotList (unsigned char token_present, \
                                        CK_SLOT_ID_PTR slot_list, \
                                        long unsigned int * ulCount) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_GetSlotList (funcs, \
                                     token_present, \
                                     slot_list, \
                                     ulCount); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_GetSlotInfo (CK_SLOT_ID slotID, \
                                        CK_SLOT_INFO_PTR pInfo) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_GetSlotInfo (funcs, \
                                     slotID, \
                                     pInfo); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_GetTokenInfo (CK_SLOT_ID slotID, \
                                         CK_TOKEN_INFO_PTR pInfo) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_GetTokenInfo (funcs, \
                                      slotID, \
                                      pInfo); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_GetMechanismList (CK_SLOT_ID slotID, \
                                             CK_MECHANISM_TYPE_PTR mechanism_list, \
                                             long unsigned int * ulCount) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_GetMechanismList (funcs, \
                                          slotID, \
                                          mechanism_list, \
                                          ulCount); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_GetMechanismInfo (CK_SLOT_ID slotID, \
                                             CK_MECHANISM_TYPE type, \
                                             CK_MECHANISM_INFO_PTR pInfo) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_GetMechanismInfo (funcs, \
                                          slotID, \
                                          type, \
                                          pInfo); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_InitToken (CK_SLOT_ID slotID, \
                                      unsigned char * pin, \
                                      long unsigned int pin_len, \
                                      unsigned char * label) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_InitToken (funcs, \
                                   slotID, \
                                   pin, \
                                   pin_len, \
                                   label); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_InitPIN (CK_SESSION_HANDLE session, \
                                    unsigned char * pin, \
                                    long unsigned int pin_len) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_InitPIN (funcs, \
                                 session, \
                                 pin, \
                                 pin_len); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_SetPIN (CK_SESSION_HANDLE session, \
                                   unsigned char * old_pin, \
                                   long unsigned int old_len, \
                                   unsigned char * new_pin, \
                                   long unsigned int new_len) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_SetPIN (funcs, \
                                session, \
                                old_pin, \
                                old_len, \
                                new_pin, \
                                new_len); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_OpenSession (CK_SLOT_ID slotID, \
                                        CK_FLAGS flags, \
                                        CK_VOID_PTR application, \
                                        CK_NOTIFY notify, \
                                        CK_SESSION_HANDLE_PTR session) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_OpenSession (funcs, \
                                     slotID, \
                                     flags, \
                                     application, \
                                     notify, \
                                     session); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_CloseSession (CK_SESSION_HANDLE session) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_CloseSession (funcs, \
                                      session); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_CloseAllSessions (CK_SLOT_ID slotID) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_CloseAllSessions (funcs, \
                                          slotID); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_GetSessionInfo (CK_SESSION_HANDLE session, \
                                           CK_SESSION_INFO_PTR pInfo) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_GetSessionInfo (funcs, \
                                        session, \
                                        pInfo); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_GetOperationState (CK_SESSION_HANDLE session, \
                                              unsigned char * operation_state, \
                                              long unsigned int * operation_state_len) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_GetOperationState (funcs, \
                                           session, \
                                           operation_state, \
                                           operation_state_len); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_SetOperationState (CK_SESSION_HANDLE session, \
                                              unsigned char * operation_state, \
                                              long unsigned int operation_state_len, \
                                              CK_OBJECT_HANDLE encryption_key, \
                                              CK_OBJECT_HANDLE authentication_key) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_SetOperationState (funcs, \
                                           session, \
                                           operation_state, \
                                           operation_state_len, \
                                           encryption_key, \
                                           authentication_key); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_Login (CK_SESSION_HANDLE session, \
                                  CK_USER_TYPE user_type, \
                                  unsigned char * pin, \
                                  long unsigned int pin_len) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_Login (funcs, \
                               session, \
                               user_type, \
                               pin, \
                               pin_len); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_Logout (CK_SESSION_HANDLE session) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_Logout (funcs, \
                                session); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_CreateObject (CK_SESSION_HANDLE session, \
                                         CK_ATTRIBUTE_PTR pTemplate, \
                                         long unsigned int ulCount, \
                                         CK_OBJECT_HANDLE_PTR object) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_CreateObject (funcs, \
                                      session, \
                                      pTemplate, \
                                      ulCount, \
                                      object); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_CopyObject (CK_SESSION_HANDLE session, \
                                       CK_OBJECT_HANDLE object, \
                                       CK_ATTRIBUTE_PTR pTemplate, \
                                       long unsigned int ulCount, \
                                       CK_OBJECT_HANDLE_PTR new_object) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_CopyObject (funcs, \
                                    session, \
                                    object, \
                                    pTemplate, \
                                    ulCount, \
                                    new_object); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_DestroyObject (CK_SESSION_HANDLE session, \
                                          CK_OBJECT_HANDLE object) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_DestroyObject (funcs, \
                                       session, \
                                       object); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_GetObjectSize (CK_SESSION_HANDLE session, \
                                          CK_OBJECT_HANDLE object, \
                                          long unsigned int * size) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_GetObjectSize (funcs, \
                                       session, \
                                       object, \
                                       size); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_GetAttributeValue (CK_SESSION_HANDLE session, \
                                              CK_OBJECT_HANDLE object, \
                                              CK_ATTRIBUTE_PTR pTemplate, \
                                              long unsigned int ulCount) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_GetAttributeValue (funcs, \
                                           session, \
                                           object, \
                                           pTemplate, \
                                           ulCount); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_SetAttributeValue (CK_SESSION_HANDLE session, \
                                              CK_OBJECT_HANDLE object, \
                                              CK_ATTRIBUTE_PTR pTemplate, \
                                              long unsigned int ulCount) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_SetAttributeValue (funcs, \
                                           session, \
                                           object, \
                                           pTemplate, \
                                           ulCount); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_FindObjectsInit (CK_SESSION_HANDLE session, \
                                            CK_ATTRIBUTE_PTR pTemplate, \
                                            long unsigned int ulCount) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_FindObjectsInit (funcs, \
                                         session, \
                                         pTemplate, \
                                         ulCount); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_FindObjects (CK_SESSION_HANDLE session, \
                                        CK_OBJECT_HANDLE_PTR object, \
                                        long unsigned int max_object_count, \
                                        long unsigned int * object_count) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_FindObjects (funcs, \
                                     session, \
                                     object, \
                                     max_object_count, \
                                     object_count); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_FindObjectsFinal (CK_SESSION_HANDLE session) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_FindObjectsFinal (funcs, \
                                          session); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_EncryptInit (CK_SESSION_HANDLE session, \
                                        CK_MECHANISM_PTR mechanism, \
                                        CK_OBJECT_HANDLE hKey) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_EncryptInit (funcs, \
                                     session, \
                                     mechanism, \
                                     hKey); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_Encrypt (CK_SESSION_HANDLE session, \
                                    unsigned char * data, \
                                    long unsigned int ulDataLen, \
                                    unsigned char * encrypted_data, \
                                    long unsigned int * encrypted_data_len) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_Encrypt (funcs, \
                                 session, \
                                 data, \
                                 ulDataLen, \
                                 encrypted_data, \
                                 encrypted_data_len); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_EncryptUpdate (CK_SESSION_HANDLE session, \
                                          unsigned char * part, \
                                          long unsigned int part_len, \
                                          unsigned char * encrypted_part, \
                                          long unsigned int * encrypted_part_len) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_EncryptUpdate (funcs, \
                                       session, \
                                       part, \
                                       part_len, \
                                       encrypted_part, \
                                       encrypted_part_len); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_EncryptFinal (CK_SESSION_HANDLE session, \
                                         unsigned char * last_encrypted_part, \
                                         long unsigned int * last_encrypted_part_len) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_EncryptFinal (funcs, \
                                      session, \
                                      last_encrypted_part, \
                                      last_encrypted_part_len); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_DecryptInit (CK_SESSION_HANDLE session, \
                                        CK_MECHANISM_PTR mechanism, \
                                        CK_OBJECT_HANDLE hKey) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_DecryptInit (funcs, \
                                     session, \
                                     mechanism, \
                                     hKey); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_Decrypt (CK_SESSION_HANDLE session, \
                                    unsigned char * encrypted_data, \
                                    long unsigned int encrypted_data_len, \
                                    unsigned char * data, \
                                    long unsigned int * ulDataLen) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_Decrypt (funcs, \
                                 session, \
                                 encrypted_data, \
                                 encrypted_data_len, \
                                 data, \
                                 ulDataLen); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_DecryptUpdate (CK_SESSION_HANDLE session, \
                                          unsigned char * encrypted_part, \
                                          long unsigned int encrypted_part_len, \
                                          unsigned char * part, \
                                          long unsigned int * part_len) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_DecryptUpdate (funcs, \
                                       session, \
                                       encrypted_part, \
                                       encrypted_part_len, \
                                       part, \
                                       part_len); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_DecryptFinal (CK_SESSION_HANDLE session, \
                                         unsigned char * last_part, \
                                         long unsigned int * last_part_len) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_DecryptFinal (funcs, \
                                      session, \
                                      last_part, \
                                      last_part_len); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_DigestInit (CK_SESSION_HANDLE session, \
                                       CK_MECHANISM_PTR mechanism) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_DigestInit (funcs, \
                                    session, \
                                    mechanism); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_Digest (CK_SESSION_HANDLE session, \
                                   unsigned char * data, \
                                   long unsigned int ulDataLen, \
                                   unsigned char * digest, \
                                   long unsigned int * digest_len) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_Digest (funcs, \
                                session, \
                                data, \
                                ulDataLen, \
                                digest, \
                                digest_len); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_DigestUpdate (CK_SESSION_HANDLE session, \
                                         unsigned char * part, \
                                         long unsigned int part_len) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_DigestUpdate (funcs, \
                                      session, \
                                      part, \
                                      part_len); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_DigestKey (CK_SESSION_HANDLE session, \
                                      CK_OBJECT_HANDLE hKey) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_DigestKey (funcs, \
                                   session, \
                                   hKey); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_DigestFinal (CK_SESSION_HANDLE session, \
                                        unsigned char * digest, \
                                        long unsigned int * digest_len) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_DigestFinal (funcs, \
                                     session, \
                                     digest, \
                                     digest_len); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_SignInit (CK_SESSION_HANDLE session, \
                                     CK_MECHANISM_PTR mechanism, \
                                     CK_OBJECT_HANDLE hKey) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_SignInit (funcs, \
                                  session, \
                                  mechanism, \
                                  hKey); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_Sign (CK_SESSION_HANDLE session, \
                                 unsigned char * data, \
                                 long unsigned int ulDataLen, \
                                 unsigned char * signature, \
                                 long unsigned int * signature_len) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_Sign (funcs, \
                              session, \
                              data, \
                              ulDataLen, \
                              signature, \
                              signature_len); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_SignUpdate (CK_SESSION_HANDLE session, \
                                       unsigned char * part, \
                                       long unsigned int part_len) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_SignUpdate (funcs, \
                                    session, \
                                    part, \
                                    part_len); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_SignFinal (CK_SESSION_HANDLE session, \
                                      unsigned char * signature, \
                                      long unsigned int * signature_len) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_SignFinal (funcs, \
                                   session, \
                                   signature, \
                                   signature_len); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_SignRecoverInit (CK_SESSION_HANDLE session, \
                                            CK_MECHANISM_PTR mechanism, \
                                            CK_OBJECT_HANDLE hKey) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_SignRecoverInit (funcs, \
                                         session, \
                                         mechanism, \
                                         hKey); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_SignRecover (CK_SESSION_HANDLE session, \
                                        unsigned char * data, \
                                        long unsigned int ulDataLen, \
                                        unsigned char * signature, \
                                        long unsigned int * signature_len) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_SignRecover (funcs, \
                                     session, \
                                     data, \
                                     ulDataLen, \
                                     signature, \
                                     signature_len); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_VerifyInit (CK_SESSION_HANDLE session, \
                                       CK_MECHANISM_PTR mechanism, \
                                       CK_OBJECT_HANDLE hKey) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_VerifyInit (funcs, \
                                    session, \
                                    mechanism, \
                                    hKey); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_Verify (CK_SESSION_HANDLE session, \
                                   unsigned char * data, \
                                   long unsigned int ulDataLen, \
                                   unsigned char * signature, \
                                   long unsigned int signature_len) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_Verify (funcs, \
                                session, \
                                data, \
                                ulDataLen, \
                                signature, \
                                signature_len); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_VerifyUpdate (CK_SESSION_HANDLE session, \
                                         unsigned char * part, \
                                         long unsigned int part_len) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_VerifyUpdate (funcs, \
                                      session, \
                                      part, \
                                      part_len); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_VerifyFinal (CK_SESSION_HANDLE session, \
                                        unsigned char * signature, \
                                        long unsigned int signature_len) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_VerifyFinal (funcs, \
                                     session, \
                                     signature, \
                                     signature_len); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_VerifyRecoverInit (CK_SESSION_HANDLE session, \
                                              CK_MECHANISM_PTR mechanism, \
                                              CK_OBJECT_HANDLE hKey) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_VerifyRecoverInit (funcs, \
                                           session, \
                                           mechanism, \
                                           hKey); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_VerifyRecover (CK_SESSION_HANDLE session, \
                                          unsigned char * signature, \
                                          long unsigned int signature_len, \
                                          unsigned char * data, \
                                          long unsigned int * ulDataLen) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_VerifyRecover (funcs, \
                                       session, \
                                       signature, \
                                       signature_len, \
                                       data, \
                                       ulDataLen); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_DigestEncryptUpdate (CK_SESSION_HANDLE session, \
                                                unsigned char * part, \
                                                long unsigned int part_len, \
                                                unsigned char * encrypted_part, \
                                                long unsigned int * encrypted_part_len) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_DigestEncryptUpdate (funcs, \
                                             session, \
                                             part, \
                                             part_len, \
                                             encrypted_part, \
                                             encrypted_part_len); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_DecryptDigestUpdate (CK_SESSION_HANDLE session, \
                                                unsigned char * encrypted_part, \
                                                long unsigned int encrypted_part_len, \
                                                unsigned char * part, \
                                                long unsigned int * part_len) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_DecryptDigestUpdate (funcs, \
                                             session, \
                                             encrypted_part, \
                                             encrypted_part_len, \
                                             part, \
                                             part_len); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_SignEncryptUpdate (CK_SESSION_HANDLE session, \
                                              unsigned char * part, \
                                              long unsigned int part_len, \
                                              unsigned char * encrypted_part, \
                                              long unsigned int * encrypted_part_len) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_SignEncryptUpdate (funcs, \
                                           session, \
                                           part, \
                                           part_len, \
                                           encrypted_part, \
                                           encrypted_part_len); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_DecryptVerifyUpdate (CK_SESSION_HANDLE session, \
                                                unsigned char * encrypted_part, \
                                                long unsigned int encrypted_part_len, \
                                                unsigned char * part, \
                                                long unsigned int * part_len) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_DecryptVerifyUpdate (funcs, \
                                             session, \
                                             encrypted_part, \
                                             encrypted_part_len, \
                                             part, \
                                             part_len); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_GenerateKey (CK_SESSION_HANDLE session, \
                                        CK_MECHANISM_PTR mechanism, \
                                        CK_ATTRIBUTE_PTR pTemplate, \
                                        long unsigned int ulCount, \
                                        CK_OBJECT_HANDLE_PTR hKey) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_GenerateKey (funcs, \
                                     session, \
                                     mechanism, \
                                     pTemplate, \
                                     ulCount, \
                                     hKey); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_GenerateKeyPair (CK_SESSION_HANDLE session, \
                                            CK_MECHANISM_PTR mechanism, \
                                            CK_ATTRIBUTE_PTR public_key_template, \
                                            long unsigned int public_key_attribute_count, \
                                            CK_ATTRIBUTE_PTR private_key_template, \
                                            long unsigned int private_key_attribute_count, \
                                            CK_OBJECT_HANDLE_PTR publicKey, \
                                            CK_OBJECT_HANDLE_PTR private_key) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_GenerateKeyPair (funcs, \
                                         session, \
                                         mechanism, \
                                         public_key_template, \
                                         public_key_attribute_count, \
                                         private_key_template, \
                                         private_key_attribute_count, \
                                         publicKey, \
                                         private_key); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_WrapKey (CK_SESSION_HANDLE session, \
                                    CK_MECHANISM_PTR mechanism, \
                                    CK_OBJECT_HANDLE wrapping_key, \
                                    CK_OBJECT_HANDLE hKey, \
                                    unsigned char * wrapped_key, \
                                    long unsigned int * wrapped_key_len) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_WrapKey (funcs, \
                                 session, \
                                 mechanism, \
                                 wrapping_key, \
                                 hKey, \
                                 wrapped_key, \
                                 wrapped_key_len); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_UnwrapKey (CK_SESSION_HANDLE session, \
                                      CK_MECHANISM_PTR mechanism, \
                                      CK_OBJECT_HANDLE unwrapping_key, \
                                      unsigned char * wrapped_key, \
                                      long unsigned int wrapped_key_len, \
                                      CK_ATTRIBUTE_PTR pTemplate, \
                                      long unsigned int ulAttributeCount, \
                                      CK_OBJECT_HANDLE_PTR hKey) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_UnwrapKey (funcs, \
                                   session, \
                                   mechanism, \
                                   unwrapping_key, \
                                   wrapped_key, \
                                   wrapped_key_len, \
                                   pTemplate, \
                                   ulAttributeCount, \
                                   hKey); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_DeriveKey (CK_SESSION_HANDLE session, \
                                      CK_MECHANISM_PTR mechanism, \
                                      CK_OBJECT_HANDLE base_key, \
                                      CK_ATTRIBUTE_PTR pTemplate, \
                                      long unsigned int ulAttributeCount, \
                                      CK_OBJECT_HANDLE_PTR hKey) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_DeriveKey (funcs, \
                                   session, \
                                   mechanism, \
                                   base_key, \
                                   pTemplate, \
                                   ulAttributeCount, \
                                   hKey); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_SeedRandom (CK_SESSION_HANDLE session, \
                                       unsigned char * seed, \
                                       long unsigned int ulSeedLen) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_SeedRandom (funcs, \
                                    session, \
                                    seed, \
                                    ulSeedLen); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_GenerateRandom (CK_SESSION_HANDLE session, \
                                           unsigned char * random_data, \
                                           long unsigned int ulRandomLen) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_GenerateRandom (funcs, \
                                        session, \
                                        random_data, \
                                        ulRandomLen); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_WaitForSlotEvent (CK_FLAGS flags, \
                                             CK_SLOT_ID_PTR slot, \
                                             CK_VOID_PTR pReserved) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_WaitForSlotEvent (funcs, \
                                          flags, \
                                          slot, \
                                          pReserved); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_LoginUser (CK_SESSION_HANDLE session, \
                                      CK_USER_TYPE user_type, \
                                      unsigned char * pin, \
                                      long unsigned int pin_len, \
                                      unsigned char * username, \
                                      long unsigned int username_len) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_LoginUser (funcs, \
                                   session, \
                                   user_type, \
                                   pin, \
                                   pin_len, \
                                   username, \
                                   username_len); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_SessionCancel (CK_SESSION_HANDLE session, \
                                          CK_FLAGS flags) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_SessionCancel (funcs, \
                                       session, \
                                       flags); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_MessageEncryptInit (CK_SESSION_HANDLE session, \
                                               CK_MECHANISM_PTR mechanism, \
                                               CK_OBJECT_HANDLE hKey) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_MessageEncryptInit (funcs, \
                                            session, \
                                            mechanism, \
                                            hKey); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_EncryptMessage (CK_SESSION_HANDLE session, \
                                           CK_VOID_PTR pParameter, \
                                           long unsigned int ulParameterLen, \
                                           unsigned char * associated_data, \
                                           long unsigned int associated_data_len, \
                                           unsigned char * plaintext, \
                                           long unsigned int plaintext_len, \
                                           unsigned char * ciphertext, \
                                           long unsigned int * ciphertext_len) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_EncryptMessage (funcs, \
                                        session, \
                                        pParameter, \
                                        ulParameterLen, \
                                        associated_data, \
                                        associated_data_len, \
                                        plaintext, \
                                        plaintext_len, \
                                        ciphertext, \
                                        ciphertext_len); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_EncryptMessageBegin (CK_SESSION_HANDLE session, \
                                                CK_VOID_PTR pParameter, \
                                                long unsigned int ulParameterLen, \
                                                unsigned char * associated_data, \
                                                long unsigned int associated_data_len) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_EncryptMessageBegin (funcs, \
                                             session, \
                                             pParameter, \
                                             ulParameterLen, \
                                             associated_data, \
                                             associated_data_len); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_EncryptMessageNext (CK_SESSION_HANDLE session, \
                                               CK_VOID_PTR pParameter, \
                                               long unsigned int ulParameterLen, \
                                               unsigned char * plaintext_part, \
                                               long unsigned int plaintext_part_len, \
                                               unsigned char * ciphertext_part, \
                                               long unsigned int * ciphertext_part_len, \
                                               CK_FLAGS flags) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_EncryptMessageNext (funcs, \
                                            session, \
                                            pParameter, \
                                            ulParameterLen, \
                                            plaintext_part, \
                                            plaintext_part_len, \
                                            ciphertext_part, \
                                            ciphertext_part_len, \
                                            flags); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_MessageEncryptFinal (CK_SESSION_HANDLE session) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_MessageEncryptFinal (funcs, \
                                             session); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_MessageDecryptInit (CK_SESSION_HANDLE session, \
                                               CK_MECHANISM_PTR mechanism, \
                                               CK_OBJECT_HANDLE hKey) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_MessageDecryptInit (funcs, \
                                            session, \
                                            mechanism, \
                                            hKey); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_DecryptMessage (CK_SESSION_HANDLE session, \
                                           CK_VOID_PTR pParameter, \
                                           long unsigned int ulParameterLen, \
                                           unsigned char * associated_data, \
                                           long unsigned int associated_data_len, \
                                           unsigned char * ciphertext, \
                                           long unsigned int ciphertext_len, \
                                           unsigned char * plaintext, \
                                           long unsigned int * plaintext_len) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_DecryptMessage (funcs, \
                                        session, \
                                        pParameter, \
                                        ulParameterLen, \
                                        associated_data, \
                                        associated_data_len, \
                                        ciphertext, \
                                        ciphertext_len, \
                                        plaintext, \
                                        plaintext_len); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_DecryptMessageBegin (CK_SESSION_HANDLE session, \
                                                CK_VOID_PTR pParameter, \
                                                long unsigned int ulParameterLen, \
                                                unsigned char * associated_data, \
                                                long unsigned int associated_data_len) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_DecryptMessageBegin (funcs, \
                                             session, \
                                             pParameter, \
                                             ulParameterLen, \
                                             associated_data, \
                                             associated_data_len); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_DecryptMessageNext (CK_SESSION_HANDLE session, \
                                               CK_VOID_PTR pParameter, \
                                               long unsigned int ulParameterLen, \
                                               unsigned char * ciphertext_part, \
                                               long unsigned int ciphertext_part_len, \
                                               unsigned char * plaintext_part, \
                                               long unsigned int * plaintext_part_len, \
                                               CK_FLAGS flags) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_DecryptMessageNext (funcs, \
                                            session, \
                                            pParameter, \
                                            ulParameterLen, \
                                            ciphertext_part, \
                                            ciphertext_part_len, \
                                            plaintext_part, \
                                            plaintext_part_len, \
                                            flags); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_MessageDecryptFinal (CK_SESSION_HANDLE session) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_MessageDecryptFinal (funcs, \
                                             session); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_MessageSignInit (CK_SESSION_HANDLE session, \
                                            CK_MECHANISM_PTR mechanism, \
                                            CK_OBJECT_HANDLE hKey) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_MessageSignInit (funcs, \
                                         session, \
                                         mechanism, \
                                         hKey); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_SignMessage (CK_SESSION_HANDLE session, \
                                        CK_VOID_PTR pParameter, \
                                        long unsigned int ulParameterLen, \
                                        unsigned char * data, \
                                        long unsigned int ulDataLen, \
                                        unsigned char * signature, \
                                        long unsigned int * signature_len) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_SignMessage (funcs, \
                                     session, \
                                     pParameter, \
                                     ulParameterLen, \
                                     data, \
                                     ulDataLen, \
                                     signature, \
                                     signature_len); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_SignMessageBegin (CK_SESSION_HANDLE session, \
                                             CK_VOID_PTR pParameter, \
                                             long unsigned int ulParameterLen) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_SignMessageBegin (funcs, \
                                          session, \
                                          pParameter, \
                                          ulParameterLen); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_SignMessageNext (CK_SESSION_HANDLE session, \
                                            CK_VOID_PTR pParameter, \
                                            long unsigned int ulParameterLen, \
                                            unsigned char * data, \
                                            long unsigned int ulDataLen, \
                                            unsigned char * signature, \
                                            long unsigned int * signature_len) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_SignMessageNext (funcs, \
                                         session, \
                                         pParameter, \
                                         ulParameterLen, \
                                         data, \
                                         ulDataLen, \
                                         signature, \
                                         signature_len); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_MessageSignFinal (CK_SESSION_HANDLE session) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_MessageSignFinal (funcs, \
                                          session); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_MessageVerifyInit (CK_SESSION_HANDLE session, \
                                              CK_MECHANISM_PTR mechanism, \
                                              CK_OBJECT_HANDLE hKey) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_MessageVerifyInit (funcs, \
                                           session, \
                                           mechanism, \
                                           hKey); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_VerifyMessage (CK_SESSION_HANDLE session, \
                                          CK_VOID_PTR pParameter, \
                                          long unsigned int ulParameterLen, \
                                          unsigned char * data, \
                                          long unsigned int ulDataLen, \
                                          unsigned char * signature, \
                                          long unsigned int signature_len) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_VerifyMessage (funcs, \
                                       session, \
                                       pParameter, \
                                       ulParameterLen, \
                                       data, \
                                       ulDataLen, \
                                       signature, \
                                       signature_len); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_VerifyMessageBegin (CK_SESSION_HANDLE session, \
                                               CK_VOID_PTR pParameter, \
                                               long unsigned int ulParameterLen) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_VerifyMessageBegin (funcs, \
                                            session, \
                                            pParameter, \
                                            ulParameterLen); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_VerifyMessageNext (CK_SESSION_HANDLE session, \
                                              CK_VOID_PTR pParameter, \
                                              long unsigned int ulParameterLen, \
                                              unsigned char * data, \
                                              long unsigned int ulDataLen, \
                                              unsigned char * signature, \
                                              long unsigned int signature_len) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_VerifyMessageNext (funcs, \
                                           session, \
                                           pParameter, \
                                           ulParameterLen, \
                                           data, \
                                           ulDataLen, \
                                           signature, \
                                           signature_len); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_MessageVerifyFinal (CK_SESSION_HANDLE session) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_MessageVerifyFinal (funcs, \
                                            session); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_EncapsulateKey (CK_SESSION_HANDLE session, \
                                           CK_MECHANISM_PTR mechanism, \
                                           CK_OBJECT_HANDLE publicKey, \
                                           CK_ATTRIBUTE_PTR pTemplate, \
                                           long unsigned int ulAttributeCount, \
                                           unsigned char * ciphertext, \
                                           long unsigned int * ciphertext_len, \
                                           CK_OBJECT_HANDLE_PTR phKey) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_EncapsulateKey (funcs, \
                                        session, \
                                        mechanism, \
                                        publicKey, \
                                        pTemplate, \
                                        ulAttributeCount, \
                                        ciphertext, \
                                        ciphertext_len, \
                                        phKey); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_DecapsulateKey (CK_SESSION_HANDLE session, \
                                           CK_MECHANISM_PTR mechanism, \
                                           CK_OBJECT_HANDLE private_key, \
                                           CK_ATTRIBUTE_PTR pTemplate, \
                                           long unsigned int ulAttributeCount, \
                                           unsigned char * ciphertext, \
                                           long unsigned int * ciphertext_len, \
                                           CK_OBJECT_HANDLE_PTR phKey) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_DecapsulateKey (funcs, \
                                        session, \
                                        mechanism, \
                                        private_key, \
                                        pTemplate, \
                                        ulAttributeCount, \
                                        ciphertext, \
                                        ciphertext_len, \
                                        phKey); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_VerifySignatureInit (CK_SESSION_HANDLE session, \
                                                CK_MECHANISM_PTR mechanism, \
                                                CK_OBJECT_HANDLE hKey, \
                                                unsigned char * signature, \
                                                long unsigned int signature_len) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_VerifySignatureInit (funcs, \
                                             session, \
                                             mechanism, \
                                             hKey, \
                                             signature, \
                                             signature_len); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_VerifySignature (CK_SESSION_HANDLE session, \
                                            unsigned char * data, \
                                            long unsigned int ulDataLen) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_VerifySignature (funcs, \
                                         session, \
                                         data, \
                                         ulDataLen); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_VerifySignatureUpdate (CK_SESSION_HANDLE session, \
                                                  unsigned char * part, \
                                                  long unsigned int part_len) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_VerifySignatureUpdate (funcs, \
                                               session, \
                                               part, \
                                               part_len); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_VerifySignatureFinal (CK_SESSION_HANDLE session) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_VerifySignatureFinal (funcs, \
                                              session); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_GetSessionValidationFlags (CK_SESSION_HANDLE session, \
                                                      CK_SESSION_VALIDATION_FLAGS_TYPE type, \
                                                      CK_FLAGS * flags_ptr) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_GetSessionValidationFlags (funcs, \
                                                   session, \
                                                   type, \
                                                   flags_ptr); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_AsyncComplete (CK_SESSION_HANDLE session, \
                                          unsigned char * function_name, \
                                          CK_ASYNC_DATA_PTR result) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_AsyncComplete (funcs, \
                                       session, \
                                       function_name, \
                                       result); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_AsyncGetID (CK_SESSION_HANDLE session, \
                                       unsigned char * function_name, \
                                       long unsigned int * id_ptr) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_AsyncGetID (funcs, \
                                    session, \
                                    function_name, \
                                    id_ptr); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_AsyncJoin (CK_SESSION_HANDLE session, \
                                      unsigned char * function_name, \
                                      long unsigned int id, \
                                      unsigned char * data, \
                                      long unsigned int ulDataLen) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_AsyncJoin (funcs, \
                                   session, \
                                   function_name, \
                                   id, \
                                   data, \
                                   ulDataLen); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_WrapKeyAuthenticated (CK_SESSION_HANDLE session, \
                                                 CK_MECHANISM_PTR mechanism, \
                                                 CK_OBJECT_HANDLE wrapping_key, \
                                                 CK_OBJECT_HANDLE hKey, \
                                                 unsigned char * associated_data, \
                                                 long unsigned int associated_data_len, \
                                                 unsigned char * wrapped_key, \
                                                 long unsigned int * wrapped_key_len) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_WrapKeyAuthenticated (funcs, \
                                              session, \
                                              mechanism, \
                                              wrapping_key, \
                                              hKey, \
                                              associated_data, \
                                              associated_data_len, \
                                              wrapped_key, \
                                              wrapped_key_len); \
} \
\
static CK_RV \
fixed ## fixed_index ## _C_UnwrapKeyAuthenticated (CK_SESSION_HANDLE session, \
                                                   CK_MECHANISM_PTR mechanism, \
                                                   CK_OBJECT_HANDLE unwrapping_key, \
                                                   unsigned char * wrapped_key, \
                                                   long unsigned int wrapped_key_len, \
                                                   CK_ATTRIBUTE_PTR pTemplate, \
                                                   long unsigned int ulAttributeCount, \
                                                   unsigned char * associated_data, \
                                                   long unsigned int associated_data_len, \
                                                   CK_OBJECT_HANDLE_PTR phKey) \
{ \
        CK_FUNCTION_LIST_3_2 *bound; \
        Wrapper *wrapper; \
        CK_X_FUNCTION_LIST *funcs; \
        bound = fixed_closures[fixed_index]; \
        return_val_if_fail (bound != NULL, CKR_GENERAL_ERROR); \
        wrapper = (Wrapper *) bound; \
        funcs = &wrapper->virt->funcs; \
        return funcs->C_UnwrapKeyAuthenticated (funcs, \
                                                session, \
                                                mechanism, \
                                                unwrapping_key, \
                                                wrapped_key, \
                                                wrapped_key_len, \
                                                pTemplate, \
                                                ulAttributeCount, \
                                                associated_data, \
                                                associated_data_len, \
                                                phKey); \
} \
static CK_RV \
fixed ## fixed_index ## _C_GetFunctionList (CK_FUNCTION_LIST_PTR_PTR list); \
\
static CK_RV \
fixed ## fixed_index ## _C_GetInterfaceList (CK_INTERFACE_PTR pInterfacesList, \
                                             CK_ULONG_PTR pulCount); \
\
static CK_RV \
fixed ## fixed_index ## _C_GetInterface (CK_UTF8CHAR_PTR pInterfaceName, \
                                         CK_VERSION_PTR pVersion, \
                                         CK_INTERFACE_PTR_PTR ppInterface, \
                                         CK_FLAGS flags);

#define P11_VIRTUAL_FIXED_GET_FUNCTION_LIST(fixed_index) \
static CK_RV \
fixed ## fixed_index ## _C_GetFunctionList (CK_FUNCTION_LIST_PTR_PTR list) \
{ \
        if (!list) \
                return CKR_ARGUMENTS_BAD; \
        *list = (CK_FUNCTION_LIST *)fixed_closures[fixed_index]; \
        return CKR_OK; \
}

#define P11_VIRTUAL_FIXED_GET_INTERFACE_LIST(fixed_index) \
static CK_RV \
fixed ## fixed_index ## _C_GetInterfaceList (CK_INTERFACE_PTR pInterfacesList, \
                                             CK_ULONG_PTR pulCount) \
{ \
        CK_RV rv = CKR_OK; \
\
        if (pulCount == NULL_PTR) \
                return CKR_ARGUMENTS_BAD; \
\
        if (pInterfacesList == NULL_PTR) { \
                *pulCount = 1; \
                return CKR_OK; \
        } \
\
        if (*pulCount < 1) { \
                *pulCount = 1; \
                return CKR_BUFFER_TOO_SMALL; \
        } \
\
        if (rv == CKR_OK) { \
                memcpy (pInterfacesList, \
                        fixed_interfaces[fixed_index], \
                        sizeof(CK_INTERFACE)); \
                *pulCount = 1; \
        } \
\
        return rv; \
}

#define P11_VIRTUAL_FIXED_GET_INTERFACE(fixed_index) \
static CK_RV \
fixed ## fixed_index ## _C_GetInterface (CK_UTF8CHAR_PTR pInterfaceName, \
                                         CK_VERSION_PTR pVersion, \
                                         CK_INTERFACE_PTR_PTR ppInterface, \
                                         CK_FLAGS flags) \
{ \
        CK_INTERFACE_PTR interface = fixed_interfaces[fixed_index]; \
        CK_VERSION_PTR cmp_version = &fixed_closures[fixed_index]->version; \
\
        if (ppInterface == NULL_PTR) { \
                return CKR_ARGUMENTS_BAD; \
        } \
\
        if (pInterfaceName == NULL) { \
                *ppInterface = interface; \
                return CKR_OK; \
        } \
\
        if (strcmp ((char *)pInterfaceName, interface->pInterfaceName) != 0 || \
            (pVersion != NULL && (pVersion->major != cmp_version->major || \
                                  pVersion->minor != cmp_version->minor)) || \
            ((flags & interface->flags) != flags)) { \
                return CKR_ARGUMENTS_BAD; \
        } \
        *ppInterface = interface; \
        return CKR_OK; \
}

#define P11_VIRTUAL_FIXED_INITIALIZER(fixed_index) \
{ \
        { CRYPTOKI_VERSION_MAJOR, CRYPTOKI_VERSION_MINOR },  /* version */ \
        fixed ## fixed_index ## _C_Initialize, \
        fixed ## fixed_index ## _C_Finalize, \
        fixed ## fixed_index ## _C_GetInfo, \
        fixed ## fixed_index ## _C_GetFunctionList, \
        fixed ## fixed_index ## _C_GetSlotList, \
        fixed ## fixed_index ## _C_GetSlotInfo, \
        fixed ## fixed_index ## _C_GetTokenInfo, \
        fixed ## fixed_index ## _C_GetMechanismList, \
        fixed ## fixed_index ## _C_GetMechanismInfo, \
        fixed ## fixed_index ## _C_InitToken, \
        fixed ## fixed_index ## _C_InitPIN, \
        fixed ## fixed_index ## _C_SetPIN, \
        fixed ## fixed_index ## _C_OpenSession, \
        fixed ## fixed_index ## _C_CloseSession, \
        fixed ## fixed_index ## _C_CloseAllSessions, \
        fixed ## fixed_index ## _C_GetSessionInfo, \
        fixed ## fixed_index ## _C_GetOperationState, \
        fixed ## fixed_index ## _C_SetOperationState, \
        fixed ## fixed_index ## _C_Login, \
        fixed ## fixed_index ## _C_Logout, \
        fixed ## fixed_index ## _C_CreateObject, \
        fixed ## fixed_index ## _C_CopyObject, \
        fixed ## fixed_index ## _C_DestroyObject, \
        fixed ## fixed_index ## _C_GetObjectSize, \
        fixed ## fixed_index ## _C_GetAttributeValue, \
        fixed ## fixed_index ## _C_SetAttributeValue, \
        fixed ## fixed_index ## _C_FindObjectsInit, \
        fixed ## fixed_index ## _C_FindObjects, \
        fixed ## fixed_index ## _C_FindObjectsFinal, \
        fixed ## fixed_index ## _C_EncryptInit, \
        fixed ## fixed_index ## _C_Encrypt, \
        fixed ## fixed_index ## _C_EncryptUpdate, \
        fixed ## fixed_index ## _C_EncryptFinal, \
        fixed ## fixed_index ## _C_DecryptInit, \
        fixed ## fixed_index ## _C_Decrypt, \
        fixed ## fixed_index ## _C_DecryptUpdate, \
        fixed ## fixed_index ## _C_DecryptFinal, \
        fixed ## fixed_index ## _C_DigestInit, \
        fixed ## fixed_index ## _C_Digest, \
        fixed ## fixed_index ## _C_DigestUpdate, \
        fixed ## fixed_index ## _C_DigestKey, \
        fixed ## fixed_index ## _C_DigestFinal, \
        fixed ## fixed_index ## _C_SignInit, \
        fixed ## fixed_index ## _C_Sign, \
        fixed ## fixed_index ## _C_SignUpdate, \
        fixed ## fixed_index ## _C_SignFinal, \
        fixed ## fixed_index ## _C_SignRecoverInit, \
        fixed ## fixed_index ## _C_SignRecover, \
        fixed ## fixed_index ## _C_VerifyInit, \
        fixed ## fixed_index ## _C_Verify, \
        fixed ## fixed_index ## _C_VerifyUpdate, \
        fixed ## fixed_index ## _C_VerifyFinal, \
        fixed ## fixed_index ## _C_VerifyRecoverInit, \
        fixed ## fixed_index ## _C_VerifyRecover, \
        fixed ## fixed_index ## _C_DigestEncryptUpdate, \
        fixed ## fixed_index ## _C_DecryptDigestUpdate, \
        fixed ## fixed_index ## _C_SignEncryptUpdate, \
        fixed ## fixed_index ## _C_DecryptVerifyUpdate, \
        fixed ## fixed_index ## _C_GenerateKey, \
        fixed ## fixed_index ## _C_GenerateKeyPair, \
        fixed ## fixed_index ## _C_WrapKey, \
        fixed ## fixed_index ## _C_UnwrapKey, \
        fixed ## fixed_index ## _C_DeriveKey, \
        fixed ## fixed_index ## _C_SeedRandom, \
        fixed ## fixed_index ## _C_GenerateRandom, \
        short_C_GetFunctionStatus, \
        short_C_CancelFunction, \
        fixed ## fixed_index ## _C_WaitForSlotEvent, \
        fixed ## fixed_index ## _C_GetInterfaceList, \
        fixed ## fixed_index ## _C_GetInterface, \
        fixed ## fixed_index ## _C_LoginUser, \
        fixed ## fixed_index ## _C_SessionCancel, \
        fixed ## fixed_index ## _C_MessageEncryptInit, \
        fixed ## fixed_index ## _C_EncryptMessage, \
        fixed ## fixed_index ## _C_EncryptMessageBegin, \
        fixed ## fixed_index ## _C_EncryptMessageNext, \
        fixed ## fixed_index ## _C_MessageEncryptFinal, \
        fixed ## fixed_index ## _C_MessageDecryptInit, \
        fixed ## fixed_index ## _C_DecryptMessage, \
        fixed ## fixed_index ## _C_DecryptMessageBegin, \
        fixed ## fixed_index ## _C_DecryptMessageNext, \
        fixed ## fixed_index ## _C_MessageDecryptFinal, \
        fixed ## fixed_index ## _C_MessageSignInit, \
        fixed ## fixed_index ## _C_SignMessage, \
        fixed ## fixed_index ## _C_SignMessageBegin, \
        fixed ## fixed_index ## _C_SignMessageNext, \
        fixed ## fixed_index ## _C_MessageSignFinal, \
        fixed ## fixed_index ## _C_MessageVerifyInit, \
        fixed ## fixed_index ## _C_VerifyMessage, \
        fixed ## fixed_index ## _C_VerifyMessageBegin, \
        fixed ## fixed_index ## _C_VerifyMessageNext, \
        fixed ## fixed_index ## _C_MessageVerifyFinal, \
        fixed ## fixed_index ## _C_EncapsulateKey, \
        fixed ## fixed_index ## _C_DecapsulateKey, \
        fixed ## fixed_index ## _C_VerifySignatureInit, \
        fixed ## fixed_index ## _C_VerifySignature, \
        fixed ## fixed_index ## _C_VerifySignatureUpdate, \
        fixed ## fixed_index ## _C_VerifySignatureFinal, \
        fixed ## fixed_index ## _C_GetSessionValidationFlags, \
        fixed ## fixed_index ## _C_AsyncComplete, \
        fixed ## fixed_index ## _C_AsyncGetID, \
        fixed ## fixed_index ## _C_AsyncJoin, \
        fixed ## fixed_index ## _C_WrapKeyAuthenticated, \
        fixed ## fixed_index ## _C_UnwrapKeyAuthenticated \
}
