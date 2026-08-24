
/* DO NOT EDIT! GENERATED AUTOMATICALLY! */

static CK_RV
stack_C_Initialize (CK_X_FUNCTION_LIST *self,
                    CK_VOID_PTR init_args)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_Initialize (funcs,
                                    init_args);
}
    
static CK_RV
stack_C_Finalize (CK_X_FUNCTION_LIST *self,
                  CK_VOID_PTR pReserved)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_Finalize (funcs,
                                  pReserved);
}
    
static CK_RV
stack_C_GetInfo (CK_X_FUNCTION_LIST *self,
                 CK_INFO_PTR pInfo)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_GetInfo (funcs,
                                 pInfo);
}
    
static CK_RV
stack_C_GetSlotList (CK_X_FUNCTION_LIST *self,
                     unsigned char token_present,
                     CK_SLOT_ID_PTR slot_list,
                     long unsigned int * ulCount)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_GetSlotList (funcs,
                                     token_present,
                                     slot_list,
                                     ulCount);
}
    
static CK_RV
stack_C_GetSlotInfo (CK_X_FUNCTION_LIST *self,
                     CK_SLOT_ID slotID,
                     CK_SLOT_INFO_PTR pInfo)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_GetSlotInfo (funcs,
                                     slotID,
                                     pInfo);
}
    
static CK_RV
stack_C_GetTokenInfo (CK_X_FUNCTION_LIST *self,
                      CK_SLOT_ID slotID,
                      CK_TOKEN_INFO_PTR pInfo)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_GetTokenInfo (funcs,
                                      slotID,
                                      pInfo);
}
    
static CK_RV
stack_C_GetMechanismList (CK_X_FUNCTION_LIST *self,
                          CK_SLOT_ID slotID,
                          CK_MECHANISM_TYPE_PTR mechanism_list,
                          long unsigned int * ulCount)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_GetMechanismList (funcs,
                                          slotID,
                                          mechanism_list,
                                          ulCount);
}
    
static CK_RV
stack_C_GetMechanismInfo (CK_X_FUNCTION_LIST *self,
                          CK_SLOT_ID slotID,
                          CK_MECHANISM_TYPE type,
                          CK_MECHANISM_INFO_PTR pInfo)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_GetMechanismInfo (funcs,
                                          slotID,
                                          type,
                                          pInfo);
}
    
static CK_RV
stack_C_InitToken (CK_X_FUNCTION_LIST *self,
                   CK_SLOT_ID slotID,
                   unsigned char * pin,
                   long unsigned int pin_len,
                   unsigned char * label)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_InitToken (funcs,
                                   slotID,
                                   pin,
                                   pin_len,
                                   label);
}
    
static CK_RV
stack_C_InitPIN (CK_X_FUNCTION_LIST *self,
                 CK_SESSION_HANDLE session,
                 unsigned char * pin,
                 long unsigned int pin_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_InitPIN (funcs,
                                 session,
                                 pin,
                                 pin_len);
}
    
static CK_RV
stack_C_SetPIN (CK_X_FUNCTION_LIST *self,
                CK_SESSION_HANDLE session,
                unsigned char * old_pin,
                long unsigned int old_len,
                unsigned char * new_pin,
                long unsigned int new_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_SetPIN (funcs,
                                session,
                                old_pin,
                                old_len,
                                new_pin,
                                new_len);
}
    
static CK_RV
stack_C_OpenSession (CK_X_FUNCTION_LIST *self,
                     CK_SLOT_ID slotID,
                     CK_FLAGS flags,
                     CK_VOID_PTR application,
                     CK_NOTIFY notify,
                     CK_SESSION_HANDLE_PTR session)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_OpenSession (funcs,
                                     slotID,
                                     flags,
                                     application,
                                     notify,
                                     session);
}
    
static CK_RV
stack_C_CloseSession (CK_X_FUNCTION_LIST *self,
                      CK_SESSION_HANDLE session)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_CloseSession (funcs,
                                      session);
}
    
static CK_RV
stack_C_CloseAllSessions (CK_X_FUNCTION_LIST *self,
                          CK_SLOT_ID slotID)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_CloseAllSessions (funcs,
                                          slotID);
}
    
static CK_RV
stack_C_GetSessionInfo (CK_X_FUNCTION_LIST *self,
                        CK_SESSION_HANDLE session,
                        CK_SESSION_INFO_PTR pInfo)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_GetSessionInfo (funcs,
                                        session,
                                        pInfo);
}
    
static CK_RV
stack_C_GetOperationState (CK_X_FUNCTION_LIST *self,
                           CK_SESSION_HANDLE session,
                           unsigned char * operation_state,
                           long unsigned int * operation_state_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_GetOperationState (funcs,
                                           session,
                                           operation_state,
                                           operation_state_len);
}
    
