
/* DO NOT EDIT! GENERATED AUTOMATICALLY! */

static void
binding_C_Initialize (ffi_cif *cif,
                      CK_RV *ret,
                      void* args[],
                      CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_Initialize (funcs,
                                    *(CK_VOID_PTR *)args[0]);
}
    
static void
binding_C_Finalize (ffi_cif *cif,
                    CK_RV *ret,
                    void* args[],
                    CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_Finalize (funcs,
                                  *(CK_VOID_PTR *)args[0]);
}
    
static void
binding_C_GetInfo (ffi_cif *cif,
                   CK_RV *ret,
                   void* args[],
                   CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_GetInfo (funcs,
                                 *(CK_INFO_PTR *)args[0]);
}
    
static void
binding_C_GetSlotList (ffi_cif *cif,
                       CK_RV *ret,
                       void* args[],
                       CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_GetSlotList (funcs,
                                     *(unsigned char *)args[0],
                                     *(CK_SLOT_ID_PTR *)args[1],
                                     *(long unsigned int * *)args[2]);
}
    
static void
binding_C_GetSlotInfo (ffi_cif *cif,
                       CK_RV *ret,
                       void* args[],
                       CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_GetSlotInfo (funcs,
                                     *(CK_SLOT_ID *)args[0],
                                     *(CK_SLOT_INFO_PTR *)args[1]);
}
    
static void
binding_C_GetTokenInfo (ffi_cif *cif,
                        CK_RV *ret,
                        void* args[],
                        CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_GetTokenInfo (funcs,
                                      *(CK_SLOT_ID *)args[0],
                                      *(CK_TOKEN_INFO_PTR *)args[1]);
}
    
static void
binding_C_GetMechanismList (ffi_cif *cif,
                            CK_RV *ret,
                            void* args[],
                            CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_GetMechanismList (funcs,
                                          *(CK_SLOT_ID *)args[0],
                                          *(CK_MECHANISM_TYPE_PTR *)args[1],
                                          *(long unsigned int * *)args[2]);
}
    
static void
binding_C_GetMechanismInfo (ffi_cif *cif,
                            CK_RV *ret,
                            void* args[],
                            CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_GetMechanismInfo (funcs,
                                          *(CK_SLOT_ID *)args[0],
                                          *(CK_MECHANISM_TYPE *)args[1],
                                          *(CK_MECHANISM_INFO_PTR *)args[2]);
}
    
static void
binding_C_InitToken (ffi_cif *cif,
                     CK_RV *ret,
                     void* args[],
                     CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_InitToken (funcs,
                                   *(CK_SLOT_ID *)args[0],
                                   *(unsigned char * *)args[1],
                                   *(long unsigned int *)args[2],
                                   *(unsigned char * *)args[3]);
}
    
static void
binding_C_InitPIN (ffi_cif *cif,
                   CK_RV *ret,
                   void* args[],
                   CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_InitPIN (funcs,
                                 *(CK_SESSION_HANDLE *)args[0],
                                 *(unsigned char * *)args[1],
                                 *(long unsigned int *)args[2]);
}
    
static void
binding_C_SetPIN (ffi_cif *cif,
                  CK_RV *ret,
                  void* args[],
                  CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_SetPIN (funcs,
                                *(CK_SESSION_HANDLE *)args[0],
                                *(unsigned char * *)args[1],
                                *(long unsigned int *)args[2],
                                *(unsigned char * *)args[3],
                                *(long unsigned int *)args[4]);
}
    
static void
binding_C_OpenSession (ffi_cif *cif,
                       CK_RV *ret,
                       void* args[],
                       CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_OpenSession (funcs,
                                     *(CK_SLOT_ID *)args[0],
                                     *(CK_FLAGS *)args[1],
                                     *(CK_VOID_PTR *)args[2],
                                     *(CK_NOTIFY *)args[3],
                                     *(CK_SESSION_HANDLE_PTR *)args[4]);
}
    
static void
binding_C_CloseSession (ffi_cif *cif,
                        CK_RV *ret,
                        void* args[],
                        CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_CloseSession (funcs,
                                      *(CK_SESSION_HANDLE *)args[0]);
}
    
static void
binding_C_CloseAllSessions (ffi_cif *cif,
                            CK_RV *ret,
                            void* args[],
                            CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_CloseAllSessions (funcs,
                                          *(CK_SLOT_ID *)args[0]);
}
    
static void
binding_C_GetSessionInfo (ffi_cif *cif,
                          CK_RV *ret,
                          void* args[],
                          CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_GetSessionInfo (funcs,
                                        *(CK_SESSION_HANDLE *)args[0],
                                        *(CK_SESSION_INFO_PTR *)args[1]);
}
    
static void
binding_C_GetOperationState (ffi_cif *cif,
                             CK_RV *ret,
                             void* args[],
                             CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_GetOperationState (funcs,
                                           *(CK_SESSION_HANDLE *)args[0],
                                           *(unsigned char * *)args[1],
                                           *(long unsigned int * *)args[2]);
}
    
static void
binding_C_SetOperationState (ffi_cif *cif,
                             CK_RV *ret,
                             void* args[],
                             CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_SetOperationState (funcs,
                                           *(CK_SESSION_HANDLE *)args[0],
                                           *(unsigned char * *)args[1],
                                           *(long unsigned int *)args[2],
                                           *(CK_OBJECT_HANDLE *)args[3],
                                           *(CK_OBJECT_HANDLE *)args[4]);
}
    
static void
binding_C_Login (ffi_cif *cif,
                 CK_RV *ret,
                 void* args[],
                 CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_Login (funcs,
                               *(CK_SESSION_HANDLE *)args[0],
                               *(CK_USER_TYPE *)args[1],
                               *(unsigned char * *)args[2],
                               *(long unsigned int *)args[3]);
}
    
static void
binding_C_Logout (ffi_cif *cif,
                  CK_RV *ret,
                  void* args[],
                  CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_Logout (funcs,
                                *(CK_SESSION_HANDLE *)args[0]);
}
    
