/*
 * ESP-01 PlatformIO/Arduino SDK
 * with Ticker read temperature from DS18B20 chip connected to GPIO2
 * file src/main.c
 */
#include <Arduino.h>
#include <OneWire.h>
#include <Ticker.h>

uint8_t addr[] = {0x28, 0xA1, 0xBD, 0x53, 0x03, 0x00, 0x00, 0x62};
uint8_t data[2];
OneWire ds(2);
Ticker convertor;
Ticker reader;

void readScratchpad() {
  ds.reset();
  ds.select(addr);    
  ds.write(0xBE);          
  data[0] = ds.read();
  data[1] = ds.read();
  int raw = (data[1] << 8) | data[0]; 
  Serial.print("temp = ");
  Serial.println(raw / 16.0);
}

void startConversion() {
  ds.reset();            
  ds.select(addr);        
  ds.write(0x44);      
  reader.once(1, readScratchpad);
}

void setup() {
  Serial.begin(115200);
  delay(10);
  Serial.println("hello from ESP8266 & ds18b20");
  // startConversion every 10s
  convertor.attach(10, startConversion);
}

void loop() {
}