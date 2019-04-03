/*
 * ESP-01 PlatformIO / nonOS SDK
 * file src/user_main.c
 * with dweet.io read temperature from DS18B20 connected to GPIO2
 */
#include "ets_sys.h"
#include "osapi.h"
#include "gpio.h"
#include "os_type.h"
#include "ip_addr.h"
#include "espconn.h"
#include "user_config.h"
#include "user_interface.h"

#include "ds18b20.h"

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

void ICACHE_FLASH_ATTR data_received( void *arg, char *pdata, unsigned short len )
{
    struct espconn *conn = arg;
    os_printf( "SHS %s: %s\n", __FUNCTION__, pdata );
    espconn_disconnect( conn );
}

void ICACHE_FLASH_ATTR tcp_connected( void *arg )
{
  struct espconn *conn = arg;
    
  os_printf( "SHS %s\n", __FUNCTION__ );
  espconn_regist_recvcb( conn, data_received );

  int whole = raw >> 4;  // separate off the whole and fractional portions
  int fract = (raw & 0xf) * 100 / 16;
  os_sprintf( json_data, "{\"temperature\": \"%d.%s%d\" }", whole, (fract < 10 ? "0" : ""), fract);
  os_sprintf( buffer, "POST %s HTTP/1.1\r\nHost: %s\r\nConnection: close\r\nContent-Type: application/json\r\nContent-Length: %d\r\n\r\n%s", 
                         dweet_path, dweet_host, os_strlen( json_data ), json_data );
    
  os_printf( "SHS Sending: %s\n", buffer );
  espconn_sent( conn, buffer, os_strlen( buffer ) );
}

void ICACHE_FLASH_ATTR tcp_disconnected( void *arg )
{
    struct espconn *conn = arg;
    os_printf( "SHS %s\n", __FUNCTION__ );
    wifi_station_disconnect();
}

void ICACHE_FLASH_ATTR dns_done( const char *name, ip_addr_t *ipaddr, void *arg )
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
        os_memcpy( conn->proto.tcp->remote_ip, &ipaddr->addr, 4 );

        espconn_regist_connectcb( conn, tcp_connected );
        espconn_regist_disconcb( conn, tcp_disconnected );
        
        espconn_connect( conn );
    }
}

void ICACHE_FLASH_ATTR wifi_callback( System_Event_t *evt )
{
    os_printf( "SHS %s: %d\n", __FUNCTION__, evt->event );
    
    switch ( evt->event )
    {
        case EVENT_STAMODE_CONNECTED:
        {
            os_printf("SHS connect to ssid %s, channel %d\n",
                        evt->event_info.connected.ssid,
                        evt->event_info.connected.channel);
            break;
        }

        case EVENT_STAMODE_DISCONNECTED:
        {
            os_printf("SHS disconnect from ssid %s, reason %d\n",
                        evt->event_info.disconnected.ssid,
                        evt->event_info.disconnected.reason);
            
            deep_sleep_set_option( 0 );
            system_deep_sleep( 60 * 1000 * 1000 );  // 60 seconds
            break;
        }

        case EVENT_STAMODE_GOT_IP:
        {
            os_printf("SHS ip:" IPSTR ",mask:" IPSTR ",gw:" IPSTR,
                        IP2STR(&evt->event_info.got_ip.ip),
                        IP2STR(&evt->event_info.got_ip.mask),
                        IP2STR(&evt->event_info.got_ip.gw));
            os_printf("\n");
            
            espconn_gethostbyname( &dweet_conn, dweet_host, &dweet_ip, dns_done );
            break;
        }
        
        default:
        {
            break;
        }
    }
}

void ICACHE_FLASH_ATTR readScratchpad_cb(void *arg)
{
  os_printf( "SHS readScratchpad_cb begin\n");
  ds_reset();
  ds_select(addr);    
  ds_write(0xBE, 0);          
  data[0] = ds_read();
  data[1] = ds_read();
  
  raw = ((data[1] << 8) | data[0]);
  os_printf( "SHS raw = %d\n", raw);

  wifi_station_set_hostname( "dweet" );
  wifi_set_opmode_current( STATION_MODE );

  static struct station_config config;
  config.bssid_set = 0;
  os_memcpy( &config.ssid, SH_SSID, 32 );
  os_memcpy( &config.password, SH_SSID_PASSWORD, 64 );
  wifi_station_set_config( &config );
    
  wifi_set_event_handler_cb( wifi_callback );

  wifi_station_connect();

  os_printf( "SHS readScratchpad_cb end\n");
}

