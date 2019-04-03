#include "ets_sys.h"
#include "osapi.h"
#include "user_interface.h"
#include "gpio.h"

LOCAL os_timer_t led_timer;
LOCAL bool led;

void ICACHE_FLASH_ATTR setLED()
{
  if (led) {
    led = false;
    GPIO_OUTPUT_SET (2, 0);
  } else {
    led = true;
    GPIO_OUTPUT_SET (2, 1);
  }
}

LOCAL void ICACHE_FLASH_ATTR led_timer_cb(void *arg)
{
  setLED();
}

uint32 ICACHE_FLASH_ATTR user_rf_cal_sector_set(void)
{
  enum flash_size_map size_map = system_get_flash_size_map();
  uint32 rf_cal_sec = 0;
  switch (size_map) {
    case FLASH_SIZE_4M_MAP_256_256:
      rf_cal_sec = 128 - 5;
      break;
    case FLASH_SIZE_8M_MAP_512_512:
      rf_cal_sec = 256 - 5;
      break;
    case FLASH_SIZE_16M_MAP_512_512:
    case FLASH_SIZE_16M_MAP_1024_1024:
      rf_cal_sec = 512 - 5;
      break;
    case FLASH_SIZE_32M_MAP_512_512:
    case FLASH_SIZE_32M_MAP_1024_1024:
      rf_cal_sec = 1024 - 5;
      break;
    case FLASH_SIZE_64M_MAP_1024_1024:
      rf_cal_sec = 2048 - 5;
      break;
    case FLASH_SIZE_128M_MAP_1024_1024:
      rf_cal_sec = 4096 - 5;
      break;
    default:
      rf_cal_sec = 0;
      break;
  }
  return rf_cal_sec;
}

void ICACHE_FLASH_ATTR user_rf_pre_init(void)
{
}

void ICACHE_FLASH_ATTR user_init(void)
{
//  uart_init(BIT_RATE_115200, BIT_RATE_115200);
  PIN_FUNC_SELECT(PERIPHS_IO_MUX_GPIO2_U,  FUNC_GPIO2);
  led = false;
  GPIO_OUTPUT_SET (2, 0);
  os_timer_disarm(&led_timer);
  os_timer_setfn(&led_timer, (os_timer_func_t *)led_timer_cb, (void *)0);
  os_timer_arm(&led_timer, 1000, true);
}

