
/* DO NOT EDIT! GENERATED AUTOMATICALLY! */

static CK_RV
base_C_Initialize (CK_X_FUNCTION_LIST *self,
                   CK_VOID_PTR init_args)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_Initialize (init_args);
}
    
static CK_RV
base_C_Finalize (CK_X_FUNCTION_LIST *self,
                 CK_VOID_PTR pReserved)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_Finalize (pReserved);
}
    
static CK_RV
base_C_GetInfo (CK_X_FUNCTION_LIST *self,
                CK_INFO_PTR pInfo)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_GetInfo (pInfo);
}
    
static CK_RV
base_C_GetSlotList (CK_X_FUNCTION_LIST *self,
                    unsigned char token_present,
                    CK_SLOT_ID_PTR slot_list,
                    long unsigned int * ulCount)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_GetSlotList (token_present,
                                     slot_list,
                                     ulCount);
}
    
static CK_RV
base_C_GetSlotInfo (CK_X_FUNCTION_LIST *self,
                    CK_SLOT_ID slotID,
                    CK_SLOT_INFO_PTR pInfo)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_GetSlotInfo (slotID,
                                     pInfo);
}
    
static CK_RV
base_C_GetTokenInfo (CK_X_FUNCTION_LIST *self,
                     CK_SLOT_ID slotID,
                     CK_TOKEN_INFO_PTR pInfo)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_GetTokenInfo (slotID,
                                      pInfo);
}
    
static CK_RV
base_C_GetMechanismList (CK_X_FUNCTION_LIST *self,
                         CK_SLOT_ID slotID,
                         CK_MECHANISM_TYPE_PTR mechanism_list,
                         long unsigned int * ulCount)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_GetMechanismList (slotID,
                                          mechanism_list,
                                          ulCount);
}
    
static CK_RV
base_C_GetMechanismInfo (CK_X_FUNCTION_LIST *self,
                         CK_SLOT_ID slotID,
                         CK_MECHANISM_TYPE type,
                         CK_MECHANISM_INFO_PTR pInfo)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_GetMechanismInfo (slotID,
                                          type,
                                          pInfo);
}
    
static CK_RV
base_C_InitToken (CK_X_FUNCTION_LIST *self,
                  CK_SLOT_ID slotID,
                  unsigned char * pin,
                  long unsigned int pin_len,
                  unsigned char * label)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_InitToken (slotID,
                                   pin,
                                   pin_len,
                                   label);
}
    
static CK_RV
base_C_InitPIN (CK_X_FUNCTION_LIST *self,
                CK_SESSION_HANDLE session,
                unsigned char * pin,
                long unsigned int pin_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_InitPIN (session,
                                 pin,
                                 pin_len);
}
    
static CK_RV
base_C_SetPIN (CK_X_FUNCTION_LIST *self,
               CK_SESSION_HANDLE session,
               unsigned char * old_pin,
               long unsigned int old_len,
               unsigned char * new_pin,
               long unsigned int new_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_SetPIN (session,
                                old_pin,
                                old_len,
                                new_pin,
                                new_len);
}
    
static CK_RV
base_C_OpenSession (CK_X_FUNCTION_LIST *self,
                    CK_SLOT_ID slotID,
                    CK_FLAGS flags,
                    CK_VOID_PTR application,
                    CK_NOTIFY notify,
                    CK_SESSION_HANDLE_PTR session)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_OpenSession (slotID,
                                     flags,
                                     application,
                                     notify,
                                     session);
}
    
static CK_RV
base_C_CloseSession (CK_X_FUNCTION_LIST *self,
                     CK_SESSION_HANDLE session)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_CloseSession (session);
}
    
static CK_RV
base_C_CloseAllSessions (CK_X_FUNCTION_LIST *self,
                         CK_SLOT_ID slotID)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_CloseAllSessions (slotID);
}
    
static CK_RV
base_C_GetSessionInfo (CK_X_FUNCTION_LIST *self,
                       CK_SESSION_HANDLE session,
                       CK_SESSION_INFO_PTR pInfo)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_GetSessionInfo (session,
                                        pInfo);
}
    
static CK_RV
base_C_GetOperationState (CK_X_FUNCTION_LIST *self,
                          CK_SESSION_HANDLE session,
                          unsigned char * operation_state,
                          long unsigned int * operation_state_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_GetOperationState (session,
                                           operation_state,
                                           operation_state_len);
}
    
static CK_RV
base_C_SetOperationState (CK_X_FUNCTION_LIST *self,
                          CK_SESSION_HANDLE session,
                          unsigned char * operation_state,
                          long unsigned int operation_state_len,
                          CK_OBJECT_HANDLE encryption_key,
                          CK_OBJECT_HANDLE authentication_key)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_SetOperationState (session,
                                           operation_state,
                                           operation_state_len,
                                           encryption_key,
                                           authentication_key);
}
    
static CK_RV
base_C_Login (CK_X_FUNCTION_LIST *self,
              CK_SESSION_HANDLE session,
              CK_USER_TYPE user_type,
              unsigned char * pin,
              long unsigned int pin_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_Login (session,
                               user_type,
                               pin,
                               pin_len);
}
    
static CK_RV
base_C_Logout (CK_X_FUNCTION_LIST *self,
               CK_SESSION_HANDLE session)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_Logout (session);
}
    
