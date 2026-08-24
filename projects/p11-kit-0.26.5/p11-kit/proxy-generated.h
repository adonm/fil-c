
/* DO NOT EDIT! GENERATED AUTOMATICALLY! */

static CK_RV
proxy_C_GetSlotInfo (CK_X_FUNCTION_LIST *self,
                     CK_SLOT_ID slotID,
                     CK_SLOT_INFO_PTR pInfo)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_slot_to_real (state->px, &slotID, &map);
        if (rv != CKR_OK)
                return rv;
        return map.funcs->C_GetSlotInfo (slotID,
                                         pInfo);
}
    
static CK_RV
proxy_C_GetTokenInfo (CK_X_FUNCTION_LIST *self,
                      CK_SLOT_ID slotID,
                      CK_TOKEN_INFO_PTR pInfo)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_slot_to_real (state->px, &slotID, &map);
        if (rv != CKR_OK)
                return rv;
        return map.funcs->C_GetTokenInfo (slotID,
                                          pInfo);
}
    
static CK_RV
proxy_C_GetMechanismList (CK_X_FUNCTION_LIST *self,
                          CK_SLOT_ID slotID,
                          CK_MECHANISM_TYPE_PTR mechanism_list,
                          long unsigned int * ulCount)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_slot_to_real (state->px, &slotID, &map);
        if (rv != CKR_OK)
                return rv;
        return map.funcs->C_GetMechanismList (slotID,
                                              mechanism_list,
                                              ulCount);
}
    
static CK_RV
proxy_C_GetMechanismInfo (CK_X_FUNCTION_LIST *self,
                          CK_SLOT_ID slotID,
                          CK_MECHANISM_TYPE type,
                          CK_MECHANISM_INFO_PTR pInfo)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_slot_to_real (state->px, &slotID, &map);
        if (rv != CKR_OK)
                return rv;
        return map.funcs->C_GetMechanismInfo (slotID,
                                              type,
                                              pInfo);
}
    
static CK_RV
proxy_C_InitToken (CK_X_FUNCTION_LIST *self,
                   CK_SLOT_ID slotID,
                   unsigned char * pin,
                   long unsigned int pin_len,
                   unsigned char * label)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_slot_to_real (state->px, &slotID, &map);
        if (rv != CKR_OK)
                return rv;
        return map.funcs->C_InitToken (slotID,
                                       pin,
                                       pin_len,
                                       label);
}
    
static CK_RV
proxy_C_InitPIN (CK_X_FUNCTION_LIST *self,
                 CK_SESSION_HANDLE session,
                 unsigned char * pin,
                 long unsigned int pin_len)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return map.funcs->C_InitPIN (session,
                                     pin,
                                     pin_len);
}
    
static CK_RV
proxy_C_SetPIN (CK_X_FUNCTION_LIST *self,
                CK_SESSION_HANDLE session,
                unsigned char * old_pin,
                long unsigned int old_len,
                unsigned char * new_pin,
                long unsigned int new_len)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return map.funcs->C_SetPIN (session,
                                    old_pin,
                                    old_len,
                                    new_pin,
                                    new_len);
}
    
static CK_RV
proxy_C_GetOperationState (CK_X_FUNCTION_LIST *self,
                           CK_SESSION_HANDLE session,
                           unsigned char * operation_state,
                           long unsigned int * operation_state_len)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return map.funcs->C_GetOperationState (session,
                                               operation_state,
                                               operation_state_len);
}
    
static CK_RV
proxy_C_SetOperationState (CK_X_FUNCTION_LIST *self,
                           CK_SESSION_HANDLE session,
                           unsigned char * operation_state,
                           long unsigned int operation_state_len,
                           CK_OBJECT_HANDLE encryption_key,
                           CK_OBJECT_HANDLE authentication_key)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return map.funcs->C_SetOperationState (session,
                                               operation_state,
                                               operation_state_len,
                                               encryption_key,
                                               authentication_key);
}
    
static CK_RV
proxy_C_Login (CK_X_FUNCTION_LIST *self,
               CK_SESSION_HANDLE session,
               CK_USER_TYPE user_type,
               unsigned char * pin,
               long unsigned int pin_len)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return map.funcs->C_Login (session,
                                   user_type,
                                   pin,
                                   pin_len);
}
    
static CK_RV
proxy_C_Logout (CK_X_FUNCTION_LIST *self,
                CK_SESSION_HANDLE session)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return map.funcs->C_Logout (session);
}
    
static CK_RV
proxy_C_CreateObject (CK_X_FUNCTION_LIST *self,
                      CK_SESSION_HANDLE session,
                      CK_ATTRIBUTE_PTR pTemplate,
                      long unsigned int ulCount,
                      CK_OBJECT_HANDLE_PTR object)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return map.funcs->C_CreateObject (session,
                                          pTemplate,
                                          ulCount,
                                          object);
}
    
static CK_RV
proxy_C_CopyObject (CK_X_FUNCTION_LIST *self,
                    CK_SESSION_HANDLE session,
                    CK_OBJECT_HANDLE object,
                    CK_ATTRIBUTE_PTR pTemplate,
                    long unsigned int ulCount,
                    CK_OBJECT_HANDLE_PTR new_object)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return map.funcs->C_CopyObject (session,
                                        object,
                                        pTemplate,
                                        ulCount,
                                        new_object);
}
    