static CK_RV
stack_C_SetOperationState (CK_X_FUNCTION_LIST *self,
                           CK_SESSION_HANDLE session,
                           unsigned char * operation_state,
                           long unsigned int operation_state_len,
                           CK_OBJECT_HANDLE encryption_key,
                           CK_OBJECT_HANDLE authentication_key)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_SetOperationState (funcs,
                                           session,
                                           operation_state,
                                           operation_state_len,
                                           encryption_key,
                                           authentication_key);
}
    
static CK_RV
stack_C_Login (CK_X_FUNCTION_LIST *self,
               CK_SESSION_HANDLE session,
               CK_USER_TYPE user_type,
               unsigned char * pin,
               long unsigned int pin_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_Login (funcs,
                               session,
                               user_type,
                               pin,
                               pin_len);
}
    
static CK_RV
stack_C_Logout (CK_X_FUNCTION_LIST *self,
                CK_SESSION_HANDLE session)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_Logout (funcs,
                                session);
}
    
static CK_RV
stack_C_CreateObject (CK_X_FUNCTION_LIST *self,
                      CK_SESSION_HANDLE session,
                      CK_ATTRIBUTE_PTR pTemplate,
                      long unsigned int ulCount,
                      CK_OBJECT_HANDLE_PTR object)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_CreateObject (funcs,
                                      session,
                                      pTemplate,
                                      ulCount,
                                      object);
}
    
static CK_RV
stack_C_CopyObject (CK_X_FUNCTION_LIST *self,
                    CK_SESSION_HANDLE session,
                    CK_OBJECT_HANDLE object,
                    CK_ATTRIBUTE_PTR pTemplate,
                    long unsigned int ulCount,
                    CK_OBJECT_HANDLE_PTR new_object)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_CopyObject (funcs,
                                    session,
                                    object,
                                    pTemplate,
                                    ulCount,
                                    new_object);
}
    
static CK_RV
stack_C_DestroyObject (CK_X_FUNCTION_LIST *self,
                       CK_SESSION_HANDLE session,
                       CK_OBJECT_HANDLE object)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_DestroyObject (funcs,
                                       session,
                                       object);
}
    
static CK_RV
stack_C_GetObjectSize (CK_X_FUNCTION_LIST *self,
                       CK_SESSION_HANDLE session,
                       CK_OBJECT_HANDLE object,
                       long unsigned int * size)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_GetObjectSize (funcs,
                                       session,
                                       object,
                                       size);
}
    
static CK_RV
stack_C_GetAttributeValue (CK_X_FUNCTION_LIST *self,
                           CK_SESSION_HANDLE session,
                           CK_OBJECT_HANDLE object,
                           CK_ATTRIBUTE_PTR pTemplate,
                           long unsigned int ulCount)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_GetAttributeValue (funcs,
                                           session,
                                           object,
                                           pTemplate,
                                           ulCount);
}
    
static CK_RV
stack_C_SetAttributeValue (CK_X_FUNCTION_LIST *self,
                           CK_SESSION_HANDLE session,
                           CK_OBJECT_HANDLE object,
                           CK_ATTRIBUTE_PTR pTemplate,
                           long unsigned int ulCount)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_SetAttributeValue (funcs,
                                           session,
                                           object,
                                           pTemplate,
                                           ulCount);
}
    
static CK_RV
stack_C_FindObjectsInit (CK_X_FUNCTION_LIST *self,
                         CK_SESSION_HANDLE session,
                         CK_ATTRIBUTE_PTR pTemplate,
                         long unsigned int ulCount)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_FindObjectsInit (funcs,
                                         session,
                                         pTemplate,
                                         ulCount);
}
    
static CK_RV
stack_C_FindObjects (CK_X_FUNCTION_LIST *self,
                     CK_SESSION_HANDLE session,
                     CK_OBJECT_HANDLE_PTR object,
                     long unsigned int max_object_count,
                     long unsigned int * object_count)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_FindObjects (funcs,
                                     session,
                                     object,
                                     max_object_count,
                                     object_count);
}
    
static CK_RV
stack_C_FindObjectsFinal (CK_X_FUNCTION_LIST *self,
                          CK_SESSION_HANDLE session)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_FindObjectsFinal (funcs,
                                          session);
}
    
static CK_RV
stack_C_EncryptInit (CK_X_FUNCTION_LIST *self,
                     CK_SESSION_HANDLE session,
                     CK_MECHANISM_PTR mechanism,
                     CK_OBJECT_HANDLE hKey)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_EncryptInit (funcs,
                                     session,
                                     mechanism,
                                     hKey);
}
    
static CK_RV
stack_C_Encrypt (CK_X_FUNCTION_LIST *self,
                 CK_SESSION_HANDLE session,
                 unsigned char * data,
                 long unsigned int ulDataLen,
                 unsigned char * encrypted_data,
                 long unsigned int * encrypted_data_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_Encrypt (funcs,
                                 session,
                                 data,
                                 ulDataLen,
                                 encrypted_data,
                                 encrypted_data_len);
}
    
