/*
 * ESP-01 PlatformIO / RTOS SDK
 * project DS18B20 dweet
 * file src/user_main.c
 * with dweet.io read temperature 
 * from DS18B20 connected to GPIO2
 */
#include "esp_common.h"
#include "espconn.h"
#include "uart.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/queue.h"
#include "ds18b20.h"
#include "user_config.h"

os_timer_t convertor_timer;
os_timer_t reader_timer;

struct espconn dweet_conn;
ip_addr_t dweet_ip;
esp_tcp dweet_tcp;
char dweet_host[] = "dweet.io";
char dweet_path[] = "/dweet/for/shs-grus";
char json_data[ 256 ];
char buffer[ 2048 ];

uint8_t addr[] = {0x28, 0xA1, 0xBD, 0x53, 0x03, 0x00, 0x00, 0x62};
uint8_t data[2];
int raw = 0;

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

void data_received( void *arg, char *pdata, unsigned short len )
{
    struct espconn *conn = arg;
    os_printf( "SHS %s: %s\n", __FUNCTION__, pdata );
    espconn_disconnect( conn );
}

void tcp_connected( void *arg )
{
  struct espconn *conn = arg;
    
  os_printf( "SHS %s\n", __FUNCTION__ );
  espconn_regist_recvcb( conn, data_received );

  int whole = raw >> 4;  // separate off the whole and fractional portions
  int fract = (raw & 0xf) * 100 / 16;
  sprintf( json_data, "{\"temperature\": \"%d.%s%d\" }", whole, (fract < 10 ? "0" : ""), fract);
  sprintf( buffer, "POST %s HTTP/1.1\r\nHost: %s\r\nConnection: close\r\nContent-Type: application/json\r\nContent-Length: %d\r\n\r\n%s", 
                         dweet_path, dweet_host, strlen( json_data ), json_data );
    
  os_printf( "SHS Sending: %s\n", buffer );
  espconn_sent( conn, buffer, strlen( buffer ) );
}

void tcp_disconnected( void *arg )
{
    struct espconn *conn = arg;
    os_printf( "SHS %s\n", __FUNCTION__ );
    wifi_station_disconnect();
}

void dns_done( const char *name, ip_addr_t *ipaddr, void *arg )
{
    struct espconn *conn = arg;
    
    os_printf( "SHS %s\n", __FUNCTION__ );
    
    if ( ipaddr == NULL) 
    {
        os_printf("SHS DNS lookup failed\n");
        wifi_station_disconnect();
    }
    else
    {
        os_printf("SHS Connecting...\n" );
        
        conn->type = ESPCONN_TCP;
        conn->state = ESPCONN_NONE;
        conn->proto.tcp=&dweet_tcp;
        conn->proto.tcp->local_port = espconn_port();
        conn->proto.tcp->remote_port = 80;
        memcpy( conn->proto.tcp->remote_ip, &ipaddr->addr, 4 );

        espconn_regist_connectcb( conn, tcp_connected );
        espconn_regist_disconcb( conn, tcp_disconnected );
        
        espconn_connect( conn );
    }
}

void wifi_callback( System_Event_t *evt )
{
    os_printf( "SHS %s: %d\n", __FUNCTION__, evt->event_id );
    switch ( evt->event_id )
    {
        case EVENT_STAMODE_CONNECTED:  // evt->event_id  == 1
            os_printf("SHS connect to ssid %s, channel %d\n",
                        evt->event_info.connected.ssid,
                        evt->event_info.connected.channel);
            break;
        case EVENT_STAMODE_DISCONNECTED:  // evt->event_id  == 2
            os_printf("SHS disconnect from ssid %s, reason %d\n",
                        evt->event_info.disconnected.ssid,
                        evt->event_info.disconnected.reason);
            deep_sleep_set_option( 0 );
            system_deep_sleep( 60 * 1000 * 1000 );  // 60 seconds
            break;
        case EVENT_STAMODE_GOT_IP:  // evt->event_id  == 4
            os_printf("SHS ip:" IPSTR ",mask:" IPSTR ",gw:" IPSTR,
                        IP2STR(&evt->event_info.got_ip.ip),
                        IP2STR(&evt->event_info.got_ip.mask),
                        IP2STR(&evt->event_info.got_ip.gw));
            os_printf("\n");
            espconn_gethostbyname( &dweet_conn, dweet_host, &dweet_ip, dns_done );
            break;
        default:
            break;
    }
}

void readScratchpad_cb(void *arg)
{
  os_printf( "SHS readScratchpad_cb begin\n");
  ds_reset();
  ds_select(addr);    
  ds_write(0xBE, 0);          
  data[0] = ds_read();
  data[1] = ds_read();
  raw = ((data[1] << 8) | data[0]);
  os_printf( "SHS raw = %d\n", raw);
  wifi_station_connect();
  os_printf( "SHS readScratchpad_cb end\n");
}

void startConversion_cb(void *arg)
{
  os_printf( "SHS startConversion_cb\n");
  ds_reset();            
  ds_select(addr);        
  ds_write(0x44, 0);      
  os_timer_disarm(&reader_timer);
  os_timer_setfn(&reader_timer, (os_timer_func_t *)readScratchpad_cb, (void *)0);
  os_timer_arm(&reader_timer, 1000, false);
}

void sensorTask (void *pvParameters)
{
  printf("SHS Hello, welcome to sensorTask!\n");
  wifi_station_set_hostname( "dweet" );
  wifi_set_opmode(STATION_MODE);
  //wifi_set_opmode_current( STATION_MODE );
/*
  static struct station_config config;
  config.bssid_set = 0;
  memcpy( &config.ssid, SH_SSID, 32 );
  memcpy( &config.password, SH_SSID_PASSWORD, 64 );
  wifi_station_set_config( &config );
*/
  struct station_config * config = (struct station_config *)zalloc(sizeof(struct station_config));
  sprintf(config->ssid, SH_SSID);
  sprintf(config->password, SH_SSID_PASSWORD);
  wifi_station_set_config(config);
  free(config);
  wifi_set_event_handler_cb( wifi_callback );
  os_timer_disarm(&convertor_timer);
  os_timer_setfn(&convertor_timer, (os_timer_func_t *)startConversion_cb, (void *)0);
  os_timer_arm(&convertor_timer, 10000, false);
  while(1)
  {
    vTaskDelay (10);
  }
}
 
void user_init(void)
{
  //uart_init(115200, 115200);
  //uart_div_modify( 0, UART_CLK_FREQ / ( 115200 ) );
  UART_SetBaudrate(0, 115200);
  ds_init();
  printf("SDK version:%s\n", system_get_sdk_version());
  xTaskCreate(sensorTask, "Sensor", 256, NULL, 2, NULL);
}