static CK_RV
proxy_C_DestroyObject (CK_X_FUNCTION_LIST *self,
                       CK_SESSION_HANDLE session,
                       CK_OBJECT_HANDLE object)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return map.funcs->C_DestroyObject (session,
                                           object);
}
    
static CK_RV
proxy_C_GetObjectSize (CK_X_FUNCTION_LIST *self,
                       CK_SESSION_HANDLE session,
                       CK_OBJECT_HANDLE object,
                       long unsigned int * size)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return map.funcs->C_GetObjectSize (session,
                                           object,
                                           size);
}
    
static CK_RV
proxy_C_GetAttributeValue (CK_X_FUNCTION_LIST *self,
                           CK_SESSION_HANDLE session,
                           CK_OBJECT_HANDLE object,
                           CK_ATTRIBUTE_PTR pTemplate,
                           long unsigned int ulCount)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return map.funcs->C_GetAttributeValue (session,
                                               object,
                                               pTemplate,
                                               ulCount);
}
    
static CK_RV
proxy_C_SetAttributeValue (CK_X_FUNCTION_LIST *self,
                           CK_SESSION_HANDLE session,
                           CK_OBJECT_HANDLE object,
                           CK_ATTRIBUTE_PTR pTemplate,
                           long unsigned int ulCount)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return map.funcs->C_SetAttributeValue (session,
                                               object,
                                               pTemplate,
                                               ulCount);
}
    
static CK_RV
proxy_C_FindObjectsInit (CK_X_FUNCTION_LIST *self,
                         CK_SESSION_HANDLE session,
                         CK_ATTRIBUTE_PTR pTemplate,
                         long unsigned int ulCount)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return map.funcs->C_FindObjectsInit (session,
                                             pTemplate,
                                             ulCount);
}
    
static CK_RV
proxy_C_FindObjects (CK_X_FUNCTION_LIST *self,
                     CK_SESSION_HANDLE session,
                     CK_OBJECT_HANDLE_PTR object,
                     long unsigned int max_object_count,
                     long unsigned int * object_count)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return map.funcs->C_FindObjects (session,
                                         object,
                                         max_object_count,
                                         object_count);
}
    
static CK_RV
proxy_C_FindObjectsFinal (CK_X_FUNCTION_LIST *self,
                          CK_SESSION_HANDLE session)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return map.funcs->C_FindObjectsFinal (session);
}
    
static CK_RV
proxy_C_EncryptInit (CK_X_FUNCTION_LIST *self,
                     CK_SESSION_HANDLE session,
                     CK_MECHANISM_PTR mechanism,
                     CK_OBJECT_HANDLE hKey)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return map.funcs->C_EncryptInit (session,
                                         mechanism,
                                         hKey);
}
    
static CK_RV
proxy_C_Encrypt (CK_X_FUNCTION_LIST *self,
                 CK_SESSION_HANDLE session,
                 unsigned char * data,
                 long unsigned int ulDataLen,
                 unsigned char * encrypted_data,
                 long unsigned int * encrypted_data_len)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return map.funcs->C_Encrypt (session,
                                     data,
                                     ulDataLen,
                                     encrypted_data,
                                     encrypted_data_len);
}
    
static CK_RV
proxy_C_EncryptUpdate (CK_X_FUNCTION_LIST *self,
                       CK_SESSION_HANDLE session,
                       unsigned char * part,
                       long unsigned int part_len,
                       unsigned char * encrypted_part,
                       long unsigned int * encrypted_part_len)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return map.funcs->C_EncryptUpdate (session,
                                           part,
                                           part_len,
                                           encrypted_part,
                                           encrypted_part_len);
}
    
static CK_RV
proxy_C_EncryptFinal (CK_X_FUNCTION_LIST *self,
                      CK_SESSION_HANDLE session,
                      unsigned char * last_encrypted_part,
                      long unsigned int * last_encrypted_part_len)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return map.funcs->C_EncryptFinal (session,
                                          last_encrypted_part,
                                          last_encrypted_part_len);
}
    
static CK_RV
proxy_C_DecryptInit (CK_X_FUNCTION_LIST *self,
                     CK_SESSION_HANDLE session,
                     CK_MECHANISM_PTR mechanism,
                     CK_OBJECT_HANDLE hKey)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return map.funcs->C_DecryptInit (session,
                                         mechanism,
                                         hKey);
}
    
static CK_RV
proxy_C_Decrypt (CK_X_FUNCTION_LIST *self,
                 CK_SESSION_HANDLE session,
                 unsigned char * encrypted_data,
                 long unsigned int encrypted_data_len,
                 unsigned char * data,
                 long unsigned int * ulDataLen)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return map.funcs->C_Decrypt (session,
                                     encrypted_data,
                                     encrypted_data_len,
                                     data,
                                     ulDataLen);
}
    
static CK_RV
proxy_C_DecryptUpdate (CK_X_FUNCTION_LIST *self,
                       CK_SESSION_HANDLE session,
                       unsigned char * encrypted_part,
                       long unsigned int encrypted_part_len,
                       unsigned char * part,
                       long unsigned int * part_len)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return map.funcs->C_DecryptUpdate (session,
                                           encrypted_part,
                                           encrypted_part_len,
                                           part,
                                           part_len);
}
    
static CK_RV
proxy_C_DecryptFinal (CK_X_FUNCTION_LIST *self,
                      CK_SESSION_HANDLE session,
                      unsigned char * last_part,
                      long unsigned int * last_part_len)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return map.funcs->C_DecryptFinal (session,
                                          last_part,
                                          last_part_len);
}
    