static CK_RV
stack_C_EncryptUpdate (CK_X_FUNCTION_LIST *self,
                       CK_SESSION_HANDLE session,
                       unsigned char * part,
                       long unsigned int part_len,
                       unsigned char * encrypted_part,
                       long unsigned int * encrypted_part_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_EncryptUpdate (funcs,
                                       session,
                                       part,
                                       part_len,
                                       encrypted_part,
                                       encrypted_part_len);
}
    
static CK_RV
stack_C_EncryptFinal (CK_X_FUNCTION_LIST *self,
                      CK_SESSION_HANDLE session,
                      unsigned char * last_encrypted_part,
                      long unsigned int * last_encrypted_part_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_EncryptFinal (funcs,
                                      session,
                                      last_encrypted_part,
                                      last_encrypted_part_len);
}
    
static CK_RV
stack_C_DecryptInit (CK_X_FUNCTION_LIST *self,
                     CK_SESSION_HANDLE session,
                     CK_MECHANISM_PTR mechanism,
                     CK_OBJECT_HANDLE hKey)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_DecryptInit (funcs,
                                     session,
                                     mechanism,
                                     hKey);
}
    
static CK_RV
stack_C_Decrypt (CK_X_FUNCTION_LIST *self,
                 CK_SESSION_HANDLE session,
                 unsigned char * encrypted_data,
                 long unsigned int encrypted_data_len,
                 unsigned char * data,
                 long unsigned int * ulDataLen)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_Decrypt (funcs,
                                 session,
                                 encrypted_data,
                                 encrypted_data_len,
                                 data,
                                 ulDataLen);
}
    
static CK_RV
stack_C_DecryptUpdate (CK_X_FUNCTION_LIST *self,
                       CK_SESSION_HANDLE session,
                       unsigned char * encrypted_part,
                       long unsigned int encrypted_part_len,
                       unsigned char * part,
                       long unsigned int * part_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_DecryptUpdate (funcs,
                                       session,
                                       encrypted_part,
                                       encrypted_part_len,
                                       part,
                                       part_len);
}
    
static CK_RV
stack_C_DecryptFinal (CK_X_FUNCTION_LIST *self,
                      CK_SESSION_HANDLE session,
                      unsigned char * last_part,
                      long unsigned int * last_part_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_DecryptFinal (funcs,
                                      session,
                                      last_part,
                                      last_part_len);
}
    
static CK_RV
stack_C_DigestInit (CK_X_FUNCTION_LIST *self,
                    CK_SESSION_HANDLE session,
                    CK_MECHANISM_PTR mechanism)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_DigestInit (funcs,
                                    session,
                                    mechanism);
}
    
static CK_RV
stack_C_Digest (CK_X_FUNCTION_LIST *self,
                CK_SESSION_HANDLE session,
                unsigned char * data,
                long unsigned int ulDataLen,
                unsigned char * digest,
                long unsigned int * digest_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_Digest (funcs,
                                session,
                                data,
                                ulDataLen,
                                digest,
                                digest_len);
}
    
static CK_RV
stack_C_DigestUpdate (CK_X_FUNCTION_LIST *self,
                      CK_SESSION_HANDLE session,
                      unsigned char * part,
                      long unsigned int part_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_DigestUpdate (funcs,
                                      session,
                                      part,
                                      part_len);
}
    
static CK_RV
stack_C_DigestKey (CK_X_FUNCTION_LIST *self,
                   CK_SESSION_HANDLE session,
                   CK_OBJECT_HANDLE hKey)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_DigestKey (funcs,
                                   session,
                                   hKey);
}
    
static CK_RV
stack_C_DigestFinal (CK_X_FUNCTION_LIST *self,
                     CK_SESSION_HANDLE session,
                     unsigned char * digest,
                     long unsigned int * digest_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_DigestFinal (funcs,
                                     session,
                                     digest,
                                     digest_len);
}
    
static CK_RV
stack_C_SignInit (CK_X_FUNCTION_LIST *self,
                  CK_SESSION_HANDLE session,
                  CK_MECHANISM_PTR mechanism,
                  CK_OBJECT_HANDLE hKey)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_SignInit (funcs,
                                  session,
                                  mechanism,
                                  hKey);
}
    
static CK_RV
stack_C_Sign (CK_X_FUNCTION_LIST *self,
              CK_SESSION_HANDLE session,
              unsigned char * data,
              long unsigned int ulDataLen,
              unsigned char * signature,
              long unsigned int * signature_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_Sign (funcs,
                              session,
                              data,
                              ulDataLen,
                              signature,
                              signature_len);
}
    
static CK_RV
stack_C_SignUpdate (CK_X_FUNCTION_LIST *self,
                    CK_SESSION_HANDLE session,
                    unsigned char * part,
                    long unsigned int part_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_SignUpdate (funcs,
                                    session,
                                    part,
                                    part_len);
}
    