static void
binding_C_CreateObject (ffi_cif *cif,
                        CK_RV *ret,
                        void* args[],
                        CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_CreateObject (funcs,
                                      *(CK_SESSION_HANDLE *)args[0],
                                      *(CK_ATTRIBUTE_PTR *)args[1],
                                      *(long unsigned int *)args[2],
                                      *(CK_OBJECT_HANDLE_PTR *)args[3]);
}
    
static void
binding_C_CopyObject (ffi_cif *cif,
                      CK_RV *ret,
                      void* args[],
                      CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_CopyObject (funcs,
                                    *(CK_SESSION_HANDLE *)args[0],
                                    *(CK_OBJECT_HANDLE *)args[1],
                                    *(CK_ATTRIBUTE_PTR *)args[2],
                                    *(long unsigned int *)args[3],
                                    *(CK_OBJECT_HANDLE_PTR *)args[4]);
}
    
static void
binding_C_DestroyObject (ffi_cif *cif,
                         CK_RV *ret,
                         void* args[],
                         CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_DestroyObject (funcs,
                                       *(CK_SESSION_HANDLE *)args[0],
                                       *(CK_OBJECT_HANDLE *)args[1]);
}
    
static void
binding_C_GetObjectSize (ffi_cif *cif,
                         CK_RV *ret,
                         void* args[],
                         CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_GetObjectSize (funcs,
                                       *(CK_SESSION_HANDLE *)args[0],
                                       *(CK_OBJECT_HANDLE *)args[1],
                                       *(long unsigned int * *)args[2]);
}
    
static void
binding_C_GetAttributeValue (ffi_cif *cif,
                             CK_RV *ret,
                             void* args[],
                             CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_GetAttributeValue (funcs,
                                           *(CK_SESSION_HANDLE *)args[0],
                                           *(CK_OBJECT_HANDLE *)args[1],
                                           *(CK_ATTRIBUTE_PTR *)args[2],
                                           *(long unsigned int *)args[3]);
}
    
static void
binding_C_SetAttributeValue (ffi_cif *cif,
                             CK_RV *ret,
                             void* args[],
                             CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_SetAttributeValue (funcs,
                                           *(CK_SESSION_HANDLE *)args[0],
                                           *(CK_OBJECT_HANDLE *)args[1],
                                           *(CK_ATTRIBUTE_PTR *)args[2],
                                           *(long unsigned int *)args[3]);
}
    
static void
binding_C_FindObjectsInit (ffi_cif *cif,
                           CK_RV *ret,
                           void* args[],
                           CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_FindObjectsInit (funcs,
                                         *(CK_SESSION_HANDLE *)args[0],
                                         *(CK_ATTRIBUTE_PTR *)args[1],
                                         *(long unsigned int *)args[2]);
}
    
static void
binding_C_FindObjects (ffi_cif *cif,
                       CK_RV *ret,
                       void* args[],
                       CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_FindObjects (funcs,
                                     *(CK_SESSION_HANDLE *)args[0],
                                     *(CK_OBJECT_HANDLE_PTR *)args[1],
                                     *(long unsigned int *)args[2],
                                     *(long unsigned int * *)args[3]);
}
    
static void
binding_C_FindObjectsFinal (ffi_cif *cif,
                            CK_RV *ret,
                            void* args[],
                            CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_FindObjectsFinal (funcs,
                                          *(CK_SESSION_HANDLE *)args[0]);
}
    
static void
binding_C_EncryptInit (ffi_cif *cif,
                       CK_RV *ret,
                       void* args[],
                       CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_EncryptInit (funcs,
                                     *(CK_SESSION_HANDLE *)args[0],
                                     *(CK_MECHANISM_PTR *)args[1],
                                     *(CK_OBJECT_HANDLE *)args[2]);
}
    
static void
binding_C_Encrypt (ffi_cif *cif,
                   CK_RV *ret,
                   void* args[],
                   CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_Encrypt (funcs,
                                 *(CK_SESSION_HANDLE *)args[0],
                                 *(unsigned char * *)args[1],
                                 *(long unsigned int *)args[2],
                                 *(unsigned char * *)args[3],
                                 *(long unsigned int * *)args[4]);
}
    
static void
binding_C_EncryptUpdate (ffi_cif *cif,
                         CK_RV *ret,
                         void* args[],
                         CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_EncryptUpdate (funcs,
                                       *(CK_SESSION_HANDLE *)args[0],
                                       *(unsigned char * *)args[1],
                                       *(long unsigned int *)args[2],
                                       *(unsigned char * *)args[3],
                                       *(long unsigned int * *)args[4]);
}
    
static void
binding_C_EncryptFinal (ffi_cif *cif,
                        CK_RV *ret,
                        void* args[],
                        CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_EncryptFinal (funcs,
                                      *(CK_SESSION_HANDLE *)args[0],
                                      *(unsigned char * *)args[1],
                                      *(long unsigned int * *)args[2]);
}
    
static void
binding_C_DecryptInit (ffi_cif *cif,
                       CK_RV *ret,
                       void* args[],
                       CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_DecryptInit (funcs,
                                     *(CK_SESSION_HANDLE *)args[0],
                                     *(CK_MECHANISM_PTR *)args[1],
                                     *(CK_OBJECT_HANDLE *)args[2]);
}
    
static void
binding_C_Decrypt (ffi_cif *cif,
                   CK_RV *ret,
                   void* args[],
                   CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_Decrypt (funcs,
                                 *(CK_SESSION_HANDLE *)args[0],
                                 *(unsigned char * *)args[1],
                                 *(long unsigned int *)args[2],
                                 *(unsigned char * *)args[3],
                                 *(long unsigned int * *)args[4]);
}
    
static void
binding_C_DecryptUpdate (ffi_cif *cif,
                         CK_RV *ret,
                         void* args[],
                         CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_DecryptUpdate (funcs,
                                       *(CK_SESSION_HANDLE *)args[0],
                                       *(unsigned char * *)args[1],
                                       *(long unsigned int *)args[2],
                                       *(unsigned char * *)args[3],
                                       *(long unsigned int * *)args[4]);
}
    
