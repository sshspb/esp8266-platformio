/*
 * ESP-01 PlatformIO/Arduino SDK
 * DS18B20 & web server
 * file src/main.c
 * read temperature from DS18B20 chip connected to GPIO2
 * and send it by http server on request http://192.168.0.100/
 */
#include <Arduino.h>
#include <ESP8266WiFi.h>
#include <WiFiClient.h>
#include <ESP8266WebServer.h>
#include <ESP8266mDNS.h>
#include <OneWire.h>
#include <Ticker.h>

ESP8266WebServer server(80);
Ticker convertor;
Ticker reader;
OneWire  ds(2);

const char* ssid     = "ssid";
const char* password = "password";
uint8_t addr[] = {0x28, 0xA1, 0xBD, 0x53, 0x03, 0x00, 0x00, 0x62};
uint8_t data[2];
int raw = 0;

void handleRoot() {
  digitalWrite(LED_BUILTIN, HIGH);
  // char *dtostrf(double val, signed char width, unsigned char prec, char *s)
  // 4 is mininum width, 2 is precision; float value is copied onto str_temp  
  char str_temp[8];
  char str_message[256];
  dtostrf((double)(raw/16.0), 4, 2, str_temp);
  sprintf(str_message,"hello from esp8266! temperature = %s C", str_temp);
  server.send(200, "text/plain", str_message);
  //digitalWrite(led, 0);
  digitalWrite(LED_BUILTIN, LOW);
}

void handleNotFound(){
  digitalWrite(LED_BUILTIN, HIGH);
  String message = "File Not Found\n\n";
  message += "URI: ";
  message += server.uri();
  message += "\nMethod: ";
  message += (server.method() == HTTP_GET)?"GET":"POST";
  message += "\nArguments: ";
  message += server.args();
  message += "\n";
  for (uint8_t i=0; i < server.args(); i++){
    message += " " + server.argName(i) + ": " + server.arg(i) + "\n";
  }
  server.send(404, "text/plain", message);
  digitalWrite(LED_BUILTIN, LOW);
}

void readScratchpad() {
  ds.reset();
  ds.select(addr);    
  ds.write(0xBE);          
  data[0] = ds.read();
  data[1] = ds.read();
  raw = (data[1] << 8) | data[0]; 
  Serial.println();
  Serial.print("Temperature = ");
  Serial.println(raw / 16.0);
}

void startConversion() {
  ds.reset();            
  ds.select(addr);        
  ds.write(0x44);      
  reader.once(1, readScratchpad);
}

void setup(void){
  pinMode(LED_BUILTIN, OUTPUT);
  digitalWrite(LED_BUILTIN, LOW);
  Serial.begin(115200);
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);
  Serial.println("");

  // Wait for connection
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("");
  Serial.print("Connected to ");
  Serial.println(ssid);
  Serial.print("IP address: ");
  Serial.println(WiFi.localIP());

  if (MDNS.begin("esp8266")) {
    Serial.println("MDNS responder started");
  }

  server.on("/", handleRoot);

  server.on("/inline", [](){
    server.send(200, "text/plain", "this works as well");
  });

  server.onNotFound(handleNotFound);

  server.begin();
  Serial.println("HTTP server started");
  // startConversion every 10s
  convertor.attach(10, startConversion);
}

void loop(void){
  server.handleClient();
}

/*
======================
DATA:    [===       ]  34.6% (used 28384 bytes from 81920 bytes)
PROGRAM: [====      ]  41.3% (used 315000 bytes from 761840 bytes)
Uploading 319152 bytes from .pioenvs\esp01_1m\firmware.bin to flash at 0x00000000
======================
$ ssh puma
Welcome to FreeBSD!
$ echo -n "GET / HTTP/1.1\r\n\r\n" | nc 192.168.0.100 80
HTTP/1.1 200 OK
Content-Type: text/plain
Content-Length: 41
Connection: close

hello from esp8266! temperature = 25.19 C
*/