static CK_RV
stack_C_SignFinal (CK_X_FUNCTION_LIST *self,
                   CK_SESSION_HANDLE session,
                   unsigned char * signature,
                   long unsigned int * signature_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_SignFinal (funcs,
                                   session,
                                   signature,
                                   signature_len);
}
    
static CK_RV
stack_C_SignRecoverInit (CK_X_FUNCTION_LIST *self,
                         CK_SESSION_HANDLE session,
                         CK_MECHANISM_PTR mechanism,
                         CK_OBJECT_HANDLE hKey)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_SignRecoverInit (funcs,
                                         session,
                                         mechanism,
                                         hKey);
}
    
static CK_RV
stack_C_SignRecover (CK_X_FUNCTION_LIST *self,
                     CK_SESSION_HANDLE session,
                     unsigned char * data,
                     long unsigned int ulDataLen,
                     unsigned char * signature,
                     long unsigned int * signature_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_SignRecover (funcs,
                                     session,
                                     data,
                                     ulDataLen,
                                     signature,
                                     signature_len);
}
    
static CK_RV
stack_C_VerifyInit (CK_X_FUNCTION_LIST *self,
                    CK_SESSION_HANDLE session,
                    CK_MECHANISM_PTR mechanism,
                    CK_OBJECT_HANDLE hKey)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_VerifyInit (funcs,
                                    session,
                                    mechanism,
                                    hKey);
}
    
static CK_RV
stack_C_Verify (CK_X_FUNCTION_LIST *self,
                CK_SESSION_HANDLE session,
                unsigned char * data,
                long unsigned int ulDataLen,
                unsigned char * signature,
                long unsigned int signature_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_Verify (funcs,
                                session,
                                data,
                                ulDataLen,
                                signature,
                                signature_len);
}
    
static CK_RV
stack_C_VerifyUpdate (CK_X_FUNCTION_LIST *self,
                      CK_SESSION_HANDLE session,
                      unsigned char * part,
                      long unsigned int part_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_VerifyUpdate (funcs,
                                      session,
                                      part,
                                      part_len);
}
    
static CK_RV
stack_C_VerifyFinal (CK_X_FUNCTION_LIST *self,
                     CK_SESSION_HANDLE session,
                     unsigned char * signature,
                     long unsigned int signature_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_VerifyFinal (funcs,
                                     session,
                                     signature,
                                     signature_len);
}
    
static CK_RV
stack_C_VerifyRecoverInit (CK_X_FUNCTION_LIST *self,
                           CK_SESSION_HANDLE session,
                           CK_MECHANISM_PTR mechanism,
                           CK_OBJECT_HANDLE hKey)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_VerifyRecoverInit (funcs,
                                           session,
                                           mechanism,
                                           hKey);
}
    
static CK_RV
stack_C_VerifyRecover (CK_X_FUNCTION_LIST *self,
                       CK_SESSION_HANDLE session,
                       unsigned char * signature,
                       long unsigned int signature_len,
                       unsigned char * data,
                       long unsigned int * ulDataLen)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_VerifyRecover (funcs,
                                       session,
                                       signature,
                                       signature_len,
                                       data,
                                       ulDataLen);
}
    
static CK_RV
stack_C_DigestEncryptUpdate (CK_X_FUNCTION_LIST *self,
                             CK_SESSION_HANDLE session,
                             unsigned char * part,
                             long unsigned int part_len,
                             unsigned char * encrypted_part,
                             long unsigned int * encrypted_part_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_DigestEncryptUpdate (funcs,
                                             session,
                                             part,
                                             part_len,
                                             encrypted_part,
                                             encrypted_part_len);
}
    
static CK_RV
stack_C_DecryptDigestUpdate (CK_X_FUNCTION_LIST *self,
                             CK_SESSION_HANDLE session,
                             unsigned char * encrypted_part,
                             long unsigned int encrypted_part_len,
                             unsigned char * part,
                             long unsigned int * part_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_DecryptDigestUpdate (funcs,
                                             session,
                                             encrypted_part,
                                             encrypted_part_len,
                                             part,
                                             part_len);
}
    
static CK_RV
stack_C_SignEncryptUpdate (CK_X_FUNCTION_LIST *self,
                           CK_SESSION_HANDLE session,
                           unsigned char * part,
                           long unsigned int part_len,
                           unsigned char * encrypted_part,
                           long unsigned int * encrypted_part_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_SignEncryptUpdate (funcs,
                                           session,
                                           part,
                                           part_len,
                                           encrypted_part,
                                           encrypted_part_len);
}
    
static CK_RV
stack_C_DecryptVerifyUpdate (CK_X_FUNCTION_LIST *self,
                             CK_SESSION_HANDLE session,
                             unsigned char * encrypted_part,
                             long unsigned int encrypted_part_len,
                             unsigned char * part,
                             long unsigned int * part_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_DecryptVerifyUpdate (funcs,
                                             session,
                                             encrypted_part,
                                             encrypted_part_len,
                                             part,
                                             part_len);
}
    