static void
binding_C_DecryptFinal (ffi_cif *cif,
                        CK_RV *ret,
                        void* args[],
                        CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_DecryptFinal (funcs,
                                      *(CK_SESSION_HANDLE *)args[0],
                                      *(unsigned char * *)args[1],
                                      *(long unsigned int * *)args[2]);
}
    
static void
binding_C_DigestInit (ffi_cif *cif,
                      CK_RV *ret,
                      void* args[],
                      CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_DigestInit (funcs,
                                    *(CK_SESSION_HANDLE *)args[0],
                                    *(CK_MECHANISM_PTR *)args[1]);
}
    
static void
binding_C_Digest (ffi_cif *cif,
                  CK_RV *ret,
                  void* args[],
                  CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_Digest (funcs,
                                *(CK_SESSION_HANDLE *)args[0],
                                *(unsigned char * *)args[1],
                                *(long unsigned int *)args[2],
                                *(unsigned char * *)args[3],
                                *(long unsigned int * *)args[4]);
}
    
static void
binding_C_DigestUpdate (ffi_cif *cif,
                        CK_RV *ret,
                        void* args[],
                        CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_DigestUpdate (funcs,
                                      *(CK_SESSION_HANDLE *)args[0],
                                      *(unsigned char * *)args[1],
                                      *(long unsigned int *)args[2]);
}
    
static void
binding_C_DigestKey (ffi_cif *cif,
                     CK_RV *ret,
                     void* args[],
                     CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_DigestKey (funcs,
                                   *(CK_SESSION_HANDLE *)args[0],
                                   *(CK_OBJECT_HANDLE *)args[1]);
}
    
static void
binding_C_DigestFinal (ffi_cif *cif,
                       CK_RV *ret,
                       void* args[],
                       CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_DigestFinal (funcs,
                                     *(CK_SESSION_HANDLE *)args[0],
                                     *(unsigned char * *)args[1],
                                     *(long unsigned int * *)args[2]);
}
    
static void
binding_C_SignInit (ffi_cif *cif,
                    CK_RV *ret,
                    void* args[],
                    CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_SignInit (funcs,
                                  *(CK_SESSION_HANDLE *)args[0],
                                  *(CK_MECHANISM_PTR *)args[1],
                                  *(CK_OBJECT_HANDLE *)args[2]);
}
    
static void
binding_C_Sign (ffi_cif *cif,
                CK_RV *ret,
                void* args[],
                CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_Sign (funcs,
                              *(CK_SESSION_HANDLE *)args[0],
                              *(unsigned char * *)args[1],
                              *(long unsigned int *)args[2],
                              *(unsigned char * *)args[3],
                              *(long unsigned int * *)args[4]);
}
    
static void
binding_C_SignUpdate (ffi_cif *cif,
                      CK_RV *ret,
                      void* args[],
                      CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_SignUpdate (funcs,
                                    *(CK_SESSION_HANDLE *)args[0],
                                    *(unsigned char * *)args[1],
                                    *(long unsigned int *)args[2]);
}
    
static void
binding_C_SignFinal (ffi_cif *cif,
                     CK_RV *ret,
                     void* args[],
                     CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_SignFinal (funcs,
                                   *(CK_SESSION_HANDLE *)args[0],
                                   *(unsigned char * *)args[1],
                                   *(long unsigned int * *)args[2]);
}
    
static void
binding_C_SignRecoverInit (ffi_cif *cif,
                           CK_RV *ret,
                           void* args[],
                           CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_SignRecoverInit (funcs,
                                         *(CK_SESSION_HANDLE *)args[0],
                                         *(CK_MECHANISM_PTR *)args[1],
                                         *(CK_OBJECT_HANDLE *)args[2]);
}
    
static void
binding_C_SignRecover (ffi_cif *cif,
                       CK_RV *ret,
                       void* args[],
                       CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_SignRecover (funcs,
                                     *(CK_SESSION_HANDLE *)args[0],
                                     *(unsigned char * *)args[1],
                                     *(long unsigned int *)args[2],
                                     *(unsigned char * *)args[3],
                                     *(long unsigned int * *)args[4]);
}
    
static void
binding_C_VerifyInit (ffi_cif *cif,
                      CK_RV *ret,
                      void* args[],
                      CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_VerifyInit (funcs,
                                    *(CK_SESSION_HANDLE *)args[0],
                                    *(CK_MECHANISM_PTR *)args[1],
                                    *(CK_OBJECT_HANDLE *)args[2]);
}
    
static void
binding_C_Verify (ffi_cif *cif,
                  CK_RV *ret,
                  void* args[],
                  CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_Verify (funcs,
                                *(CK_SESSION_HANDLE *)args[0],
                                *(unsigned char * *)args[1],
                                *(long unsigned int *)args[2],
                                *(unsigned char * *)args[3],
                                *(long unsigned int *)args[4]);
}
    
static void
binding_C_VerifyUpdate (ffi_cif *cif,
                        CK_RV *ret,
                        void* args[],
                        CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_VerifyUpdate (funcs,
                                      *(CK_SESSION_HANDLE *)args[0],
                                      *(unsigned char * *)args[1],
                                      *(long unsigned int *)args[2]);
}
    
static void
binding_C_VerifyFinal (ffi_cif *cif,
                       CK_RV *ret,
                       void* args[],
                       CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_VerifyFinal (funcs,
                                     *(CK_SESSION_HANDLE *)args[0],
                                     *(unsigned char * *)args[1],
                                     *(long unsigned int *)args[2]);
}
    
static void
binding_C_VerifyRecoverInit (ffi_cif *cif,
                             CK_RV *ret,
                             void* args[],
                             CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_VerifyRecoverInit (funcs,
                                           *(CK_SESSION_HANDLE *)args[0],
                                           *(CK_MECHANISM_PTR *)args[1],
                                           *(CK_OBJECT_HANDLE *)args[2]);
}
    