static CK_RV
base_C_CreateObject (CK_X_FUNCTION_LIST *self,
                     CK_SESSION_HANDLE session,
                     CK_ATTRIBUTE_PTR pTemplate,
                     long unsigned int ulCount,
                     CK_OBJECT_HANDLE_PTR object)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_CreateObject (session,
                                      pTemplate,
                                      ulCount,
                                      object);
}
    
static CK_RV
base_C_CopyObject (CK_X_FUNCTION_LIST *self,
                   CK_SESSION_HANDLE session,
                   CK_OBJECT_HANDLE object,
                   CK_ATTRIBUTE_PTR pTemplate,
                   long unsigned int ulCount,
                   CK_OBJECT_HANDLE_PTR new_object)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_CopyObject (session,
                                    object,
                                    pTemplate,
                                    ulCount,
                                    new_object);
}
    
static CK_RV
base_C_DestroyObject (CK_X_FUNCTION_LIST *self,
                      CK_SESSION_HANDLE session,
                      CK_OBJECT_HANDLE object)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_DestroyObject (session,
                                       object);
}
    
static CK_RV
base_C_GetObjectSize (CK_X_FUNCTION_LIST *self,
                      CK_SESSION_HANDLE session,
                      CK_OBJECT_HANDLE object,
                      long unsigned int * size)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_GetObjectSize (session,
                                       object,
                                       size);
}
    
static CK_RV
base_C_GetAttributeValue (CK_X_FUNCTION_LIST *self,
                          CK_SESSION_HANDLE session,
                          CK_OBJECT_HANDLE object,
                          CK_ATTRIBUTE_PTR pTemplate,
                          long unsigned int ulCount)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_GetAttributeValue (session,
                                           object,
                                           pTemplate,
                                           ulCount);
}
    
static CK_RV
base_C_SetAttributeValue (CK_X_FUNCTION_LIST *self,
                          CK_SESSION_HANDLE session,
                          CK_OBJECT_HANDLE object,
                          CK_ATTRIBUTE_PTR pTemplate,
                          long unsigned int ulCount)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_SetAttributeValue (session,
                                           object,
                                           pTemplate,
                                           ulCount);
}
    
static CK_RV
base_C_FindObjectsInit (CK_X_FUNCTION_LIST *self,
                        CK_SESSION_HANDLE session,
                        CK_ATTRIBUTE_PTR pTemplate,
                        long unsigned int ulCount)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_FindObjectsInit (session,
                                         pTemplate,
                                         ulCount);
}
    
static CK_RV
base_C_FindObjects (CK_X_FUNCTION_LIST *self,
                    CK_SESSION_HANDLE session,
                    CK_OBJECT_HANDLE_PTR object,
                    long unsigned int max_object_count,
                    long unsigned int * object_count)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_FindObjects (session,
                                     object,
                                     max_object_count,
                                     object_count);
}
    
static CK_RV
base_C_FindObjectsFinal (CK_X_FUNCTION_LIST *self,
                         CK_SESSION_HANDLE session)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_FindObjectsFinal (session);
}
    
static CK_RV
base_C_EncryptInit (CK_X_FUNCTION_LIST *self,
                    CK_SESSION_HANDLE session,
                    CK_MECHANISM_PTR mechanism,
                    CK_OBJECT_HANDLE hKey)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_EncryptInit (session,
                                     mechanism,
                                     hKey);
}
    
static CK_RV
base_C_Encrypt (CK_X_FUNCTION_LIST *self,
                CK_SESSION_HANDLE session,
                unsigned char * data,
                long unsigned int ulDataLen,
                unsigned char * encrypted_data,
                long unsigned int * encrypted_data_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_Encrypt (session,
                                 data,
                                 ulDataLen,
                                 encrypted_data,
                                 encrypted_data_len);
}
    
static CK_RV
base_C_EncryptUpdate (CK_X_FUNCTION_LIST *self,
                      CK_SESSION_HANDLE session,
                      unsigned char * part,
                      long unsigned int part_len,
                      unsigned char * encrypted_part,
                      long unsigned int * encrypted_part_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_EncryptUpdate (session,
                                       part,
                                       part_len,
                                       encrypted_part,
                                       encrypted_part_len);
}
    
static CK_RV
base_C_EncryptFinal (CK_X_FUNCTION_LIST *self,
                     CK_SESSION_HANDLE session,
                     unsigned char * last_encrypted_part,
                     long unsigned int * last_encrypted_part_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_EncryptFinal (session,
                                      last_encrypted_part,
                                      last_encrypted_part_len);
}
    
static CK_RV
base_C_DecryptInit (CK_X_FUNCTION_LIST *self,
                    CK_SESSION_HANDLE session,
                    CK_MECHANISM_PTR mechanism,
                    CK_OBJECT_HANDLE hKey)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_DecryptInit (session,
                                     mechanism,
                                     hKey);
}
    
static CK_RV
base_C_Decrypt (CK_X_FUNCTION_LIST *self,
                CK_SESSION_HANDLE session,
                unsigned char * encrypted_data,
                long unsigned int encrypted_data_len,
                unsigned char * data,
                long unsigned int * ulDataLen)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_Decrypt (session,
                                 encrypted_data,
                                 encrypted_data_len,
                                 data,
                                 ulDataLen);
}
    
static CK_RV
base_C_DecryptUpdate (CK_X_FUNCTION_LIST *self,
                      CK_SESSION_HANDLE session,
                      unsigned char * encrypted_part,
                      long unsigned int encrypted_part_len,
                      unsigned char * part,
                      long unsigned int * part_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_DecryptUpdate (session,
                                       encrypted_part,
                                       encrypted_part_len,
                                       part,
                                       part_len);
}
    