static CK_RV
proxy_C_DigestInit (CK_X_FUNCTION_LIST *self,
                    CK_SESSION_HANDLE session,
                    CK_MECHANISM_PTR mechanism)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return map.funcs->C_DigestInit (session,
                                        mechanism);
}
    
static CK_RV
proxy_C_Digest (CK_X_FUNCTION_LIST *self,
                CK_SESSION_HANDLE session,
                unsigned char * data,
                long unsigned int ulDataLen,
                unsigned char * digest,
                long unsigned int * digest_len)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return map.funcs->C_Digest (session,
                                    data,
                                    ulDataLen,
                                    digest,
                                    digest_len);
}
    
static CK_RV
proxy_C_DigestUpdate (CK_X_FUNCTION_LIST *self,
                      CK_SESSION_HANDLE session,
                      unsigned char * part,
                      long unsigned int part_len)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return map.funcs->C_DigestUpdate (session,
                                          part,
                                          part_len);
}
    
static CK_RV
proxy_C_DigestKey (CK_X_FUNCTION_LIST *self,
                   CK_SESSION_HANDLE session,
                   CK_OBJECT_HANDLE hKey)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return map.funcs->C_DigestKey (session,
                                       hKey);
}
    
static CK_RV
proxy_C_DigestFinal (CK_X_FUNCTION_LIST *self,
                     CK_SESSION_HANDLE session,
                     unsigned char * digest,
                     long unsigned int * digest_len)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return map.funcs->C_DigestFinal (session,
                                         digest,
                                         digest_len);
}
    
static CK_RV
proxy_C_SignInit (CK_X_FUNCTION_LIST *self,
                  CK_SESSION_HANDLE session,
                  CK_MECHANISM_PTR mechanism,
                  CK_OBJECT_HANDLE hKey)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return map.funcs->C_SignInit (session,
                                      mechanism,
                                      hKey);
}
    
static CK_RV
proxy_C_Sign (CK_X_FUNCTION_LIST *self,
              CK_SESSION_HANDLE session,
              unsigned char * data,
              long unsigned int ulDataLen,
              unsigned char * signature,
              long unsigned int * signature_len)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return map.funcs->C_Sign (session,
                                  data,
                                  ulDataLen,
                                  signature,
                                  signature_len);
}
    
static CK_RV
proxy_C_SignUpdate (CK_X_FUNCTION_LIST *self,
                    CK_SESSION_HANDLE session,
                    unsigned char * part,
                    long unsigned int part_len)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return map.funcs->C_SignUpdate (session,
                                        part,
                                        part_len);
}
    
static CK_RV
proxy_C_SignFinal (CK_X_FUNCTION_LIST *self,
                   CK_SESSION_HANDLE session,
                   unsigned char * signature,
                   long unsigned int * signature_len)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return map.funcs->C_SignFinal (session,
                                       signature,
                                       signature_len);
}
    
static CK_RV
proxy_C_SignRecoverInit (CK_X_FUNCTION_LIST *self,
                         CK_SESSION_HANDLE session,
                         CK_MECHANISM_PTR mechanism,
                         CK_OBJECT_HANDLE hKey)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return map.funcs->C_SignRecoverInit (session,
                                             mechanism,
                                             hKey);
}
    
static CK_RV
proxy_C_SignRecover (CK_X_FUNCTION_LIST *self,
                     CK_SESSION_HANDLE session,
                     unsigned char * data,
                     long unsigned int ulDataLen,
                     unsigned char * signature,
                     long unsigned int * signature_len)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return map.funcs->C_SignRecover (session,
                                         data,
                                         ulDataLen,
                                         signature,
                                         signature_len);
}
    
static CK_RV
proxy_C_VerifyInit (CK_X_FUNCTION_LIST *self,
                    CK_SESSION_HANDLE session,
                    CK_MECHANISM_PTR mechanism,
                    CK_OBJECT_HANDLE hKey)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return map.funcs->C_VerifyInit (session,
                                        mechanism,
                                        hKey);
}
    
static CK_RV
proxy_C_Verify (CK_X_FUNCTION_LIST *self,
                CK_SESSION_HANDLE session,
                unsigned char * data,
                long unsigned int ulDataLen,
                unsigned char * signature,
                long unsigned int signature_len)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return map.funcs->C_Verify (session,
                                    data,
                                    ulDataLen,
                                    signature,
                                    signature_len);
}
    
static CK_RV
proxy_C_VerifyUpdate (CK_X_FUNCTION_LIST *self,
                      CK_SESSION_HANDLE session,
                      unsigned char * part,
                      long unsigned int part_len)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return map.funcs->C_VerifyUpdate (session,
                                          part,
                                          part_len);
}
    
static CK_RV
proxy_C_VerifyFinal (CK_X_FUNCTION_LIST *self,
                     CK_SESSION_HANDLE session,
                     unsigned char * signature,
                     long unsigned int signature_len)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return map.funcs->C_VerifyFinal (session,
                                         signature,
                                         signature_len);
}
    
static CK_RV
proxy_C_VerifyRecoverInit (CK_X_FUNCTION_LIST *self,
                           CK_SESSION_HANDLE session,
                           CK_MECHANISM_PTR mechanism,
                           CK_OBJECT_HANDLE hKey)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return map.funcs->C_VerifyRecoverInit (session,
                                               mechanism,
                                               hKey);
}
    