static CK_RV
stack_C_GenerateKey (CK_X_FUNCTION_LIST *self,
                     CK_SESSION_HANDLE session,
                     CK_MECHANISM_PTR mechanism,
                     CK_ATTRIBUTE_PTR pTemplate,
                     long unsigned int ulCount,
                     CK_OBJECT_HANDLE_PTR hKey)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_GenerateKey (funcs,
                                     session,
                                     mechanism,
                                     pTemplate,
                                     ulCount,
                                     hKey);
}
    
static CK_RV
stack_C_GenerateKeyPair (CK_X_FUNCTION_LIST *self,
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
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_GenerateKeyPair (funcs,
                                         session,
                                         mechanism,
                                         public_key_template,
                                         public_key_attribute_count,
                                         private_key_template,
                                         private_key_attribute_count,
                                         publicKey,
                                         private_key);
}
    
static CK_RV
stack_C_WrapKey (CK_X_FUNCTION_LIST *self,
                 CK_SESSION_HANDLE session,
                 CK_MECHANISM_PTR mechanism,
                 CK_OBJECT_HANDLE wrapping_key,
                 CK_OBJECT_HANDLE hKey,
                 unsigned char * wrapped_key,
                 long unsigned int * wrapped_key_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_WrapKey (funcs,
                                 session,
                                 mechanism,
                                 wrapping_key,
                                 hKey,
                                 wrapped_key,
                                 wrapped_key_len);
}
    
static CK_RV
stack_C_UnwrapKey (CK_X_FUNCTION_LIST *self,
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
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_UnwrapKey (funcs,
                                   session,
                                   mechanism,
                                   unwrapping_key,
                                   wrapped_key,
                                   wrapped_key_len,
                                   pTemplate,
                                   ulAttributeCount,
                                   hKey);
}
    
static CK_RV
stack_C_DeriveKey (CK_X_FUNCTION_LIST *self,
                   CK_SESSION_HANDLE session,
                   CK_MECHANISM_PTR mechanism,
                   CK_OBJECT_HANDLE base_key,
                   CK_ATTRIBUTE_PTR pTemplate,
                   long unsigned int ulAttributeCount,
                   CK_OBJECT_HANDLE_PTR hKey)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_DeriveKey (funcs,
                                   session,
                                   mechanism,
                                   base_key,
                                   pTemplate,
                                   ulAttributeCount,
                                   hKey);
}
    
static CK_RV
stack_C_SeedRandom (CK_X_FUNCTION_LIST *self,
                    CK_SESSION_HANDLE session,
                    unsigned char * seed,
                    long unsigned int ulSeedLen)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_SeedRandom (funcs,
                                    session,
                                    seed,
                                    ulSeedLen);
}
    
static CK_RV
stack_C_GenerateRandom (CK_X_FUNCTION_LIST *self,
                        CK_SESSION_HANDLE session,
                        unsigned char * random_data,
                        long unsigned int ulRandomLen)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_GenerateRandom (funcs,
                                        session,
                                        random_data,
                                        ulRandomLen);
}
    
static CK_RV
stack_C_WaitForSlotEvent (CK_X_FUNCTION_LIST *self,
                          CK_FLAGS flags,
                          CK_SLOT_ID_PTR slot,
                          CK_VOID_PTR pReserved)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_WaitForSlotEvent (funcs,
                                          flags,
                                          slot,
                                          pReserved);
}
    
static CK_RV
stack_C_LoginUser (CK_X_FUNCTION_LIST *self,
                   CK_SESSION_HANDLE session,
                   CK_USER_TYPE user_type,
                   unsigned char * pin,
                   long unsigned int pin_len,
                   unsigned char * username,
                   long unsigned int username_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_LoginUser (funcs,
                                   session,
                                   user_type,
                                   pin,
                                   pin_len,
                                   username,
                                   username_len);
}
    
static CK_RV
stack_C_SessionCancel (CK_X_FUNCTION_LIST *self,
                       CK_SESSION_HANDLE session,
                       CK_FLAGS flags)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_SessionCancel (funcs,
                                       session,
                                       flags);
}
    
static CK_RV
stack_C_MessageEncryptInit (CK_X_FUNCTION_LIST *self,
                            CK_SESSION_HANDLE session,
                            CK_MECHANISM_PTR mechanism,
                            CK_OBJECT_HANDLE hKey)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_MessageEncryptInit (funcs,
                                            session,
                                            mechanism,
                                            hKey);
}
    
