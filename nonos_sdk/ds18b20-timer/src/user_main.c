/*
 * ESP-01 PlatformIO / nonOS SDK
 * project DS18B20 & os_timer
 * read temperature from DS18B20 connected to GPIO2
 * file src/user_main.c
 */
#include <ets_sys.h>
#include <osapi.h>
#include "user_interface.h"
#include <os_type.h>
#include <gpio.h>

#include "ds18b20.h"

LOCAL os_timer_t convertor_timer;
LOCAL os_timer_t reader_timer;
uint8_t addr[] = {0x28, 0xA1, 0xBD, 0x53, 0x03, 0x00, 0x00, 0x62};
uint8_t data[2];

LOCAL void ICACHE_FLASH_ATTR giveTemperature(int raw)
{
  int whole = raw >> 4;  // separate off the whole and fractional portions
  int fract = (raw & 0xf) * 100 / 16;
  os_printf("Temperature: %d.%s%d\r\n", whole, (fract < 10 ? "0" : ""), fract);
}

LOCAL void ICACHE_FLASH_ATTR readScratchpad_cb(void *arg)
{
  ds_reset();
  ds_select(addr);    
  ds_write(0xBE, 0);          
  data[0] = ds_read();
  data[1] = ds_read();
  giveTemperature((data[1] << 8) | data[0]);
}

LOCAL void ICACHE_FLASH_ATTR startConversion_cb(void *arg)
{
  ds_reset();            
  ds_select(addr);        
  ds_write(0x44, 0);      

  os_timer_disarm(&reader_timer);
  os_timer_setfn(&reader_timer, (os_timer_func_t *)readScratchpad_cb, (void *)0);
  os_timer_arm(&reader_timer, 1000, false);
}

uint32 ICACHE_FLASH_ATTR
user_rf_cal_sector_set(void)
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
  uart_init(115200, 115200);
  PIN_FUNC_SELECT(DS18B20_MUX,  DS18B20_FUNC);
  PIN_PULLUP_EN(DS18B20_MUX);
  GPIO_DIS_OUTPUT(DS18B20_PIN);
  os_printf("SDK version:%s\n", system_get_sdk_version());
  os_timer_disarm(&convertor_timer);
  os_timer_setfn(&convertor_timer, (os_timer_func_t *)startConversion_cb, (void *)0);
  os_timer_arm(&convertor_timer, 10000, true);
}