static void
binding_C_VerifyRecover (ffi_cif *cif,
                         CK_RV *ret,
                         void* args[],
                         CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_VerifyRecover (funcs,
                                       *(CK_SESSION_HANDLE *)args[0],
                                       *(unsigned char * *)args[1],
                                       *(long unsigned int *)args[2],
                                       *(unsigned char * *)args[3],
                                       *(long unsigned int * *)args[4]);
}
    
static void
binding_C_DigestEncryptUpdate (ffi_cif *cif,
                               CK_RV *ret,
                               void* args[],
                               CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_DigestEncryptUpdate (funcs,
                                             *(CK_SESSION_HANDLE *)args[0],
                                             *(unsigned char * *)args[1],
                                             *(long unsigned int *)args[2],
                                             *(unsigned char * *)args[3],
                                             *(long unsigned int * *)args[4]);
}
    
static void
binding_C_DecryptDigestUpdate (ffi_cif *cif,
                               CK_RV *ret,
                               void* args[],
                               CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_DecryptDigestUpdate (funcs,
                                             *(CK_SESSION_HANDLE *)args[0],
                                             *(unsigned char * *)args[1],
                                             *(long unsigned int *)args[2],
                                             *(unsigned char * *)args[3],
                                             *(long unsigned int * *)args[4]);
}
    
static void
binding_C_SignEncryptUpdate (ffi_cif *cif,
                             CK_RV *ret,
                             void* args[],
                             CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_SignEncryptUpdate (funcs,
                                           *(CK_SESSION_HANDLE *)args[0],
                                           *(unsigned char * *)args[1],
                                           *(long unsigned int *)args[2],
                                           *(unsigned char * *)args[3],
                                           *(long unsigned int * *)args[4]);
}
    
static void
binding_C_DecryptVerifyUpdate (ffi_cif *cif,
                               CK_RV *ret,
                               void* args[],
                               CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_DecryptVerifyUpdate (funcs,
                                             *(CK_SESSION_HANDLE *)args[0],
                                             *(unsigned char * *)args[1],
                                             *(long unsigned int *)args[2],
                                             *(unsigned char * *)args[3],
                                             *(long unsigned int * *)args[4]);
}
    
static void
binding_C_GenerateKey (ffi_cif *cif,
                       CK_RV *ret,
                       void* args[],
                       CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_GenerateKey (funcs,
                                     *(CK_SESSION_HANDLE *)args[0],
                                     *(CK_MECHANISM_PTR *)args[1],
                                     *(CK_ATTRIBUTE_PTR *)args[2],
                                     *(long unsigned int *)args[3],
                                     *(CK_OBJECT_HANDLE_PTR *)args[4]);
}
    
static void
binding_C_GenerateKeyPair (ffi_cif *cif,
                           CK_RV *ret,
                           void* args[],
                           CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_GenerateKeyPair (funcs,
                                         *(CK_SESSION_HANDLE *)args[0],
                                         *(CK_MECHANISM_PTR *)args[1],
                                         *(CK_ATTRIBUTE_PTR *)args[2],
                                         *(long unsigned int *)args[3],
                                         *(CK_ATTRIBUTE_PTR *)args[4],
                                         *(long unsigned int *)args[5],
                                         *(CK_OBJECT_HANDLE_PTR *)args[6],
                                         *(CK_OBJECT_HANDLE_PTR *)args[7]);
}
    
static void
binding_C_WrapKey (ffi_cif *cif,
                   CK_RV *ret,
                   void* args[],
                   CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_WrapKey (funcs,
                                 *(CK_SESSION_HANDLE *)args[0],
                                 *(CK_MECHANISM_PTR *)args[1],
                                 *(CK_OBJECT_HANDLE *)args[2],
                                 *(CK_OBJECT_HANDLE *)args[3],
                                 *(unsigned char * *)args[4],
                                 *(long unsigned int * *)args[5]);
}
    
static void
binding_C_UnwrapKey (ffi_cif *cif,
                     CK_RV *ret,
                     void* args[],
                     CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_UnwrapKey (funcs,
                                   *(CK_SESSION_HANDLE *)args[0],
                                   *(CK_MECHANISM_PTR *)args[1],
                                   *(CK_OBJECT_HANDLE *)args[2],
                                   *(unsigned char * *)args[3],
                                   *(long unsigned int *)args[4],
                                   *(CK_ATTRIBUTE_PTR *)args[5],
                                   *(long unsigned int *)args[6],
                                   *(CK_OBJECT_HANDLE_PTR *)args[7]);
}
    
static void
binding_C_DeriveKey (ffi_cif *cif,
                     CK_RV *ret,
                     void* args[],
                     CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_DeriveKey (funcs,
                                   *(CK_SESSION_HANDLE *)args[0],
                                   *(CK_MECHANISM_PTR *)args[1],
                                   *(CK_OBJECT_HANDLE *)args[2],
                                   *(CK_ATTRIBUTE_PTR *)args[3],
                                   *(long unsigned int *)args[4],
                                   *(CK_OBJECT_HANDLE_PTR *)args[5]);
}
    
static void
binding_C_SeedRandom (ffi_cif *cif,
                      CK_RV *ret,
                      void* args[],
                      CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_SeedRandom (funcs,
                                    *(CK_SESSION_HANDLE *)args[0],
                                    *(unsigned char * *)args[1],
                                    *(long unsigned int *)args[2]);
}
    
static void
binding_C_GenerateRandom (ffi_cif *cif,
                          CK_RV *ret,
                          void* args[],
                          CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_GenerateRandom (funcs,
                                        *(CK_SESSION_HANDLE *)args[0],
                                        *(unsigned char * *)args[1],
                                        *(long unsigned int *)args[2]);
}
    
static void
binding_C_WaitForSlotEvent (ffi_cif *cif,
                            CK_RV *ret,
                            void* args[],
                            CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_WaitForSlotEvent (funcs,
                                          *(CK_FLAGS *)args[0],
                                          *(CK_SLOT_ID_PTR *)args[1],
                                          *(CK_VOID_PTR *)args[2]);
}
    