static CK_RV
proxy_C_VerifyRecover (CK_X_FUNCTION_LIST *self,
                       CK_SESSION_HANDLE session,
                       unsigned char * signature,
                       long unsigned int signature_len,
                       unsigned char * data,
                       long unsigned int * ulDataLen)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return map.funcs->C_VerifyRecover (session,
                                           signature,
                                           signature_len,
                                           data,
                                           ulDataLen);
}
    
static CK_RV
proxy_C_DigestEncryptUpdate (CK_X_FUNCTION_LIST *self,
                             CK_SESSION_HANDLE session,
                             unsigned char * part,
                             long unsigned int part_len,
                             unsigned char * encrypted_part,
                             long unsigned int * encrypted_part_len)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return map.funcs->C_DigestEncryptUpdate (session,
                                                 part,
                                                 part_len,
                                                 encrypted_part,
                                                 encrypted_part_len);
}
    
static CK_RV
proxy_C_DecryptDigestUpdate (CK_X_FUNCTION_LIST *self,
                             CK_SESSION_HANDLE session,
                             unsigned char * encrypted_part,
                             long unsigned int encrypted_part_len,
                             unsigned char * part,
                             long unsigned int * part_len)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return map.funcs->C_DecryptDigestUpdate (session,
                                                 encrypted_part,
                                                 encrypted_part_len,
                                                 part,
                                                 part_len);
}
    
static CK_RV
proxy_C_SignEncryptUpdate (CK_X_FUNCTION_LIST *self,
                           CK_SESSION_HANDLE session,
                           unsigned char * part,
                           long unsigned int part_len,
                           unsigned char * encrypted_part,
                           long unsigned int * encrypted_part_len)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return map.funcs->C_SignEncryptUpdate (session,
                                               part,
                                               part_len,
                                               encrypted_part,
                                               encrypted_part_len);
}
    
static CK_RV
proxy_C_DecryptVerifyUpdate (CK_X_FUNCTION_LIST *self,
                             CK_SESSION_HANDLE session,
                             unsigned char * encrypted_part,
                             long unsigned int encrypted_part_len,
                             unsigned char * part,
                             long unsigned int * part_len)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return map.funcs->C_DecryptVerifyUpdate (session,
                                                 encrypted_part,
                                                 encrypted_part_len,
                                                 part,
                                                 part_len);
}
    
static CK_RV
proxy_C_GenerateKey (CK_X_FUNCTION_LIST *self,
                     CK_SESSION_HANDLE session,
                     CK_MECHANISM_PTR mechanism,
                     CK_ATTRIBUTE_PTR pTemplate,
                     long unsigned int ulCount,
                     CK_OBJECT_HANDLE_PTR hKey)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return map.funcs->C_GenerateKey (session,
                                         mechanism,
                                         pTemplate,
                                         ulCount,
                                         hKey);
}
    
static CK_RV
proxy_C_GenerateKeyPair (CK_X_FUNCTION_LIST *self,
                         CK_SESSION_HANDLE session,
                         CK_MECHANISM_PTR mechanism,
                         CK_ATTRIBUTE_PTR public_key_template,
                         long unsigned int public_key_attribute_count,
                         CK_ATTRIBUTE_PTR private_key_template,
                         long unsigned int private_key_attribute_count,
                         CK_OBJECT_HANDLE_PTR publicKey,
                         CK_OBJECT_HANDLE_PTR private_key)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return map.funcs->C_GenerateKeyPair (session,
                                             mechanism,
                                             public_key_template,
                                             public_key_attribute_count,
                                             private_key_template,
                                             private_key_attribute_count,
                                             publicKey,
                                             private_key);
}
    
static CK_RV
proxy_C_WrapKey (CK_X_FUNCTION_LIST *self,
                 CK_SESSION_HANDLE session,
                 CK_MECHANISM_PTR mechanism,
                 CK_OBJECT_HANDLE wrapping_key,
                 CK_OBJECT_HANDLE hKey,
                 unsigned char * wrapped_key,
                 long unsigned int * wrapped_key_len)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return map.funcs->C_WrapKey (session,
                                     mechanism,
                                     wrapping_key,
                                     hKey,
                                     wrapped_key,
                                     wrapped_key_len);
}
    
static CK_RV
proxy_C_UnwrapKey (CK_X_FUNCTION_LIST *self,
                   CK_SESSION_HANDLE session,
                   CK_MECHANISM_PTR mechanism,
                   CK_OBJECT_HANDLE unwrapping_key,
                   unsigned char * wrapped_key,
                   long unsigned int wrapped_key_len,
                   CK_ATTRIBUTE_PTR pTemplate,
                   long unsigned int ulAttributeCount,
                   CK_OBJECT_HANDLE_PTR hKey)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return map.funcs->C_UnwrapKey (session,
                                       mechanism,
                                       unwrapping_key,
                                       wrapped_key,
                                       wrapped_key_len,
                                       pTemplate,
                                       ulAttributeCount,
                                       hKey);
}
    
static CK_RV
proxy_C_DeriveKey (CK_X_FUNCTION_LIST *self,
                   CK_SESSION_HANDLE session,
                   CK_MECHANISM_PTR mechanism,
                   CK_OBJECT_HANDLE base_key,
                   CK_ATTRIBUTE_PTR pTemplate,
                   long unsigned int ulAttributeCount,
                   CK_OBJECT_HANDLE_PTR hKey)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return map.funcs->C_DeriveKey (session,
                                       mechanism,
                                       base_key,
                                       pTemplate,
                                       ulAttributeCount,
                                       hKey);
}
    