static CK_RV
stack_C_EncryptMessage (CK_X_FUNCTION_LIST *self,
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
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_EncryptMessage (funcs,
                                        session,
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
stack_C_EncryptMessageBegin (CK_X_FUNCTION_LIST *self,
                             CK_SESSION_HANDLE session,
                             CK_VOID_PTR pParameter,
                             long unsigned int ulParameterLen,
                             unsigned char * associated_data,
                             long unsigned int associated_data_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_EncryptMessageBegin (funcs,
                                             session,
                                             pParameter,
                                             ulParameterLen,
                                             associated_data,
                                             associated_data_len);
}
    
static CK_RV
stack_C_EncryptMessageNext (CK_X_FUNCTION_LIST *self,
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
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_EncryptMessageNext (funcs,
                                            session,
                                            pParameter,
                                            ulParameterLen,
                                            plaintext_part,
                                            plaintext_part_len,
                                            ciphertext_part,
                                            ciphertext_part_len,
                                            flags);
}
    
static CK_RV
stack_C_MessageEncryptFinal (CK_X_FUNCTION_LIST *self,
                             CK_SESSION_HANDLE session)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_MessageEncryptFinal (funcs,
                                             session);
}
    
static CK_RV
stack_C_MessageDecryptInit (CK_X_FUNCTION_LIST *self,
                            CK_SESSION_HANDLE session,
                            CK_MECHANISM_PTR mechanism,
                            CK_OBJECT_HANDLE hKey)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_MessageDecryptInit (funcs,
                                            session,
                                            mechanism,
                                            hKey);
}
    
static CK_RV
stack_C_DecryptMessage (CK_X_FUNCTION_LIST *self,
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
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_DecryptMessage (funcs,
                                        session,
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
stack_C_DecryptMessageBegin (CK_X_FUNCTION_LIST *self,
                             CK_SESSION_HANDLE session,
                             CK_VOID_PTR pParameter,
                             long unsigned int ulParameterLen,
                             unsigned char * associated_data,
                             long unsigned int associated_data_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_DecryptMessageBegin (funcs,
                                             session,
                                             pParameter,
                                             ulParameterLen,
                                             associated_data,
                                             associated_data_len);
}
    
static CK_RV
stack_C_DecryptMessageNext (CK_X_FUNCTION_LIST *self,
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
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_DecryptMessageNext (funcs,
                                            session,
                                            pParameter,
                                            ulParameterLen,
                                            ciphertext_part,
                                            ciphertext_part_len,
                                            plaintext_part,
                                            plaintext_part_len,
                                            flags);
}
    
static CK_RV
stack_C_MessageDecryptFinal (CK_X_FUNCTION_LIST *self,
                             CK_SESSION_HANDLE session)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_MessageDecryptFinal (funcs,
                                             session);
}
    
static CK_RV
stack_C_MessageSignInit (CK_X_FUNCTION_LIST *self,
                         CK_SESSION_HANDLE session,
                         CK_MECHANISM_PTR mechanism,
                         CK_OBJECT_HANDLE hKey)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_MessageSignInit (funcs,
                                         session,
                                         mechanism,
                                         hKey);
}
    
static CK_RV
stack_C_SignMessage (CK_X_FUNCTION_LIST *self,
                     CK_SESSION_HANDLE session,
                     CK_VOID_PTR pParameter,
                     long unsigned int ulParameterLen,
                     unsigned char * data,
                     long unsigned int ulDataLen,
                     unsigned char * signature,
                     long unsigned int * signature_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_SignMessage (funcs,
                                     session,
                                     pParameter,
                                     ulParameterLen,
                                     data,
                                     ulDataLen,
                                     signature,
                                     signature_len);
}
    
static CK_RV
stack_C_SignMessageBegin (CK_X_FUNCTION_LIST *self,
                          CK_SESSION_HANDLE session,
                          CK_VOID_PTR pParameter,
                          long unsigned int ulParameterLen)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_SignMessageBegin (funcs,
                                          session,
                                          pParameter,
                                          ulParameterLen);
}
    
static CK_RV
stack_C_SignMessageNext (CK_X_FUNCTION_LIST *self,
                         CK_SESSION_HANDLE session,
                         CK_VOID_PTR pParameter,
                         long unsigned int ulParameterLen,
                         unsigned char * data,
                         long unsigned int ulDataLen,
                         unsigned char * signature,
                         long unsigned int * signature_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_SignMessageNext (funcs,
                                         session,
                                         pParameter,
                                         ulParameterLen,
                                         data,
                                         ulDataLen,
                                         signature,
                                         signature_len);
}
    
static CK_RV
stack_C_MessageSignFinal (CK_X_FUNCTION_LIST *self,
                          CK_SESSION_HANDLE session)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_MessageSignFinal (funcs,
                                          session);
}
    
static CK_RV
stack_C_MessageVerifyInit (CK_X_FUNCTION_LIST *self,
                           CK_SESSION_HANDLE session,
                           CK_MECHANISM_PTR mechanism,
                           CK_OBJECT_HANDLE hKey)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_MessageVerifyInit (funcs,
                                           session,
                                           mechanism,
                                           hKey);
}
    
