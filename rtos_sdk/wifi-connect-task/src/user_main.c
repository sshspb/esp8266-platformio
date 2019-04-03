/*
 * ESP-01 / PlatformIO / RTOS SDK
 * project wifi connect task
 * file src/user_main.c
 */
#include "esp_common.h"
#include "espconn.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/queue.h"

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

void task3(void *pvParameters)
{
  printf("Hello, welcome to task3!\r\n");
  vTaskDelete(NULL);
}

void task2(void *pvParameters)
{
  printf("Hello, welcome to task2!\r\n");
  vTaskDelete(NULL);
}

void user_init(void)
{
  printf("test new compile..\n");
  printf("SDK version:%s\n", system_get_sdk_version());

  wifi_set_opmode(STATION_MODE);

  struct station_config * config = (struct station_config *)zalloc(sizeof(struct station_config));
  sprintf(config->ssid,"NorthSide");
  sprintf(config->password, "password");
  wifi_station_set_config(config);
  free(config);
  wifi_station_connect();

  xTaskCreate(task2, "tsk2", 256, NULL, 2, NULL);
  xTaskCreate(task3, "tsk3", 256, NULL, 2, NULL);
}
/*
==============================
Uploading  34144 bytes from eagle.flash.bin           to flash at 0x00000000
Uploading 244750 bytes from eagle.irom0text.bin       to flash at 0x00020000
Uploading    128 bytes from esp_init_data_default.bin to flash at 0x000FC000
Uploading   4096 bytes from blank.bin                 to flash at 0x000FE000
==============================
SDK version:1.5.0-dev(caff253)
mode : sta(84:f3:eb:7f:db:1e)
Hello,  welcome to      task2!
Hello,  welcome to      task3!
connected with NorthSide, channel 6
dhcp client start...
ip:192.168.0.101,mask:255.255.255.0,gw:192.168.0.1
*/