static CK_RV
proxy_C_SeedRandom (CK_X_FUNCTION_LIST *self,
                    CK_SESSION_HANDLE session,
                    unsigned char * seed,
                    long unsigned int ulSeedLen)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return map.funcs->C_SeedRandom (session,
                                        seed,
                                        ulSeedLen);
}
    
static CK_RV
proxy_C_GenerateRandom (CK_X_FUNCTION_LIST *self,
                        CK_SESSION_HANDLE session,
                        unsigned char * random_data,
                        long unsigned int ulRandomLen)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return map.funcs->C_GenerateRandom (session,
                                            random_data,
                                            ulRandomLen);
}
    
static CK_RV
proxy_C_LoginUser (CK_X_FUNCTION_LIST *self,
                   CK_SESSION_HANDLE session,
                   CK_USER_TYPE user_type,
                   unsigned char * pin,
                   long unsigned int pin_len,
                   unsigned char * username,
                   long unsigned int username_len)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return ((CK_FUNCTION_LIST_3_2_PTR)map.funcs)->C_LoginUser (session,
                                                                   user_type,
                                                                   pin,
                                                                   pin_len,
                                                                   username,
                                                                   username_len);
}
    
static CK_RV
proxy_C_SessionCancel (CK_X_FUNCTION_LIST *self,
                       CK_SESSION_HANDLE session,
                       CK_FLAGS flags)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return ((CK_FUNCTION_LIST_3_2_PTR)map.funcs)->C_SessionCancel (session,
                                                                       flags);
}
    
static CK_RV
proxy_C_MessageEncryptInit (CK_X_FUNCTION_LIST *self,
                            CK_SESSION_HANDLE session,
                            CK_MECHANISM_PTR mechanism,
                            CK_OBJECT_HANDLE hKey)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return ((CK_FUNCTION_LIST_3_2_PTR)map.funcs)->C_MessageEncryptInit (session,
                                                                            mechanism,
                                                                            hKey);
}
    
static CK_RV
proxy_C_EncryptMessage (CK_X_FUNCTION_LIST *self,
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
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return ((CK_FUNCTION_LIST_3_2_PTR)map.funcs)->C_EncryptMessage (session,
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
proxy_C_EncryptMessageBegin (CK_X_FUNCTION_LIST *self,
                             CK_SESSION_HANDLE session,
                             CK_VOID_PTR pParameter,
                             long unsigned int ulParameterLen,
                             unsigned char * associated_data,
                             long unsigned int associated_data_len)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return ((CK_FUNCTION_LIST_3_2_PTR)map.funcs)->C_EncryptMessageBegin (session,
                                                                             pParameter,
                                                                             ulParameterLen,
                                                                             associated_data,
                                                                             associated_data_len);
}
    
static CK_RV
proxy_C_EncryptMessageNext (CK_X_FUNCTION_LIST *self,
                            CK_SESSION_HANDLE session,
                            CK_VOID_PTR pParameter,
                            long unsigned int ulParameterLen,
                            unsigned char * plaintext_part,
                            long unsigned int plaintext_part_len,
                            unsigned char * ciphertext_part,
                            long unsigned int * ciphertext_part_len,
                            CK_FLAGS flags)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return ((CK_FUNCTION_LIST_3_2_PTR)map.funcs)->C_EncryptMessageNext (session,
                                                                            pParameter,
                                                                            ulParameterLen,
                                                                            plaintext_part,
                                                                            plaintext_part_len,
                                                                            ciphertext_part,
                                                                            ciphertext_part_len,
                                                                            flags);
}
    
static CK_RV
proxy_C_MessageEncryptFinal (CK_X_FUNCTION_LIST *self,
                             CK_SESSION_HANDLE session)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return ((CK_FUNCTION_LIST_3_2_PTR)map.funcs)->C_MessageEncryptFinal (session);
}
    
static CK_RV
proxy_C_MessageDecryptInit (CK_X_FUNCTION_LIST *self,
                            CK_SESSION_HANDLE session,
                            CK_MECHANISM_PTR mechanism,
                            CK_OBJECT_HANDLE hKey)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return ((CK_FUNCTION_LIST_3_2_PTR)map.funcs)->C_MessageDecryptInit (session,
                                                                            mechanism,
                                                                            hKey);
}
    
static CK_RV
proxy_C_DecryptMessage (CK_X_FUNCTION_LIST *self,
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
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return ((CK_FUNCTION_LIST_3_2_PTR)map.funcs)->C_DecryptMessage (session,
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
proxy_C_DecryptMessageBegin (CK_X_FUNCTION_LIST *self,
                             CK_SESSION_HANDLE session,
                             CK_VOID_PTR pParameter,
                             long unsigned int ulParameterLen,
                             unsigned char * associated_data,
                             long unsigned int associated_data_len)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return ((CK_FUNCTION_LIST_3_2_PTR)map.funcs)->C_DecryptMessageBegin (session,
                                                                             pParameter,
                                                                             ulParameterLen,
                                                                             associated_data,
                                                                             associated_data_len);
}
    
static CK_RV
proxy_C_DecryptMessageNext (CK_X_FUNCTION_LIST *self,
                            CK_SESSION_HANDLE session,
                            CK_VOID_PTR pParameter,
                            long unsigned int ulParameterLen,
                            unsigned char * ciphertext_part,
                            long unsigned int ciphertext_part_len,
                            unsigned char * plaintext_part,
                            long unsigned int * plaintext_part_len,
                            CK_FLAGS flags)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return ((CK_FUNCTION_LIST_3_2_PTR)map.funcs)->C_DecryptMessageNext (session,
                                                                            pParameter,
                                                                            ulParameterLen,
                                                                            ciphertext_part,
                                                                            ciphertext_part_len,
                                                                            plaintext_part,
                                                                            plaintext_part_len,
                                                                            flags);
}
    