static CK_RV
stack_C_VerifyMessage (CK_X_FUNCTION_LIST *self,
                       CK_SESSION_HANDLE session,
                       CK_VOID_PTR pParameter,
                       long unsigned int ulParameterLen,
                       unsigned char * data,
                       long unsigned int ulDataLen,
                       unsigned char * signature,
                       long unsigned int signature_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_VerifyMessage (funcs,
                                       session,
                                       pParameter,
                                       ulParameterLen,
                                       data,
                                       ulDataLen,
                                       signature,
                                       signature_len);
}
    
static CK_RV
stack_C_VerifyMessageBegin (CK_X_FUNCTION_LIST *self,
                            CK_SESSION_HANDLE session,
                            CK_VOID_PTR pParameter,
                            long unsigned int ulParameterLen)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_VerifyMessageBegin (funcs,
                                            session,
                                            pParameter,
                                            ulParameterLen);
}
    
static CK_RV
stack_C_VerifyMessageNext (CK_X_FUNCTION_LIST *self,
                           CK_SESSION_HANDLE session,
                           CK_VOID_PTR pParameter,
                           long unsigned int ulParameterLen,
                           unsigned char * data,
                           long unsigned int ulDataLen,
                           unsigned char * signature,
                           long unsigned int signature_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_VerifyMessageNext (funcs,
                                           session,
                                           pParameter,
                                           ulParameterLen,
                                           data,
                                           ulDataLen,
                                           signature,
                                           signature_len);
}
    
static CK_RV
stack_C_MessageVerifyFinal (CK_X_FUNCTION_LIST *self,
                            CK_SESSION_HANDLE session)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_MessageVerifyFinal (funcs,
                                            session);
}
    
static CK_RV
stack_C_EncapsulateKey (CK_X_FUNCTION_LIST *self,
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
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_EncapsulateKey (funcs,
                                        session,
                                        mechanism,
                                        publicKey,
                                        pTemplate,
                                        ulAttributeCount,
                                        ciphertext,
                                        ciphertext_len,
                                        phKey);
}
    
static CK_RV
stack_C_DecapsulateKey (CK_X_FUNCTION_LIST *self,
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
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_DecapsulateKey (funcs,
                                        session,
                                        mechanism,
                                        private_key,
                                        pTemplate,
                                        ulAttributeCount,
                                        ciphertext,
                                        ciphertext_len,
                                        phKey);
}
    
static CK_RV
stack_C_VerifySignatureInit (CK_X_FUNCTION_LIST *self,
                             CK_SESSION_HANDLE session,
                             CK_MECHANISM_PTR mechanism,
                             CK_OBJECT_HANDLE hKey,
                             unsigned char * signature,
                             long unsigned int signature_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_VerifySignatureInit (funcs,
                                             session,
                                             mechanism,
                                             hKey,
                                             signature,
                                             signature_len);
}
    
static CK_RV
stack_C_VerifySignature (CK_X_FUNCTION_LIST *self,
                         CK_SESSION_HANDLE session,
                         unsigned char * data,
                         long unsigned int ulDataLen)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_VerifySignature (funcs,
                                         session,
                                         data,
                                         ulDataLen);
}
    
static CK_RV
stack_C_VerifySignatureUpdate (CK_X_FUNCTION_LIST *self,
                               CK_SESSION_HANDLE session,
                               unsigned char * part,
                               long unsigned int part_len)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_VerifySignatureUpdate (funcs,
                                               session,
                                               part,
                                               part_len);
}
    
static CK_RV
stack_C_VerifySignatureFinal (CK_X_FUNCTION_LIST *self,
                              CK_SESSION_HANDLE session)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_VerifySignatureFinal (funcs,
                                              session);
}
    
static CK_RV
stack_C_GetSessionValidationFlags (CK_X_FUNCTION_LIST *self,
                                   CK_SESSION_HANDLE session,
                                   CK_SESSION_VALIDATION_FLAGS_TYPE type,
                                   CK_FLAGS * flags_ptr)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_GetSessionValidationFlags (funcs,
                                                   session,
                                                   type,
                                                   flags_ptr);
}
    
static CK_RV
stack_C_AsyncComplete (CK_X_FUNCTION_LIST *self,
                       CK_SESSION_HANDLE session,
                       unsigned char * function_name,
                       CK_ASYNC_DATA_PTR result)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_AsyncComplete (funcs,
                                       session,
                                       function_name,
                                       result);
}
    
static CK_RV
stack_C_AsyncGetID (CK_X_FUNCTION_LIST *self,
                    CK_SESSION_HANDLE session,
                    unsigned char * function_name,
                    long unsigned int * id_ptr)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_AsyncGetID (funcs,
                                    session,
                                    function_name,
                                    id_ptr);
}
    