static CK_RV
base_C_DecryptFinal (CK_X_FUNCTION_LIST *self,
                     CK_SESSION_HANDLE session,
                     unsigned char * last_part,
                     long unsigned int * last_part_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_DecryptFinal (session,
                                      last_part,
                                      last_part_len);
}
    
static CK_RV
base_C_DigestInit (CK_X_FUNCTION_LIST *self,
                   CK_SESSION_HANDLE session,
                   CK_MECHANISM_PTR mechanism)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_DigestInit (session,
                                    mechanism);
}
    
static CK_RV
base_C_Digest (CK_X_FUNCTION_LIST *self,
               CK_SESSION_HANDLE session,
               unsigned char * data,
               long unsigned int ulDataLen,
               unsigned char * digest,
               long unsigned int * digest_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_Digest (session,
                                data,
                                ulDataLen,
                                digest,
                                digest_len);
}
    
static CK_RV
base_C_DigestUpdate (CK_X_FUNCTION_LIST *self,
                     CK_SESSION_HANDLE session,
                     unsigned char * part,
                     long unsigned int part_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_DigestUpdate (session,
                                      part,
                                      part_len);
}
    
static CK_RV
base_C_DigestKey (CK_X_FUNCTION_LIST *self,
                  CK_SESSION_HANDLE session,
                  CK_OBJECT_HANDLE hKey)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_DigestKey (session,
                                   hKey);
}
    
static CK_RV
base_C_DigestFinal (CK_X_FUNCTION_LIST *self,
                    CK_SESSION_HANDLE session,
                    unsigned char * digest,
                    long unsigned int * digest_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_DigestFinal (session,
                                     digest,
                                     digest_len);
}
    
static CK_RV
base_C_SignInit (CK_X_FUNCTION_LIST *self,
                 CK_SESSION_HANDLE session,
                 CK_MECHANISM_PTR mechanism,
                 CK_OBJECT_HANDLE hKey)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_SignInit (session,
                                  mechanism,
                                  hKey);
}
    
static CK_RV
base_C_Sign (CK_X_FUNCTION_LIST *self,
             CK_SESSION_HANDLE session,
             unsigned char * data,
             long unsigned int ulDataLen,
             unsigned char * signature,
             long unsigned int * signature_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_Sign (session,
                              data,
                              ulDataLen,
                              signature,
                              signature_len);
}
    
static CK_RV
base_C_SignUpdate (CK_X_FUNCTION_LIST *self,
                   CK_SESSION_HANDLE session,
                   unsigned char * part,
                   long unsigned int part_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_SignUpdate (session,
                                    part,
                                    part_len);
}
    
static CK_RV
base_C_SignFinal (CK_X_FUNCTION_LIST *self,
                  CK_SESSION_HANDLE session,
                  unsigned char * signature,
                  long unsigned int * signature_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_SignFinal (session,
                                   signature,
                                   signature_len);
}
    
static CK_RV
base_C_SignRecoverInit (CK_X_FUNCTION_LIST *self,
                        CK_SESSION_HANDLE session,
                        CK_MECHANISM_PTR mechanism,
                        CK_OBJECT_HANDLE hKey)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_SignRecoverInit (session,
                                         mechanism,
                                         hKey);
}
    
static CK_RV
base_C_SignRecover (CK_X_FUNCTION_LIST *self,
                    CK_SESSION_HANDLE session,
                    unsigned char * data,
                    long unsigned int ulDataLen,
                    unsigned char * signature,
                    long unsigned int * signature_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_SignRecover (session,
                                     data,
                                     ulDataLen,
                                     signature,
                                     signature_len);
}
    
static CK_RV
base_C_VerifyInit (CK_X_FUNCTION_LIST *self,
                   CK_SESSION_HANDLE session,
                   CK_MECHANISM_PTR mechanism,
                   CK_OBJECT_HANDLE hKey)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_VerifyInit (session,
                                    mechanism,
                                    hKey);
}
    
static CK_RV
base_C_Verify (CK_X_FUNCTION_LIST *self,
               CK_SESSION_HANDLE session,
               unsigned char * data,
               long unsigned int ulDataLen,
               unsigned char * signature,
               long unsigned int signature_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_Verify (session,
                                data,
                                ulDataLen,
                                signature,
                                signature_len);
}
    
static CK_RV
base_C_VerifyUpdate (CK_X_FUNCTION_LIST *self,
                     CK_SESSION_HANDLE session,
                     unsigned char * part,
                     long unsigned int part_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_VerifyUpdate (session,
                                      part,
                                      part_len);
}
    
static CK_RV
base_C_VerifyFinal (CK_X_FUNCTION_LIST *self,
                    CK_SESSION_HANDLE session,
                    unsigned char * signature,
                    long unsigned int signature_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_VerifyFinal (session,
                                     signature,
                                     signature_len);
}
    
static CK_RV
base_C_VerifyRecoverInit (CK_X_FUNCTION_LIST *self,
                          CK_SESSION_HANDLE session,
                          CK_MECHANISM_PTR mechanism,
                          CK_OBJECT_HANDLE hKey)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_VerifyRecoverInit (session,
                                           mechanism,
                                           hKey);
}
    
static CK_RV
base_C_VerifyRecover (CK_X_FUNCTION_LIST *self,
                      CK_SESSION_HANDLE session,
                      unsigned char * signature,
                      long unsigned int signature_len,
                      unsigned char * data,
                      long unsigned int * ulDataLen)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_VerifyRecover (session,
                                       signature,
                                       signature_len,
                                       data,
                                       ulDataLen);
}
    