static CK_RV
proxy_C_MessageDecryptFinal (CK_X_FUNCTION_LIST *self,
                             CK_SESSION_HANDLE session)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return ((CK_FUNCTION_LIST_3_2_PTR)map.funcs)->C_MessageDecryptFinal (session);
}
    
static CK_RV
proxy_C_MessageSignInit (CK_X_FUNCTION_LIST *self,
                         CK_SESSION_HANDLE session,
                         CK_MECHANISM_PTR mechanism,
                         CK_OBJECT_HANDLE hKey)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return ((CK_FUNCTION_LIST_3_2_PTR)map.funcs)->C_MessageSignInit (session,
                                                                         mechanism,
                                                                         hKey);
}
    
static CK_RV
proxy_C_SignMessage (CK_X_FUNCTION_LIST *self,
                     CK_SESSION_HANDLE session,
                     CK_VOID_PTR pParameter,
                     long unsigned int ulParameterLen,
                     unsigned char * data,
                     long unsigned int ulDataLen,
                     unsigned char * signature,
                     long unsigned int * signature_len)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return ((CK_FUNCTION_LIST_3_2_PTR)map.funcs)->C_SignMessage (session,
                                                                     pParameter,
                                                                     ulParameterLen,
                                                                     data,
                                                                     ulDataLen,
                                                                     signature,
                                                                     signature_len);
}
    
static CK_RV
proxy_C_SignMessageBegin (CK_X_FUNCTION_LIST *self,
                          CK_SESSION_HANDLE session,
                          CK_VOID_PTR pParameter,
                          long unsigned int ulParameterLen)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return ((CK_FUNCTION_LIST_3_2_PTR)map.funcs)->C_SignMessageBegin (session,
                                                                          pParameter,
                                                                          ulParameterLen);
}
    
static CK_RV
proxy_C_SignMessageNext (CK_X_FUNCTION_LIST *self,
                         CK_SESSION_HANDLE session,
                         CK_VOID_PTR pParameter,
                         long unsigned int ulParameterLen,
                         unsigned char * data,
                         long unsigned int ulDataLen,
                         unsigned char * signature,
                         long unsigned int * signature_len)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return ((CK_FUNCTION_LIST_3_2_PTR)map.funcs)->C_SignMessageNext (session,
                                                                         pParameter,
                                                                         ulParameterLen,
                                                                         data,
                                                                         ulDataLen,
                                                                         signature,
                                                                         signature_len);
}
    
static CK_RV
proxy_C_MessageSignFinal (CK_X_FUNCTION_LIST *self,
                          CK_SESSION_HANDLE session)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return ((CK_FUNCTION_LIST_3_2_PTR)map.funcs)->C_MessageSignFinal (session);
}
    
static CK_RV
proxy_C_MessageVerifyInit (CK_X_FUNCTION_LIST *self,
                           CK_SESSION_HANDLE session,
                           CK_MECHANISM_PTR mechanism,
                           CK_OBJECT_HANDLE hKey)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return ((CK_FUNCTION_LIST_3_2_PTR)map.funcs)->C_MessageVerifyInit (session,
                                                                           mechanism,
                                                                           hKey);
}
    
static CK_RV
proxy_C_VerifyMessage (CK_X_FUNCTION_LIST *self,
                       CK_SESSION_HANDLE session,
                       CK_VOID_PTR pParameter,
                       long unsigned int ulParameterLen,
                       unsigned char * data,
                       long unsigned int ulDataLen,
                       unsigned char * signature,
                       long unsigned int signature_len)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return ((CK_FUNCTION_LIST_3_2_PTR)map.funcs)->C_VerifyMessage (session,
                                                                       pParameter,
                                                                       ulParameterLen,
                                                                       data,
                                                                       ulDataLen,
                                                                       signature,
                                                                       signature_len);
}
    
static CK_RV
proxy_C_VerifyMessageBegin (CK_X_FUNCTION_LIST *self,
                            CK_SESSION_HANDLE session,
                            CK_VOID_PTR pParameter,
                            long unsigned int ulParameterLen)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return ((CK_FUNCTION_LIST_3_2_PTR)map.funcs)->C_VerifyMessageBegin (session,
                                                                            pParameter,
                                                                            ulParameterLen);
}
    
static CK_RV
proxy_C_VerifyMessageNext (CK_X_FUNCTION_LIST *self,
                           CK_SESSION_HANDLE session,
                           CK_VOID_PTR pParameter,
                           long unsigned int ulParameterLen,
                           unsigned char * data,
                           long unsigned int ulDataLen,
                           unsigned char * signature,
                           long unsigned int signature_len)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return ((CK_FUNCTION_LIST_3_2_PTR)map.funcs)->C_VerifyMessageNext (session,
                                                                           pParameter,
                                                                           ulParameterLen,
                                                                           data,
                                                                           ulDataLen,
                                                                           signature,
                                                                           signature_len);
}
    