static void
binding_C_LoginUser (ffi_cif *cif,
                     CK_RV *ret,
                     void* args[],
                     CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_LoginUser (funcs,
                                   *(CK_SESSION_HANDLE *)args[0],
                                   *(CK_USER_TYPE *)args[1],
                                   *(unsigned char * *)args[2],
                                   *(long unsigned int *)args[3],
                                   *(unsigned char * *)args[4],
                                   *(long unsigned int *)args[5]);
}
    
static void
binding_C_SessionCancel (ffi_cif *cif,
                         CK_RV *ret,
                         void* args[],
                         CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_SessionCancel (funcs,
                                       *(CK_SESSION_HANDLE *)args[0],
                                       *(CK_FLAGS *)args[1]);
}
    
static void
binding_C_MessageEncryptInit (ffi_cif *cif,
                              CK_RV *ret,
                              void* args[],
                              CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_MessageEncryptInit (funcs,
                                            *(CK_SESSION_HANDLE *)args[0],
                                            *(CK_MECHANISM_PTR *)args[1],
                                            *(CK_OBJECT_HANDLE *)args[2]);
}
    
static void
binding_C_EncryptMessage (ffi_cif *cif,
                          CK_RV *ret,
                          void* args[],
                          CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_EncryptMessage (funcs,
                                        *(CK_SESSION_HANDLE *)args[0],
                                        *(CK_VOID_PTR *)args[1],
                                        *(long unsigned int *)args[2],
                                        *(unsigned char * *)args[3],
                                        *(long unsigned int *)args[4],
                                        *(unsigned char * *)args[5],
                                        *(long unsigned int *)args[6],
                                        *(unsigned char * *)args[7],
                                        *(long unsigned int * *)args[8]);
}
    
static void
binding_C_EncryptMessageBegin (ffi_cif *cif,
                               CK_RV *ret,
                               void* args[],
                               CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_EncryptMessageBegin (funcs,
                                             *(CK_SESSION_HANDLE *)args[0],
                                             *(CK_VOID_PTR *)args[1],
                                             *(long unsigned int *)args[2],
                                             *(unsigned char * *)args[3],
                                             *(long unsigned int *)args[4]);
}
    
static void
binding_C_EncryptMessageNext (ffi_cif *cif,
                              CK_RV *ret,
                              void* args[],
                              CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_EncryptMessageNext (funcs,
                                            *(CK_SESSION_HANDLE *)args[0],
                                            *(CK_VOID_PTR *)args[1],
                                            *(long unsigned int *)args[2],
                                            *(unsigned char * *)args[3],
                                            *(long unsigned int *)args[4],
                                            *(unsigned char * *)args[5],
                                            *(long unsigned int * *)args[6],
                                            *(CK_FLAGS *)args[7]);
}
    
static void
binding_C_MessageEncryptFinal (ffi_cif *cif,
                               CK_RV *ret,
                               void* args[],
                               CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_MessageEncryptFinal (funcs,
                                             *(CK_SESSION_HANDLE *)args[0]);
}
    
static void
binding_C_MessageDecryptInit (ffi_cif *cif,
                              CK_RV *ret,
                              void* args[],
                              CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_MessageDecryptInit (funcs,
                                            *(CK_SESSION_HANDLE *)args[0],
                                            *(CK_MECHANISM_PTR *)args[1],
                                            *(CK_OBJECT_HANDLE *)args[2]);
}
    
static void
binding_C_DecryptMessage (ffi_cif *cif,
                          CK_RV *ret,
                          void* args[],
                          CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_DecryptMessage (funcs,
                                        *(CK_SESSION_HANDLE *)args[0],
                                        *(CK_VOID_PTR *)args[1],
                                        *(long unsigned int *)args[2],
                                        *(unsigned char * *)args[3],
                                        *(long unsigned int *)args[4],
                                        *(unsigned char * *)args[5],
                                        *(long unsigned int *)args[6],
                                        *(unsigned char * *)args[7],
                                        *(long unsigned int * *)args[8]);
}
    
static void
binding_C_DecryptMessageBegin (ffi_cif *cif,
                               CK_RV *ret,
                               void* args[],
                               CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_DecryptMessageBegin (funcs,
                                             *(CK_SESSION_HANDLE *)args[0],
                                             *(CK_VOID_PTR *)args[1],
                                             *(long unsigned int *)args[2],
                                             *(unsigned char * *)args[3],
                                             *(long unsigned int *)args[4]);
}
    
static void
binding_C_DecryptMessageNext (ffi_cif *cif,
                              CK_RV *ret,
                              void* args[],
                              CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_DecryptMessageNext (funcs,
                                            *(CK_SESSION_HANDLE *)args[0],
                                            *(CK_VOID_PTR *)args[1],
                                            *(long unsigned int *)args[2],
                                            *(unsigned char * *)args[3],
                                            *(long unsigned int *)args[4],
                                            *(unsigned char * *)args[5],
                                            *(long unsigned int * *)args[6],
                                            *(CK_FLAGS *)args[7]);
}
    
static void
binding_C_MessageDecryptFinal (ffi_cif *cif,
                               CK_RV *ret,
                               void* args[],
                               CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_MessageDecryptFinal (funcs,
                                             *(CK_SESSION_HANDLE *)args[0]);
}
    
static void
binding_C_MessageSignInit (ffi_cif *cif,
                           CK_RV *ret,
                           void* args[],
                           CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_MessageSignInit (funcs,
                                         *(CK_SESSION_HANDLE *)args[0],
                                         *(CK_MECHANISM_PTR *)args[1],
                                         *(CK_OBJECT_HANDLE *)args[2]);
}
    
static void
binding_C_SignMessage (ffi_cif *cif,
                       CK_RV *ret,
                       void* args[],
                       CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_SignMessage (funcs,
                                     *(CK_SESSION_HANDLE *)args[0],
                                     *(CK_VOID_PTR *)args[1],
                                     *(long unsigned int *)args[2],
                                     *(unsigned char * *)args[3],
                                     *(long unsigned int *)args[4],
                                     *(unsigned char * *)args[5],
                                     *(long unsigned int * *)args[6]);
}
    
