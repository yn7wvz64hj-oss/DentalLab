#include "CryptoSupport.h"
#include <CommonCrypto/CommonKeyDerivation.h>
int dl_derive(const char *password, size_t length, const uint8_t *salt, size_t saltLength, uint8_t *key) {
    return CCKeyDerivationPBKDF(kCCPBKDF2, password, length, salt, saltLength, kCCPRFHmacAlgSHA256, 310000, key, 32);
}