static CK_RV
proxy_C_MessageVerifyFinal (CK_X_FUNCTION_LIST *self,
                            CK_SESSION_HANDLE session)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return ((CK_FUNCTION_LIST_3_2_PTR)map.funcs)->C_MessageVerifyFinal (session);
}
    
static CK_RV
proxy_C_EncapsulateKey (CK_X_FUNCTION_LIST *self,
                        CK_SESSION_HANDLE session,
                        CK_MECHANISM_PTR mechanism,
                        CK_OBJECT_HANDLE publicKey,
                        CK_ATTRIBUTE_PTR pTemplate,
                        long unsigned int ulAttributeCount,
                        unsigned char * ciphertext,
                        long unsigned int * ciphertext_len,
                        CK_OBJECT_HANDLE_PTR phKey)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return ((CK_FUNCTION_LIST_3_2_PTR)map.funcs)->C_EncapsulateKey (session,
                                                                        mechanism,
                                                                        publicKey,
                                                                        pTemplate,
                                                                        ulAttributeCount,
                                                                        ciphertext,
                                                                        ciphertext_len,
                                                                        phKey);
}
    
static CK_RV
proxy_C_DecapsulateKey (CK_X_FUNCTION_LIST *self,
                        CK_SESSION_HANDLE session,
                        CK_MECHANISM_PTR mechanism,
                        CK_OBJECT_HANDLE private_key,
                        CK_ATTRIBUTE_PTR pTemplate,
                        long unsigned int ulAttributeCount,
                        unsigned char * ciphertext,
                        long unsigned int * ciphertext_len,
                        CK_OBJECT_HANDLE_PTR phKey)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return ((CK_FUNCTION_LIST_3_2_PTR)map.funcs)->C_DecapsulateKey (session,
                                                                        mechanism,
                                                                        private_key,
                                                                        pTemplate,
                                                                        ulAttributeCount,
                                                                        ciphertext,
                                                                        ciphertext_len,
                                                                        phKey);
}
    
static CK_RV
proxy_C_VerifySignatureInit (CK_X_FUNCTION_LIST *self,
                             CK_SESSION_HANDLE session,
                             CK_MECHANISM_PTR mechanism,
                             CK_OBJECT_HANDLE hKey,
                             unsigned char * signature,
                             long unsigned int signature_len)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return ((CK_FUNCTION_LIST_3_2_PTR)map.funcs)->C_VerifySignatureInit (session,
                                                                             mechanism,
                                                                             hKey,
                                                                             signature,
                                                                             signature_len);
}
    
static CK_RV
proxy_C_VerifySignature (CK_X_FUNCTION_LIST *self,
                         CK_SESSION_HANDLE session,
                         unsigned char * data,
                         long unsigned int ulDataLen)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return ((CK_FUNCTION_LIST_3_2_PTR)map.funcs)->C_VerifySignature (session,
                                                                         data,
                                                                         ulDataLen);
}
    
static CK_RV
proxy_C_VerifySignatureUpdate (CK_X_FUNCTION_LIST *self,
                               CK_SESSION_HANDLE session,
                               unsigned char * part,
                               long unsigned int part_len)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return ((CK_FUNCTION_LIST_3_2_PTR)map.funcs)->C_VerifySignatureUpdate (session,
                                                                               part,
                                                                               part_len);
}
    
static CK_RV
proxy_C_VerifySignatureFinal (CK_X_FUNCTION_LIST *self,
                              CK_SESSION_HANDLE session)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return ((CK_FUNCTION_LIST_3_2_PTR)map.funcs)->C_VerifySignatureFinal (session);
}
    
static CK_RV
proxy_C_GetSessionValidationFlags (CK_X_FUNCTION_LIST *self,
                                   CK_SESSION_HANDLE session,
                                   CK_SESSION_VALIDATION_FLAGS_TYPE type,
                                   CK_FLAGS * flags_ptr)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return ((CK_FUNCTION_LIST_3_2_PTR)map.funcs)->C_GetSessionValidationFlags (session,
                                                                                   type,
                                                                                   flags_ptr);
}
    
static CK_RV
proxy_C_AsyncComplete (CK_X_FUNCTION_LIST *self,
                       CK_SESSION_HANDLE session,
                       unsigned char * function_name,
                       CK_ASYNC_DATA_PTR result)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return ((CK_FUNCTION_LIST_3_2_PTR)map.funcs)->C_AsyncComplete (session,
                                                                       function_name,
                                                                       result);
}
    
static CK_RV
proxy_C_AsyncGetID (CK_X_FUNCTION_LIST *self,
                    CK_SESSION_HANDLE session,
                    unsigned char * function_name,
                    long unsigned int * id_ptr)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return ((CK_FUNCTION_LIST_3_2_PTR)map.funcs)->C_AsyncGetID (session,
                                                                    function_name,
                                                                    id_ptr);
}
    
static CK_RV
proxy_C_AsyncJoin (CK_X_FUNCTION_LIST *self,
                   CK_SESSION_HANDLE session,
                   unsigned char * function_name,
                   long unsigned int id,
                   unsigned char * data,
                   long unsigned int ulDataLen)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return ((CK_FUNCTION_LIST_3_2_PTR)map.funcs)->C_AsyncJoin (session,
                                                                   function_name,
                                                                   id,
                                                                   data,
                                                                   ulDataLen);
}
    