static void
binding_C_SignMessageBegin (ffi_cif *cif,
                            CK_RV *ret,
                            void* args[],
                            CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_SignMessageBegin (funcs,
                                          *(CK_SESSION_HANDLE *)args[0],
                                          *(CK_VOID_PTR *)args[1],
                                          *(long unsigned int *)args[2]);
}
    
static void
binding_C_SignMessageNext (ffi_cif *cif,
                           CK_RV *ret,
                           void* args[],
                           CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_SignMessageNext (funcs,
                                         *(CK_SESSION_HANDLE *)args[0],
                                         *(CK_VOID_PTR *)args[1],
                                         *(long unsigned int *)args[2],
                                         *(unsigned char * *)args[3],
                                         *(long unsigned int *)args[4],
                                         *(unsigned char * *)args[5],
                                         *(long unsigned int * *)args[6]);
}
    
static void
binding_C_MessageSignFinal (ffi_cif *cif,
                            CK_RV *ret,
                            void* args[],
                            CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_MessageSignFinal (funcs,
                                          *(CK_SESSION_HANDLE *)args[0]);
}
    
static void
binding_C_MessageVerifyInit (ffi_cif *cif,
                             CK_RV *ret,
                             void* args[],
                             CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_MessageVerifyInit (funcs,
                                           *(CK_SESSION_HANDLE *)args[0],
                                           *(CK_MECHANISM_PTR *)args[1],
                                           *(CK_OBJECT_HANDLE *)args[2]);
}
    
static void
binding_C_VerifyMessage (ffi_cif *cif,
                         CK_RV *ret,
                         void* args[],
                         CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_VerifyMessage (funcs,
                                       *(CK_SESSION_HANDLE *)args[0],
                                       *(CK_VOID_PTR *)args[1],
                                       *(long unsigned int *)args[2],
                                       *(unsigned char * *)args[3],
                                       *(long unsigned int *)args[4],
                                       *(unsigned char * *)args[5],
                                       *(long unsigned int *)args[6]);
}
    
static void
binding_C_VerifyMessageBegin (ffi_cif *cif,
                              CK_RV *ret,
                              void* args[],
                              CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_VerifyMessageBegin (funcs,
                                            *(CK_SESSION_HANDLE *)args[0],
                                            *(CK_VOID_PTR *)args[1],
                                            *(long unsigned int *)args[2]);
}
    
static void
binding_C_VerifyMessageNext (ffi_cif *cif,
                             CK_RV *ret,
                             void* args[],
                             CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_VerifyMessageNext (funcs,
                                           *(CK_SESSION_HANDLE *)args[0],
                                           *(CK_VOID_PTR *)args[1],
                                           *(long unsigned int *)args[2],
                                           *(unsigned char * *)args[3],
                                           *(long unsigned int *)args[4],
                                           *(unsigned char * *)args[5],
                                           *(long unsigned int *)args[6]);
}
    
static void
binding_C_MessageVerifyFinal (ffi_cif *cif,
                              CK_RV *ret,
                              void* args[],
                              CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_MessageVerifyFinal (funcs,
                                            *(CK_SESSION_HANDLE *)args[0]);
}
    
static void
binding_C_EncapsulateKey (ffi_cif *cif,
                          CK_RV *ret,
                          void* args[],
                          CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_EncapsulateKey (funcs,
                                        *(CK_SESSION_HANDLE *)args[0],
                                        *(CK_MECHANISM_PTR *)args[1],
                                        *(CK_OBJECT_HANDLE *)args[2],
                                        *(CK_ATTRIBUTE_PTR *)args[3],
                                        *(long unsigned int *)args[4],
                                        *(unsigned char * *)args[5],
                                        *(long unsigned int * *)args[6],
                                        *(CK_OBJECT_HANDLE_PTR *)args[7]);
}
    
static void
binding_C_DecapsulateKey (ffi_cif *cif,
                          CK_RV *ret,
                          void* args[],
                          CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_DecapsulateKey (funcs,
                                        *(CK_SESSION_HANDLE *)args[0],
                                        *(CK_MECHANISM_PTR *)args[1],
                                        *(CK_OBJECT_HANDLE *)args[2],
                                        *(CK_ATTRIBUTE_PTR *)args[3],
                                        *(long unsigned int *)args[4],
                                        *(unsigned char * *)args[5],
                                        *(long unsigned int * *)args[6],
                                        *(CK_OBJECT_HANDLE_PTR *)args[7]);
}
    
static void
binding_C_VerifySignatureInit (ffi_cif *cif,
                               CK_RV *ret,
                               void* args[],
                               CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_VerifySignatureInit (funcs,
                                             *(CK_SESSION_HANDLE *)args[0],
                                             *(CK_MECHANISM_PTR *)args[1],
                                             *(CK_OBJECT_HANDLE *)args[2],
                                             *(unsigned char * *)args[3],
                                             *(long unsigned int *)args[4]);
}
    
static void
binding_C_VerifySignature (ffi_cif *cif,
                           CK_RV *ret,
                           void* args[],
                           CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_VerifySignature (funcs,
                                         *(CK_SESSION_HANDLE *)args[0],
                                         *(unsigned char * *)args[1],
                                         *(long unsigned int *)args[2]);
}
    
static void
binding_C_VerifySignatureUpdate (ffi_cif *cif,
                                 CK_RV *ret,
                                 void* args[],
                                 CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_VerifySignatureUpdate (funcs,
                                               *(CK_SESSION_HANDLE *)args[0],
                                               *(unsigned char * *)args[1],
                                               *(long unsigned int *)args[2]);
}
    
static void
binding_C_VerifySignatureFinal (ffi_cif *cif,
                                CK_RV *ret,
                                void* args[],
                                CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_VerifySignatureFinal (funcs,
                                              *(CK_SESSION_HANDLE *)args[0]);
}
    