static CK_RV
base_C_DigestEncryptUpdate (CK_X_FUNCTION_LIST *self,
                            CK_SESSION_HANDLE session,
                            unsigned char * part,
                            long unsigned int part_len,
                            unsigned char * encrypted_part,
                            long unsigned int * encrypted_part_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_DigestEncryptUpdate (session,
                                             part,
                                             part_len,
                                             encrypted_part,
                                             encrypted_part_len);
}
    
static CK_RV
base_C_DecryptDigestUpdate (CK_X_FUNCTION_LIST *self,
                            CK_SESSION_HANDLE session,
                            unsigned char * encrypted_part,
                            long unsigned int encrypted_part_len,
                            unsigned char * part,
                            long unsigned int * part_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_DecryptDigestUpdate (session,
                                             encrypted_part,
                                             encrypted_part_len,
                                             part,
                                             part_len);
}
    
static CK_RV
base_C_SignEncryptUpdate (CK_X_FUNCTION_LIST *self,
                          CK_SESSION_HANDLE session,
                          unsigned char * part,
                          long unsigned int part_len,
                          unsigned char * encrypted_part,
                          long unsigned int * encrypted_part_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_SignEncryptUpdate (session,
                                           part,
                                           part_len,
                                           encrypted_part,
                                           encrypted_part_len);
}
    
static CK_RV
base_C_DecryptVerifyUpdate (CK_X_FUNCTION_LIST *self,
                            CK_SESSION_HANDLE session,
                            unsigned char * encrypted_part,
                            long unsigned int encrypted_part_len,
                            unsigned char * part,
                            long unsigned int * part_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_DecryptVerifyUpdate (session,
                                             encrypted_part,
                                             encrypted_part_len,
                                             part,
                                             part_len);
}
    
static CK_RV
base_C_GenerateKey (CK_X_FUNCTION_LIST *self,
                    CK_SESSION_HANDLE session,
                    CK_MECHANISM_PTR mechanism,
                    CK_ATTRIBUTE_PTR pTemplate,
                    long unsigned int ulCount,
                    CK_OBJECT_HANDLE_PTR hKey)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_GenerateKey (session,
                                     mechanism,
                                     pTemplate,
                                     ulCount,
                                     hKey);
}
    
static CK_RV
base_C_GenerateKeyPair (CK_X_FUNCTION_LIST *self,
                        CK_SESSION_HANDLE session,
                        CK_MECHANISM_PTR mechanism,
                        CK_ATTRIBUTE_PTR public_key_template,
                        long unsigned int public_key_attribute_count,
                        CK_ATTRIBUTE_PTR private_key_template,
                        long unsigned int private_key_attribute_count,
                        CK_OBJECT_HANDLE_PTR publicKey,
                        CK_OBJECT_HANDLE_PTR private_key)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_GenerateKeyPair (session,
                                         mechanism,
                                         public_key_template,
                                         public_key_attribute_count,
                                         private_key_template,
                                         private_key_attribute_count,
                                         publicKey,
                                         private_key);
}
    
static CK_RV
base_C_WrapKey (CK_X_FUNCTION_LIST *self,
                CK_SESSION_HANDLE session,
                CK_MECHANISM_PTR mechanism,
                CK_OBJECT_HANDLE wrapping_key,
                CK_OBJECT_HANDLE hKey,
                unsigned char * wrapped_key,
                long unsigned int * wrapped_key_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_WrapKey (session,
                                 mechanism,
                                 wrapping_key,
                                 hKey,
                                 wrapped_key,
                                 wrapped_key_len);
}
    
static CK_RV
base_C_UnwrapKey (CK_X_FUNCTION_LIST *self,
                  CK_SESSION_HANDLE session,
                  CK_MECHANISM_PTR mechanism,
                  CK_OBJECT_HANDLE unwrapping_key,
                  unsigned char * wrapped_key,
                  long unsigned int wrapped_key_len,
                  CK_ATTRIBUTE_PTR pTemplate,
                  long unsigned int ulAttributeCount,
                  CK_OBJECT_HANDLE_PTR hKey)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_UnwrapKey (session,
                                   mechanism,
                                   unwrapping_key,
                                   wrapped_key,
                                   wrapped_key_len,
                                   pTemplate,
                                   ulAttributeCount,
                                   hKey);
}
    
static CK_RV
base_C_DeriveKey (CK_X_FUNCTION_LIST *self,
                  CK_SESSION_HANDLE session,
                  CK_MECHANISM_PTR mechanism,
                  CK_OBJECT_HANDLE base_key,
                  CK_ATTRIBUTE_PTR pTemplate,
                  long unsigned int ulAttributeCount,
                  CK_OBJECT_HANDLE_PTR hKey)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_DeriveKey (session,
                                   mechanism,
                                   base_key,
                                   pTemplate,
                                   ulAttributeCount,
                                   hKey);
}
    
static CK_RV
base_C_SeedRandom (CK_X_FUNCTION_LIST *self,
                   CK_SESSION_HANDLE session,
                   unsigned char * seed,
                   long unsigned int ulSeedLen)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_SeedRandom (session,
                                    seed,
                                    ulSeedLen);
}
    
static CK_RV
base_C_GenerateRandom (CK_X_FUNCTION_LIST *self,
                       CK_SESSION_HANDLE session,
                       unsigned char * random_data,
                       long unsigned int ulRandomLen)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_GenerateRandom (session,
                                        random_data,
                                        ulRandomLen);
}
    
