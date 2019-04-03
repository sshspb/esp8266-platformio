/*
 * ESP-01 / PlatformIO / RTOS SDK
 * project Blinking LED example
 * file src/user_main.c
 */
#include "esp_common.h"
#include "gpio.h"

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

void LEDBlinkTask (void *pvParameters)
{
  while(1)
  {
    // Delay and turn on
    vTaskDelay (1000/portTICK_RATE_MS);
    GPIO_OUTPUT_SET (2, 1);
    // Delay and LED off
    vTaskDelay (1000/portTICK_RATE_MS);
    GPIO_OUTPUT_SET (2, 0);
  }
}
 
void user_init(void)
{
  // Config LED pin as GPIO2
  PIN_FUNC_SELECT(PERIPHS_IO_MUX_GPIO2_U, FUNC_GPIO2);
  // This task blinks the LED continuously
  xTaskCreate(LEDBlinkTask, (signed char *)"Blink", 256, NULL, 2, NULL);
}

/********
Uploading  34032 bytes from eagle.flash.bin           to flash at 0x00000000
Uploading 244674 bytes from eagle.irom0text.bin       to flash at 0x00020000
Uploading    128 bytes from esp_init_data_default.bin to flash at 0x000FC000
Uploading   4096 bytes from blank.bin                 to flash at 0x000FE000
 */