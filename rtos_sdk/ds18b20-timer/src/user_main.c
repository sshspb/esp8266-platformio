/*
 * ESP-01 / PlatformIO / RTOS SDK
 * project DS18B20 timer
 * read temperature from DS18B20 connected to GPIO2
 * file src/user_main.c
 */
#include "esp_common.h"
#include "espconn.h"
#include "uart.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/queue.h"

#include "ds18b20.h"

os_timer_t convertor_timer;
os_timer_t reader_timer;
uint8_t addr[] = {0x28, 0xA1, 0xBD, 0x53, 0x03, 0x00, 0x00, 0x62};
uint8_t data[2];

uint32 user_rf_cal_sector_set(void)
{
    flash_size_map size_map = system_get_flash_size_map();
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
        default:
            rf_cal_sec = 0;
            break;
    }
    return rf_cal_sec;
}

void giveTemperature(int raw)
{
  int whole = raw >> 4;  // separate off the whole and fractional portions
  int fract = (raw & 0xf) * 100 / 16;
  os_printf("Temperature: %d.%s%d\n", whole, (fract < 10 ? "0" : ""), fract);
}

void readScratchpad_cb(void *arg)
{
  ds_reset();
  ds_select(addr);    
  ds_write(0xBE, 0);          
  data[0] = ds_read();
  data[1] = ds_read();
  giveTemperature((data[1] << 8) | data[0]);
}

void startConversion_cb(void *arg)
{
  ds_reset();            
  ds_select(addr);        
  ds_write(0x44, 0);      
  os_timer_disarm(&reader_timer);
  os_timer_setfn(&reader_timer, (os_timer_func_t *)readScratchpad_cb, (void *)0);
  os_timer_arm(&reader_timer, 1000, false);
}

void sensorTask (void *pvParameters)
{
  printf("Hello, welcome to sensorTask!\n");
  os_timer_disarm(&convertor_timer);
  os_timer_setfn(&convertor_timer, (os_timer_func_t *)startConversion_cb, (void *)0);
  os_timer_arm(&convertor_timer, 10000, true);
  while(1)
  {
    vTaskDelay (10);
  }
}
 
void user_init(void)
{
  //uart_init(115200, 115200);
  UART_SetBaudrate(0, 115200);
  ds_init();
  printf("SDK version:%s\n", system_get_sdk_version());
  xTaskCreate(sensorTask, "Sensor", 256, NULL, 2, NULL);
}

/********
Uploading  34096 bytes from eagle.flash.bin           to flash at 0x00000000
Uploading 246054 bytes from eagle.irom0text.bin       to flash at 0x00020000
Uploading    128 bytes from esp_init_data_default.bin to flash at 0x000FC000
Uploading   4096 bytes from blank.bin                 to flash at 0x000FE000
*/