static CK_RV
base_C_WaitForSlotEvent (CK_X_FUNCTION_LIST *self,
                         CK_FLAGS flags,
                         CK_SLOT_ID_PTR slot,
                         CK_VOID_PTR pReserved)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_WaitForSlotEvent (flags,
                                          slot,
                                          pReserved);
}
    
static CK_RV
base_C_LoginUser (CK_X_FUNCTION_LIST *self,
                  CK_SESSION_HANDLE session,
                  CK_USER_TYPE user_type,
                  unsigned char * pin,
                  long unsigned int pin_len,
                  unsigned char * username,
                  long unsigned int username_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST_3_2 *funcs = virt->lower_module;
        if (funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return funcs->C_LoginUser (session,
                                   user_type,
                                   pin,
                                   pin_len,
                                   username,
                                   username_len);
}
    
static CK_RV
base_C_SessionCancel (CK_X_FUNCTION_LIST *self,
                      CK_SESSION_HANDLE session,
                      CK_FLAGS flags)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST_3_2 *funcs = virt->lower_module;
        if (funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return funcs->C_SessionCancel (session,
                                       flags);
}
    
static CK_RV
base_C_MessageEncryptInit (CK_X_FUNCTION_LIST *self,
                           CK_SESSION_HANDLE session,
                           CK_MECHANISM_PTR mechanism,
                           CK_OBJECT_HANDLE hKey)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST_3_2 *funcs = virt->lower_module;
        if (funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return funcs->C_MessageEncryptInit (session,
                                            mechanism,
                                            hKey);
}
    
static CK_RV
base_C_EncryptMessage (CK_X_FUNCTION_LIST *self,
                       CK_SESSION_HANDLE session,
                       CK_VOID_PTR pParameter,
                       long unsigned int ulParameterLen,
                       unsigned char * associated_data,
                       long unsigned int associated_data_len,
                       unsigned char * plaintext,
                       long unsigned int plaintext_len,
                       unsigned char * ciphertext,
                       long unsigned int * ciphertext_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST_3_2 *funcs = virt->lower_module;
        if (funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return funcs->C_EncryptMessage (session,
                                        pParameter,
                                        ulParameterLen,
                                        associated_data,
                                        associated_data_len,
                                        plaintext,
                                        plaintext_len,
                                        ciphertext,
                                        ciphertext_len);
}
    
static CK_RV
base_C_EncryptMessageBegin (CK_X_FUNCTION_LIST *self,
                            CK_SESSION_HANDLE session,
                            CK_VOID_PTR pParameter,
                            long unsigned int ulParameterLen,
                            unsigned char * associated_data,
                            long unsigned int associated_data_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST_3_2 *funcs = virt->lower_module;
        if (funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return funcs->C_EncryptMessageBegin (session,
                                             pParameter,
                                             ulParameterLen,
                                             associated_data,
                                             associated_data_len);
}
    
static CK_RV
base_C_EncryptMessageNext (CK_X_FUNCTION_LIST *self,
                           CK_SESSION_HANDLE session,
                           CK_VOID_PTR pParameter,
                           long unsigned int ulParameterLen,
                           unsigned char * plaintext_part,
                           long unsigned int plaintext_part_len,
                           unsigned char * ciphertext_part,
                           long unsigned int * ciphertext_part_len,
                           CK_FLAGS flags)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST_3_2 *funcs = virt->lower_module;
        if (funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return funcs->C_EncryptMessageNext (session,
                                            pParameter,
                                            ulParameterLen,
                                            plaintext_part,
                                            plaintext_part_len,
                                            ciphertext_part,
                                            ciphertext_part_len,
                                            flags);
}
    
static CK_RV
base_C_MessageEncryptFinal (CK_X_FUNCTION_LIST *self,
                            CK_SESSION_HANDLE session)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST_3_2 *funcs = virt->lower_module;
        if (funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return funcs->C_MessageEncryptFinal (session);
}
    
static CK_RV
base_C_MessageDecryptInit (CK_X_FUNCTION_LIST *self,
                           CK_SESSION_HANDLE session,
                           CK_MECHANISM_PTR mechanism,
                           CK_OBJECT_HANDLE hKey)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST_3_2 *funcs = virt->lower_module;
        if (funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return funcs->C_MessageDecryptInit (session,
                                            mechanism,
                                            hKey);
}
    
static CK_RV
base_C_DecryptMessage (CK_X_FUNCTION_LIST *self,
                       CK_SESSION_HANDLE session,
                       CK_VOID_PTR pParameter,
                       long unsigned int ulParameterLen,
                       unsigned char * associated_data,
                       long unsigned int associated_data_len,
                       unsigned char * ciphertext,
                       long unsigned int ciphertext_len,
                       unsigned char * plaintext,
                       long unsigned int * plaintext_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST_3_2 *funcs = virt->lower_module;
        if (funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return funcs->C_DecryptMessage (session,
                                        pParameter,
                                        ulParameterLen,
                                        associated_data,
                                        associated_data_len,
                                        ciphertext,
                                        ciphertext_len,
                                        plaintext,
                                        plaintext_len);
}
    
static CK_RV
base_C_DecryptMessageBegin (CK_X_FUNCTION_LIST *self,
                            CK_SESSION_HANDLE session,
                            CK_VOID_PTR pParameter,
                            long unsigned int ulParameterLen,
                            unsigned char * associated_data,
                            long unsigned int associated_data_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST_3_2 *funcs = virt->lower_module;
        if (funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return funcs->C_DecryptMessageBegin (session,
                                             pParameter,
                                             ulParameterLen,
                                             associated_data,
                                             associated_data_len);
}
    
static CK_RV
base_C_DecryptMessageNext (CK_X_FUNCTION_LIST *self,
                           CK_SESSION_HANDLE session,
                           CK_VOID_PTR pParameter,
                           long unsigned int ulParameterLen,
                           unsigned char * ciphertext_part,
                           long unsigned int ciphertext_part_len,
                           unsigned char * plaintext_part,
                           long unsigned int * plaintext_part_len,
                           CK_FLAGS flags)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST_3_2 *funcs = virt->lower_module;
        if (funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return funcs->C_DecryptMessageNext (session,
                                            pParameter,
                                            ulParameterLen,
                                            ciphertext_part,
                                            ciphertext_part_len,
                                            plaintext_part,
                                            plaintext_part_len,
                                            flags);
}
    
static CK_RV
base_C_MessageDecryptFinal (CK_X_FUNCTION_LIST *self,
                            CK_SESSION_HANDLE session)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST_3_2 *funcs = virt->lower_module;
        if (funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return funcs->C_MessageDecryptFinal (session);
}
    
static CK_RV
base_C_MessageSignInit (CK_X_FUNCTION_LIST *self,
                        CK_SESSION_HANDLE session,
                        CK_MECHANISM_PTR mechanism,
                        CK_OBJECT_HANDLE hKey)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST_3_2 *funcs = virt->lower_module;
        if (funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return funcs->C_MessageSignInit (session,
                                         mechanism,
                                         hKey);
}
    
static CK_RV
base_C_SignMessage (CK_X_FUNCTION_LIST *self,
                    CK_SESSION_HANDLE session,
                    CK_VOID_PTR pParameter,
                    long unsigned int ulParameterLen,
                    unsigned char * data,
                    long unsigned int ulDataLen,
                    unsigned char * signature,
                    long unsigned int * signature_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST_3_2 *funcs = virt->lower_module;
        if (funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return funcs->C_SignMessage (session,
                                     pParameter,
                                     ulParameterLen,
                                     data,
                                     ulDataLen,
                                     signature,
                                     signature_len);
}
    
static CK_RV
base_C_SignMessageBegin (CK_X_FUNCTION_LIST *self,
                         CK_SESSION_HANDLE session,
                         CK_VOID_PTR pParameter,
                         long unsigned int ulParameterLen)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST_3_2 *funcs = virt->lower_module;
        if (funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return funcs->C_SignMessageBegin (session,
                                          pParameter,
                                          ulParameterLen);
}
    
static CK_RV
base_C_SignMessageNext (CK_X_FUNCTION_LIST *self,
                        CK_SESSION_HANDLE session,
                        CK_VOID_PTR pParameter,
                        long unsigned int ulParameterLen,
                        unsigned char * data,
                        long unsigned int ulDataLen,
                        unsigned char * signature,
                        long unsigned int * signature_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST_3_2 *funcs = virt->lower_module;
        if (funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return funcs->C_SignMessageNext (session,
                                         pParameter,
                                         ulParameterLen,
                                         data,
                                         ulDataLen,
                                         signature,
                                         signature_len);
}
    
static CK_RV
base_C_MessageSignFinal (CK_X_FUNCTION_LIST *self,
                         CK_SESSION_HANDLE session)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST_3_2 *funcs = virt->lower_module;
        if (funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return funcs->C_MessageSignFinal (session);
}
    
static CK_RV
base_C_MessageVerifyInit (CK_X_FUNCTION_LIST *self,
                          CK_SESSION_HANDLE session,
                          CK_MECHANISM_PTR mechanism,
                          CK_OBJECT_HANDLE hKey)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST_3_2 *funcs = virt->lower_module;
        if (funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return funcs->C_MessageVerifyInit (session,
                                           mechanism,
                                           hKey);
}
    
static CK_RV
base_C_VerifyMessage (CK_X_FUNCTION_LIST *self,
                      CK_SESSION_HANDLE session,
                      CK_VOID_PTR pParameter,
                      long unsigned int ulParameterLen,
                      unsigned char * data,
                      long unsigned int ulDataLen,
                      unsigned char * signature,
                      long unsigned int signature_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST_3_2 *funcs = virt->lower_module;
        if (funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return funcs->C_VerifyMessage (session,
                                       pParameter,
                                       ulParameterLen,
                                       data,
                                       ulDataLen,
                                       signature,
                                       signature_len);
}
    
static CK_RV
base_C_VerifyMessageBegin (CK_X_FUNCTION_LIST *self,
                           CK_SESSION_HANDLE session,
                           CK_VOID_PTR pParameter,
                           long unsigned int ulParameterLen)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST_3_2 *funcs = virt->lower_module;
        if (funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return funcs->C_VerifyMessageBegin (session,
                                            pParameter,
                                            ulParameterLen);
}
    
static CK_RV
base_C_VerifyMessageNext (CK_X_FUNCTION_LIST *self,
                          CK_SESSION_HANDLE session,
                          CK_VOID_PTR pParameter,
                          long unsigned int ulParameterLen,
                          unsigned char * data,
                          long unsigned int ulDataLen,
                          unsigned char * signature,
                          long unsigned int signature_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST_3_2 *funcs = virt->lower_module;
        if (funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return funcs->C_VerifyMessageNext (session,
                                           pParameter,
                                           ulParameterLen,
                                           data,
                                           ulDataLen,
                                           signature,
                                           signature_len);
}
    
static CK_RV
base_C_MessageVerifyFinal (CK_X_FUNCTION_LIST *self,
                           CK_SESSION_HANDLE session)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST_3_2 *funcs = virt->lower_module;
        if (funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return funcs->C_MessageVerifyFinal (session);
}
    
static CK_RV
base_C_EncapsulateKey (CK_X_FUNCTION_LIST *self,
                       CK_SESSION_HANDLE session,
                       CK_MECHANISM_PTR mechanism,
                       CK_OBJECT_HANDLE publicKey,
                       CK_ATTRIBUTE_PTR pTemplate,
                       long unsigned int ulAttributeCount,
                       unsigned char * ciphertext,
                       long unsigned int * ciphertext_len,
                       CK_OBJECT_HANDLE_PTR phKey)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST_3_2 *funcs = virt->lower_module;
        if (funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return funcs->C_EncapsulateKey (session,
                                        mechanism,
                                        publicKey,
                                        pTemplate,
                                        ulAttributeCount,
                                        ciphertext,
                                        ciphertext_len,
                                        phKey);
}
    
static CK_RV
base_C_DecapsulateKey (CK_X_FUNCTION_LIST *self,
                       CK_SESSION_HANDLE session,
                       CK_MECHANISM_PTR mechanism,
                       CK_OBJECT_HANDLE private_key,
                       CK_ATTRIBUTE_PTR pTemplate,
                       long unsigned int ulAttributeCount,
                       unsigned char * ciphertext,
                       long unsigned int * ciphertext_len,
                       CK_OBJECT_HANDLE_PTR phKey)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST_3_2 *funcs = virt->lower_module;
        if (funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return funcs->C_DecapsulateKey (session,
                                        mechanism,
                                        private_key,
                                        pTemplate,
                                        ulAttributeCount,
                                        ciphertext,
                                        ciphertext_len,
                                        phKey);
}
    
static CK_RV
base_C_VerifySignatureInit (CK_X_FUNCTION_LIST *self,
                            CK_SESSION_HANDLE session,
                            CK_MECHANISM_PTR mechanism,
                            CK_OBJECT_HANDLE hKey,
                            unsigned char * signature,
                            long unsigned int signature_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST_3_2 *funcs = virt->lower_module;
        if (funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return funcs->C_VerifySignatureInit (session,
                                             mechanism,
                                             hKey,
                                             signature,
                                             signature_len);
}
    
static CK_RV
base_C_VerifySignature (CK_X_FUNCTION_LIST *self,
                        CK_SESSION_HANDLE session,
                        unsigned char * data,
                        long unsigned int ulDataLen)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST_3_2 *funcs = virt->lower_module;
        if (funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return funcs->C_VerifySignature (session,
                                         data,
                                         ulDataLen);
}
    
static CK_RV
base_C_VerifySignatureUpdate (CK_X_FUNCTION_LIST *self,
                              CK_SESSION_HANDLE session,
                              unsigned char * part,
                              long unsigned int part_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST_3_2 *funcs = virt->lower_module;
        if (funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return funcs->C_VerifySignatureUpdate (session,
                                               part,
                                               part_len);
}
    
static CK_RV
base_C_VerifySignatureFinal (CK_X_FUNCTION_LIST *self,
                             CK_SESSION_HANDLE session)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST_3_2 *funcs = virt->lower_module;
        if (funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return funcs->C_VerifySignatureFinal (session);
}
    
static CK_RV
base_C_GetSessionValidationFlags (CK_X_FUNCTION_LIST *self,
                                  CK_SESSION_HANDLE session,
                                  CK_SESSION_VALIDATION_FLAGS_TYPE type,
                                  CK_FLAGS * flags_ptr)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST_3_2 *funcs = virt->lower_module;
        if (funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return funcs->C_GetSessionValidationFlags (session,
                                                   type,
                                                   flags_ptr);
}
    
static CK_RV
base_C_AsyncComplete (CK_X_FUNCTION_LIST *self,
                      CK_SESSION_HANDLE session,
                      unsigned char * function_name,
                      CK_ASYNC_DATA_PTR result)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST_3_2 *funcs = virt->lower_module;
        if (funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return funcs->C_AsyncComplete (session,
                                       function_name,
                                       result);
}
    
static CK_RV
base_C_AsyncGetID (CK_X_FUNCTION_LIST *self,
                   CK_SESSION_HANDLE session,
                   unsigned char * function_name,
                   long unsigned int * id_ptr)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST_3_2 *funcs = virt->lower_module;
        if (funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return funcs->C_AsyncGetID (session,
                                    function_name,
                                    id_ptr);
}
    
static CK_RV
base_C_AsyncJoin (CK_X_FUNCTION_LIST *self,
                  CK_SESSION_HANDLE session,
                  unsigned char * function_name,
                  long unsigned int id,
                  unsigned char * data,
                  long unsigned int ulDataLen)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST_3_2 *funcs = virt->lower_module;
        if (funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return funcs->C_AsyncJoin (session,
                                   function_name,
                                   id,
                                   data,
                                   ulDataLen);
}
    
static CK_RV
base_C_WrapKeyAuthenticated (CK_X_FUNCTION_LIST *self,
                             CK_SESSION_HANDLE session,
                             CK_MECHANISM_PTR mechanism,
                             CK_OBJECT_HANDLE wrapping_key,
                             CK_OBJECT_HANDLE hKey,
                             unsigned char * associated_data,
                             long unsigned int associated_data_len,
                             unsigned char * wrapped_key,
                             long unsigned int * wrapped_key_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST_3_2 *funcs = virt->lower_module;
        if (funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return funcs->C_WrapKeyAuthenticated (session,
                                              mechanism,
                                              wrapping_key,
                                              hKey,
                                              associated_data,
                                              associated_data_len,
                                              wrapped_key,
                                              wrapped_key_len);
}
    
static CK_RV
base_C_UnwrapKeyAuthenticated (CK_X_FUNCTION_LIST *self,
                               CK_SESSION_HANDLE session,
                               CK_MECHANISM_PTR mechanism,
                               CK_OBJECT_HANDLE unwrapping_key,
                               unsigned char * wrapped_key,
                               long unsigned int wrapped_key_len,
                               CK_ATTRIBUTE_PTR pTemplate,
                               long unsigned int ulAttributeCount,
                               unsigned char * associated_data,
                               long unsigned int associated_data_len,
                               CK_OBJECT_HANDLE_PTR phKey)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_FUNCTION_LIST_3_2 *funcs = virt->lower_module;
        if (funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return funcs->C_UnwrapKeyAuthenticated (session,
                                                mechanism,
                                                unwrapping_key,
                                                wrapped_key,
                                                wrapped_key_len,
                                                pTemplate,
                                                ulAttributeCount,
                                                associated_data,
                                                associated_data_len,
                                                phKey);
}
    

CK_X_FUNCTION_LIST p11_virtual_base = {
        { CRYPTOKI_VERSION_MAJOR, CRYPTOKI_VERSION_MINOR },  /* version */
        base_C_Initialize,
        base_C_Finalize,
        base_C_GetInfo,
        base_C_GetSlotList,
        base_C_GetSlotInfo,
        base_C_GetTokenInfo,
        base_C_GetMechanismList,
        base_C_GetMechanismInfo,
        base_C_InitToken,
        base_C_InitPIN,
        base_C_SetPIN,
        base_C_OpenSession,
        base_C_CloseSession,
        base_C_CloseAllSessions,
        base_C_GetSessionInfo,
        base_C_GetOperationState,
        base_C_SetOperationState,
        base_C_Login,
        base_C_Logout,
        base_C_CreateObject,
        base_C_CopyObject,
        base_C_DestroyObject,
        base_C_GetObjectSize,
        base_C_GetAttributeValue,
        base_C_SetAttributeValue,
        base_C_FindObjectsInit,
        base_C_FindObjects,
        base_C_FindObjectsFinal,
        base_C_EncryptInit,
        base_C_Encrypt,
        base_C_EncryptUpdate,
        base_C_EncryptFinal,
        base_C_DecryptInit,
        base_C_Decrypt,
        base_C_DecryptUpdate,
        base_C_DecryptFinal,
        base_C_DigestInit,
        base_C_Digest,
        base_C_DigestUpdate,
        base_C_DigestKey,
        base_C_DigestFinal,
        base_C_SignInit,
        base_C_Sign,
        base_C_SignUpdate,
        base_C_SignFinal,
        base_C_SignRecoverInit,
        base_C_SignRecover,
        base_C_VerifyInit,
        base_C_Verify,
        base_C_VerifyUpdate,
        base_C_VerifyFinal,
        base_C_VerifyRecoverInit,
        base_C_VerifyRecover,
        base_C_DigestEncryptUpdate,
        base_C_DecryptDigestUpdate,
        base_C_SignEncryptUpdate,
        base_C_DecryptVerifyUpdate,
        base_C_GenerateKey,
        base_C_GenerateKeyPair,
        base_C_WrapKey,
        base_C_UnwrapKey,
        base_C_DeriveKey,
        base_C_SeedRandom,
        base_C_GenerateRandom,
        base_C_WaitForSlotEvent,
        base_C_LoginUser,
        base_C_SessionCancel,
        base_C_MessageEncryptInit,
        base_C_EncryptMessage,
        base_C_EncryptMessageBegin,
        base_C_EncryptMessageNext,
        base_C_MessageEncryptFinal,
        base_C_MessageDecryptInit,
        base_C_DecryptMessage,
        base_C_DecryptMessageBegin,
        base_C_DecryptMessageNext,
        base_C_MessageDecryptFinal,
        base_C_MessageSignInit,
        base_C_SignMessage,
        base_C_SignMessageBegin,
        base_C_SignMessageNext,
        base_C_MessageSignFinal,
        base_C_MessageVerifyInit,
        base_C_VerifyMessage,
        base_C_VerifyMessageBegin,
        base_C_VerifyMessageNext,
        base_C_MessageVerifyFinal,
        base_C_EncapsulateKey,
        base_C_DecapsulateKey,
        base_C_VerifySignatureInit,
        base_C_VerifySignature,
        base_C_VerifySignatureUpdate,
        base_C_VerifySignatureFinal,
        base_C_GetSessionValidationFlags,
        base_C_AsyncComplete,
        base_C_AsyncGetID,
        base_C_AsyncJoin,
        base_C_WrapKeyAuthenticated,
        base_C_UnwrapKeyAuthenticated
};