static CK_RV
stack_C_AsyncJoin (CK_X_FUNCTION_LIST *self,
                   CK_SESSION_HANDLE session,
                   unsigned char * function_name,
                   long unsigned int id,
                   unsigned char * data,
                   long unsigned int ulDataLen)
{
        p11_virtual *virt = (p11_virtual *)self;
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_AsyncJoin (funcs,
                                   session,
                                   function_name,
                                   id,
                                   data,
                                   ulDataLen);
}
    
static CK_RV
stack_C_WrapKeyAuthenticated (CK_X_FUNCTION_LIST *self,
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
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_WrapKeyAuthenticated (funcs,
                                              session,
                                              mechanism,
                                              wrapping_key,
                                              hKey,
                                              associated_data,
                                              associated_data_len,
                                              wrapped_key,
                                              wrapped_key_len);
}
    
static CK_RV
stack_C_UnwrapKeyAuthenticated (CK_X_FUNCTION_LIST *self,
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
        CK_X_FUNCTION_LIST *funcs = virt->lower_module;
        return funcs->C_UnwrapKeyAuthenticated (funcs,
                                                session,
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
    

CK_X_FUNCTION_LIST p11_virtual_stack = {
        { CRYPTOKI_VERSION_MAJOR, CRYPTOKI_VERSION_MINOR },  /* version */
        stack_C_Initialize,
        stack_C_Finalize,
        stack_C_GetInfo,
        stack_C_GetSlotList,
        stack_C_GetSlotInfo,
        stack_C_GetTokenInfo,
        stack_C_GetMechanismList,
        stack_C_GetMechanismInfo,
        stack_C_InitToken,
        stack_C_InitPIN,
        stack_C_SetPIN,
        stack_C_OpenSession,
        stack_C_CloseSession,
        stack_C_CloseAllSessions,
        stack_C_GetSessionInfo,
        stack_C_GetOperationState,
        stack_C_SetOperationState,
        stack_C_Login,
        stack_C_Logout,
        stack_C_CreateObject,
        stack_C_CopyObject,
        stack_C_DestroyObject,
        stack_C_GetObjectSize,
        stack_C_GetAttributeValue,
        stack_C_SetAttributeValue,
        stack_C_FindObjectsInit,
        stack_C_FindObjects,
        stack_C_FindObjectsFinal,
        stack_C_EncryptInit,
        stack_C_Encrypt,
        stack_C_EncryptUpdate,
        stack_C_EncryptFinal,
        stack_C_DecryptInit,
        stack_C_Decrypt,
        stack_C_DecryptUpdate,
        stack_C_DecryptFinal,
        stack_C_DigestInit,
        stack_C_Digest,
        stack_C_DigestUpdate,
        stack_C_DigestKey,
        stack_C_DigestFinal,
        stack_C_SignInit,
        stack_C_Sign,
        stack_C_SignUpdate,
        stack_C_SignFinal,
        stack_C_SignRecoverInit,
        stack_C_SignRecover,
        stack_C_VerifyInit,
        stack_C_Verify,
        stack_C_VerifyUpdate,
        stack_C_VerifyFinal,
        stack_C_VerifyRecoverInit,
        stack_C_VerifyRecover,
        stack_C_DigestEncryptUpdate,
        stack_C_DecryptDigestUpdate,
        stack_C_SignEncryptUpdate,
        stack_C_DecryptVerifyUpdate,
        stack_C_GenerateKey,
        stack_C_GenerateKeyPair,
        stack_C_WrapKey,
        stack_C_UnwrapKey,
        stack_C_DeriveKey,
        stack_C_SeedRandom,
        stack_C_GenerateRandom,
        stack_C_WaitForSlotEvent,
        stack_C_LoginUser,
        stack_C_SessionCancel,
        stack_C_MessageEncryptInit,
        stack_C_EncryptMessage,
        stack_C_EncryptMessageBegin,
        stack_C_EncryptMessageNext,
        stack_C_MessageEncryptFinal,
        stack_C_MessageDecryptInit,
        stack_C_DecryptMessage,
        stack_C_DecryptMessageBegin,
        stack_C_DecryptMessageNext,
        stack_C_MessageDecryptFinal,
        stack_C_MessageSignInit,
        stack_C_SignMessage,
        stack_C_SignMessageBegin,
        stack_C_SignMessageNext,
        stack_C_MessageSignFinal,
        stack_C_MessageVerifyInit,
        stack_C_VerifyMessage,
        stack_C_VerifyMessageBegin,
        stack_C_VerifyMessageNext,
        stack_C_MessageVerifyFinal,
        stack_C_EncapsulateKey,
        stack_C_DecapsulateKey,
        stack_C_VerifySignatureInit,
        stack_C_VerifySignature,
        stack_C_VerifySignatureUpdate,
        stack_C_VerifySignatureFinal,
        stack_C_GetSessionValidationFlags,
        stack_C_AsyncComplete,
        stack_C_AsyncGetID,
        stack_C_AsyncJoin,
        stack_C_WrapKeyAuthenticated,
        stack_C_UnwrapKeyAuthenticated
};