static void
binding_C_GetSessionValidationFlags (ffi_cif *cif,
                                     CK_RV *ret,
                                     void* args[],
                                     CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_GetSessionValidationFlags (funcs,
                                                   *(CK_SESSION_HANDLE *)args[0],
                                                   *(CK_SESSION_VALIDATION_FLAGS_TYPE *)args[1],
                                                   *(CK_FLAGS * *)args[2]);
}
    
static void
binding_C_AsyncComplete (ffi_cif *cif,
                         CK_RV *ret,
                         void* args[],
                         CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_AsyncComplete (funcs,
                                       *(CK_SESSION_HANDLE *)args[0],
                                       *(unsigned char * *)args[1],
                                       *(CK_ASYNC_DATA_PTR *)args[2]);
}
    
static void
binding_C_AsyncGetID (ffi_cif *cif,
                      CK_RV *ret,
                      void* args[],
                      CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_AsyncGetID (funcs,
                                    *(CK_SESSION_HANDLE *)args[0],
                                    *(unsigned char * *)args[1],
                                    *(long unsigned int * *)args[2]);
}
    
static void
binding_C_AsyncJoin (ffi_cif *cif,
                     CK_RV *ret,
                     void* args[],
                     CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_AsyncJoin (funcs,
                                   *(CK_SESSION_HANDLE *)args[0],
                                   *(unsigned char * *)args[1],
                                   *(long unsigned int *)args[2],
                                   *(unsigned char * *)args[3],
                                   *(long unsigned int *)args[4]);
}
    
static void
binding_C_WrapKeyAuthenticated (ffi_cif *cif,
                                CK_RV *ret,
                                void* args[],
                                CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_WrapKeyAuthenticated (funcs,
                                              *(CK_SESSION_HANDLE *)args[0],
                                              *(CK_MECHANISM_PTR *)args[1],
                                              *(CK_OBJECT_HANDLE *)args[2],
                                              *(CK_OBJECT_HANDLE *)args[3],
                                              *(unsigned char * *)args[4],
                                              *(long unsigned int *)args[5],
                                              *(unsigned char * *)args[6],
                                              *(long unsigned int * *)args[7]);
}
    
static void
binding_C_UnwrapKeyAuthenticated (ffi_cif *cif,
                                  CK_RV *ret,
                                  void* args[],
                                  CK_X_FUNCTION_LIST *funcs)
{
        *ret = funcs->C_UnwrapKeyAuthenticated (funcs,
                                                *(CK_SESSION_HANDLE *)args[0],
                                                *(CK_MECHANISM_PTR *)args[1],
                                                *(CK_OBJECT_HANDLE *)args[2],
                                                *(unsigned char * *)args[3],
                                                *(long unsigned int *)args[4],
                                                *(CK_ATTRIBUTE_PTR *)args[5],
                                                *(long unsigned int *)args[6],
                                                *(unsigned char * *)args[7],
                                                *(long unsigned int *)args[8],
                                                *(CK_OBJECT_HANDLE_PTR *)args[9]);
}
    