static CK_RV
proxy_C_WrapKeyAuthenticated (CK_X_FUNCTION_LIST *self,
                              CK_SESSION_HANDLE session,
                              CK_MECHANISM_PTR mechanism,
                              CK_OBJECT_HANDLE wrapping_key,
                              CK_OBJECT_HANDLE hKey,
                              unsigned char * associated_data,
                              long unsigned int associated_data_len,
                              unsigned char * wrapped_key,
                              long unsigned int * wrapped_key_len)
{
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return ((CK_FUNCTION_LIST_3_2_PTR)map.funcs)->C_WrapKeyAuthenticated (session,
                                                                              mechanism,
                                                                              wrapping_key,
                                                                              hKey,
                                                                              associated_data,
                                                                              associated_data_len,
                                                                              wrapped_key,
                                                                              wrapped_key_len);
}
    
static CK_RV
proxy_C_UnwrapKeyAuthenticated (CK_X_FUNCTION_LIST *self,
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
        State *state = (State *)self;
        Mapping map;
        CK_RV rv;

        rv = map_session_to_real (state->px, &session, &map, NULL);
        if (rv != CKR_OK)
                return rv;
        if (map.funcs->version.major < 3)
                return CKR_FUNCTION_NOT_SUPPORTED;
        return ((CK_FUNCTION_LIST_3_2_PTR)map.funcs)->C_UnwrapKeyAuthenticated (session,
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
    

CK_X_FUNCTION_LIST proxy_functions = {
        { CRYPTOKI_VERSION_MAJOR, CRYPTOKI_VERSION_MINOR },  /* version */
        proxy_C_Initialize,
        proxy_C_Finalize,
        proxy_C_GetInfo,
        proxy_C_GetSlotList,
        proxy_C_GetSlotInfo,
        proxy_C_GetTokenInfo,
        proxy_C_GetMechanismList,
        proxy_C_GetMechanismInfo,
        proxy_C_InitToken,
        proxy_C_InitPIN,
        proxy_C_SetPIN,
        proxy_C_OpenSession,
        proxy_C_CloseSession,
        proxy_C_CloseAllSessions,
        proxy_C_GetSessionInfo,
        proxy_C_GetOperationState,
        proxy_C_SetOperationState,
        proxy_C_Login,
        proxy_C_Logout,
        proxy_C_CreateObject,
        proxy_C_CopyObject,
        proxy_C_DestroyObject,
        proxy_C_GetObjectSize,
        proxy_C_GetAttributeValue,
        proxy_C_SetAttributeValue,
        proxy_C_FindObjectsInit,
        proxy_C_FindObjects,
        proxy_C_FindObjectsFinal,
        proxy_C_EncryptInit,
        proxy_C_Encrypt,
        proxy_C_EncryptUpdate,
        proxy_C_EncryptFinal,
        proxy_C_DecryptInit,
        proxy_C_Decrypt,
        proxy_C_DecryptUpdate,
        proxy_C_DecryptFinal,
        proxy_C_DigestInit,
        proxy_C_Digest,
        proxy_C_DigestUpdate,
        proxy_C_DigestKey,
        proxy_C_DigestFinal,
        proxy_C_SignInit,
        proxy_C_Sign,
        proxy_C_SignUpdate,
        proxy_C_SignFinal,
        proxy_C_SignRecoverInit,
        proxy_C_SignRecover,
        proxy_C_VerifyInit,
        proxy_C_Verify,
        proxy_C_VerifyUpdate,
        proxy_C_VerifyFinal,
        proxy_C_VerifyRecoverInit,
        proxy_C_VerifyRecover,
        proxy_C_DigestEncryptUpdate,
        proxy_C_DecryptDigestUpdate,
        proxy_C_SignEncryptUpdate,
        proxy_C_DecryptVerifyUpdate,
        proxy_C_GenerateKey,
        proxy_C_GenerateKeyPair,
        proxy_C_WrapKey,
        proxy_C_UnwrapKey,
        proxy_C_DeriveKey,
        proxy_C_SeedRandom,
        proxy_C_GenerateRandom,
        proxy_C_WaitForSlotEvent,
        proxy_C_LoginUser,
        proxy_C_SessionCancel,
        proxy_C_MessageEncryptInit,
        proxy_C_EncryptMessage,
        proxy_C_EncryptMessageBegin,
        proxy_C_EncryptMessageNext,
        proxy_C_MessageEncryptFinal,
        proxy_C_MessageDecryptInit,
        proxy_C_DecryptMessage,
        proxy_C_DecryptMessageBegin,
        proxy_C_DecryptMessageNext,
        proxy_C_MessageDecryptFinal,
        proxy_C_MessageSignInit,
        proxy_C_SignMessage,
        proxy_C_SignMessageBegin,
        proxy_C_SignMessageNext,
        proxy_C_MessageSignFinal,
        proxy_C_MessageVerifyInit,
        proxy_C_VerifyMessage,
        proxy_C_VerifyMessageBegin,
        proxy_C_VerifyMessageNext,
        proxy_C_MessageVerifyFinal,
        proxy_C_EncapsulateKey,
        proxy_C_DecapsulateKey,
        proxy_C_VerifySignatureInit,
        proxy_C_VerifySignature,
        proxy_C_VerifySignatureUpdate,
        proxy_C_VerifySignatureFinal,
        proxy_C_GetSessionValidationFlags,
        proxy_C_AsyncComplete,
        proxy_C_AsyncGetID,
        proxy_C_AsyncJoin,
        proxy_C_WrapKeyAuthenticated,
        proxy_C_UnwrapKeyAuthenticated
};