void ICACHE_FLASH_ATTR startConversion_cb(void *arg)
{
  os_printf( "SHS startConversion_cb\n");

  ds_reset();            
  ds_select(addr);        
  ds_write(0x44, 0);      

  os_timer_disarm(&reader_timer);
  os_timer_setfn(&reader_timer, (os_timer_func_t *)readScratchpad_cb, (void *)0);
  os_timer_arm(&reader_timer, 1000, false);
}

void ICACHE_FLASH_ATTR user_init(void)
{
  //uart_init(115200, 115200);
  uart_div_modify( 0, UART_CLK_FREQ / ( 115200 ) );
  os_printf( "\nSHS\n");
  os_printf( "SHS start user_init, %s\n", __FUNCTION__ );
  os_printf("SHS SDK version:%s\n", system_get_sdk_version());
  
  PIN_FUNC_SELECT(DS18B20_MUX,  DS18B20_FUNC);
  PIN_PULLUP_EN(DS18B20_MUX);
  GPIO_DIS_OUTPUT(DS18B20_PIN);
  
  os_timer_disarm(&convertor_timer);
  os_timer_setfn(&convertor_timer, (os_timer_func_t *)startConversion_cb, (void *)0);
  os_timer_arm(&convertor_timer, 1000, false);
}

/*
========
Uploading  27072 bytes from eagle.flash.bin           to flash at 0x00000000
Uploading 198308 bytes from eagle.irom0text.bin       to flash at 0x00010000
Uploading    128 bytes from esp_init_data_default.bin to flash at 0x000FC000
Uploading   4096 bytes from blank.bin                 to flash at 0x000FE000
========
SHS
SHS start user_init, user_init
SHS SDK version:2.1.0(7106d38)
mode : softAP(86:f3:eb:7f:db:1e)
add if1
dhcp server start:(ip:192.168.4.1,mask:255.255.255.0,gw:192.168.4.1)
bcn 100
SHS startConversion_cb
SHS readScratchpad_cb begin
SHS raw = 402
bcn 0
del if1
usl
mode : sta(84:f3:eb:7f:db:1e)
add if0
SHS readScratchpad_cb end
SHS wifi_callback: 2
scandone
state: 0 -> 2 (b0)
state: 2 -> 3 (0)
state: 3 -> 5 (10)
add 0
aid 1
cnt 

connected with NorthSide, channel 8
dhcp client start...
SHS wifi_callback: 0
SHS connect to ssid NorthSide, channel 8
ip:192.168.0.100,mask:255.255.255.0,gw:192.168.0.1
SHS wifi_callback: 3
SHS ip:192.168.0.100,mask:255.255.255.0,gw:192.168.0.1
SHS dns_done
SHS Connecting...
SHS tcp_connected
SHS Sending: POST /dweet/for/shs-grus HTTP/1.1
Host: dweet.io
Connection: close
Content-Type: application/json
Content-Length: 25

{"temperature": "25.12" }
SHS data_received: HTTP/1.1 200 OK
Access-Control-Allow-Origin: *
Content-Type: application/json
Content-Length: 200
Date: Mon, 01 Apr 2019 10:29:42 GMT
Connection: close

{"this":"succeeded","by":"dweeting","the":"dweet","with":{"thing":"shs-grus","created":"2019-04-01T10:29:42.534Z","content":{"temperature":25.12},"transaction":"25e3833c-54dc-48ee-b6bf-8746d45589ab"}}
SHS tcp_disconnected
state: 5 -> 0 (0)
rm 0
SHS wifi_callback: 1
SHS disconnect from ssid NorthSide, reason 8
del if0
usl
enter deep sleep
юбsl
*/