#ifndef CYW43_DEFINED_H_
#define CYW43_DEFINED_H_

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

int CYW43_arch_init_with_country(const uint8_t *);
void CYW43_arch_enable_sta_mode(void);
void CYW43_arch_disable_sta_mode(void);
int CYW43_arch_wifi_connect_blocking(const char *ssid, const char *pw, uint32_t auth);
void CYW43_GPIO_write(uint8_t, uint8_t);
uint8_t CYW43_GPIO_read(uint8_t pin);

#ifdef __cplusplus
}
#endif

#endif /* CYW43_DEFINED_H_ */