static const BindingInfo binding_info[] = {
        { binding_C_Initialize, { &ffi_type_pointer, NULL } },
        { binding_C_Finalize, { &ffi_type_pointer, NULL } },
        { binding_C_GetInfo, { &ffi_type_pointer, NULL } },
        { binding_C_GetSlotList, { &ffi_type_uchar, &ffi_type_pointer, &ffi_type_pointer, NULL } },
        { binding_C_GetSlotInfo, { &ffi_type_ulong, &ffi_type_pointer, NULL } },
        { binding_C_GetTokenInfo, { &ffi_type_ulong, &ffi_type_pointer, NULL } },
        { binding_C_GetMechanismList, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_pointer, NULL } },
        { binding_C_GetMechanismInfo, { &ffi_type_ulong, &ffi_type_ulong, &ffi_type_pointer, NULL } },
        { binding_C_InitToken, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, &ffi_type_pointer, NULL } },
        { binding_C_InitPIN, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, NULL } },
        { binding_C_SetPIN, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, NULL } },
        { binding_C_OpenSession, { &ffi_type_ulong, &ffi_type_ulong, &ffi_type_pointer, &ffi_type_pointer, &ffi_type_pointer, NULL } },
        { binding_C_CloseSession, { &ffi_type_ulong, NULL } },
        { binding_C_CloseAllSessions, { &ffi_type_ulong, NULL } },
        { binding_C_GetSessionInfo, { &ffi_type_ulong, &ffi_type_pointer, NULL } },
        { binding_C_GetOperationState, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_pointer, NULL } },
        { binding_C_SetOperationState, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, &ffi_type_ulong, &ffi_type_ulong, NULL } },
        { binding_C_Login, { &ffi_type_ulong, &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, NULL } },
        { binding_C_Logout, { &ffi_type_ulong, NULL } },
        { binding_C_CreateObject, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, &ffi_type_pointer, NULL } },
        { binding_C_CopyObject, { &ffi_type_ulong, &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, &ffi_type_pointer, NULL } },
        { binding_C_DestroyObject, { &ffi_type_ulong, &ffi_type_ulong, NULL } },
        { binding_C_GetObjectSize, { &ffi_type_ulong, &ffi_type_ulong, &ffi_type_pointer, NULL } },
        { binding_C_GetAttributeValue, { &ffi_type_ulong, &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, NULL } },
        { binding_C_SetAttributeValue, { &ffi_type_ulong, &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, NULL } },
        { binding_C_FindObjectsInit, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, NULL } },
        { binding_C_FindObjects, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, &ffi_type_pointer, NULL } },
        { binding_C_FindObjectsFinal, { &ffi_type_ulong, NULL } },
        { binding_C_EncryptInit, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, NULL } },
        { binding_C_Encrypt, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, &ffi_type_pointer, &ffi_type_pointer, NULL } },
        { binding_C_EncryptUpdate, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, &ffi_type_pointer, &ffi_type_pointer, NULL } },
        { binding_C_EncryptFinal, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_pointer, NULL } },
        { binding_C_DecryptInit, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, NULL } },
        { binding_C_Decrypt, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, &ffi_type_pointer, &ffi_type_pointer, NULL } },
        { binding_C_DecryptUpdate, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, &ffi_type_pointer, &ffi_type_pointer, NULL } },
        { binding_C_DecryptFinal, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_pointer, NULL } },
        { binding_C_DigestInit, { &ffi_type_ulong, &ffi_type_pointer, NULL } },
        { binding_C_Digest, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, &ffi_type_pointer, &ffi_type_pointer, NULL } },
        { binding_C_DigestUpdate, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, NULL } },
        { binding_C_DigestKey, { &ffi_type_ulong, &ffi_type_ulong, NULL } },
        { binding_C_DigestFinal, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_pointer, NULL } },
        { binding_C_SignInit, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, NULL } },
        { binding_C_Sign, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, &ffi_type_pointer, &ffi_type_pointer, NULL } },
        { binding_C_SignUpdate, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, NULL } },
        { binding_C_SignFinal, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_pointer, NULL } },
        { binding_C_SignRecoverInit, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, NULL } },
        { binding_C_SignRecover, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, &ffi_type_pointer, &ffi_type_pointer, NULL } },
        { binding_C_VerifyInit, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, NULL } },
        { binding_C_Verify, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, NULL } },
        { binding_C_VerifyUpdate, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, NULL } },
        { binding_C_VerifyFinal, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, NULL } },
        { binding_C_VerifyRecoverInit, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, NULL } },
        { binding_C_VerifyRecover, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, &ffi_type_pointer, &ffi_type_pointer, NULL } },
        { binding_C_DigestEncryptUpdate, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, &ffi_type_pointer, &ffi_type_pointer, NULL } },
        { binding_C_DecryptDigestUpdate, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, &ffi_type_pointer, &ffi_type_pointer, NULL } },
        { binding_C_SignEncryptUpdate, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, &ffi_type_pointer, &ffi_type_pointer, NULL } },
        { binding_C_DecryptVerifyUpdate, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, &ffi_type_pointer, &ffi_type_pointer, NULL } },
        { binding_C_GenerateKey, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_pointer, &ffi_type_ulong, &ffi_type_pointer, NULL } },
        { binding_C_GenerateKeyPair, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_pointer, &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, &ffi_type_pointer, &ffi_type_pointer, NULL } },
        { binding_C_WrapKey, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, &ffi_type_ulong, &ffi_type_pointer, &ffi_type_pointer, NULL } },
        { binding_C_UnwrapKey, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, &ffi_type_pointer, NULL } },
        { binding_C_DeriveKey, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, &ffi_type_pointer, NULL } },
        { binding_C_SeedRandom, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, NULL } },
        { binding_C_GenerateRandom, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, NULL } },
        { binding_C_WaitForSlotEvent, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_pointer, NULL } },
        { binding_C_LoginUser, { &ffi_type_ulong, &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, NULL } },
        { binding_C_SessionCancel, { &ffi_type_ulong, &ffi_type_ulong, NULL } },
        { binding_C_MessageEncryptInit, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, NULL } },
        { binding_C_EncryptMessage, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, &ffi_type_pointer, &ffi_type_pointer, NULL } },
        { binding_C_EncryptMessageBegin, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, NULL } },
        { binding_C_EncryptMessageNext, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, &ffi_type_pointer, &ffi_type_pointer, &ffi_type_ulong, NULL } },
        { binding_C_MessageEncryptFinal, { &ffi_type_ulong, NULL } },
        { binding_C_MessageDecryptInit, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, NULL } },
        { binding_C_DecryptMessage, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, &ffi_type_pointer, &ffi_type_pointer, NULL } },
        { binding_C_DecryptMessageBegin, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, NULL } },
        { binding_C_DecryptMessageNext, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, &ffi_type_pointer, &ffi_type_pointer, &ffi_type_ulong, NULL } },
        { binding_C_MessageDecryptFinal, { &ffi_type_ulong, NULL } },
        { binding_C_MessageSignInit, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, NULL } },
        { binding_C_SignMessage, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, &ffi_type_pointer, &ffi_type_pointer, NULL } },
        { binding_C_SignMessageBegin, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, NULL } },
        { binding_C_SignMessageNext, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, &ffi_type_pointer, &ffi_type_pointer, NULL } },
        { binding_C_MessageSignFinal, { &ffi_type_ulong, NULL } },
        { binding_C_MessageVerifyInit, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, NULL } },
        { binding_C_VerifyMessage, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, NULL } },
        { binding_C_VerifyMessageBegin, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, NULL } },
        { binding_C_VerifyMessageNext, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, NULL } },
        { binding_C_MessageVerifyFinal, { &ffi_type_ulong, NULL } },
        { binding_C_EncapsulateKey, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, &ffi_type_pointer, &ffi_type_pointer, &ffi_type_pointer, NULL } },
        { binding_C_DecapsulateKey, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, &ffi_type_pointer, &ffi_type_pointer, &ffi_type_pointer, NULL } },
        { binding_C_VerifySignatureInit, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, NULL } },
        { binding_C_VerifySignature, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, NULL } },
        { binding_C_VerifySignatureUpdate, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, NULL } },
        { binding_C_VerifySignatureFinal, { &ffi_type_ulong, NULL } },
        { binding_C_GetSessionValidationFlags, { &ffi_type_ulong, &ffi_type_ulong, &ffi_type_pointer, NULL } },
        { binding_C_AsyncComplete, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_pointer, NULL } },
        { binding_C_AsyncGetID, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_pointer, NULL } },
        { binding_C_AsyncJoin, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, NULL } },
        { binding_C_WrapKeyAuthenticated, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, &ffi_type_pointer, &ffi_type_pointer, NULL } },
        { binding_C_UnwrapKeyAuthenticated, { &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, &ffi_type_pointer, &ffi_type_ulong, &ffi_type_pointer, NULL } },
        { 0, }
};
