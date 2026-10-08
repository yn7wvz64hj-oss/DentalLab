#include <stddef.h>
#include <stdint.h>
int dl_derive(const char *password, size_t length, const uint8_t *salt, size_t saltLength, uint8_t *key);
