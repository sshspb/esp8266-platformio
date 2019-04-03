/*
 * ESP-01 / PlatformIO / Arduino SDK
 * project DS18B20 & web server auto refresh
 * file src/main.c
 * Read temperature from DS18B20 connected to GPIO2
 * and create webpage with auto refresh every 5 sec
 * Check ip address ESP8266 Module with Serial monitor
 * and open your Internet browser by its ip address 
 */
#include <ESP8266WiFi.h>
#include <OneWire.h>

const char* ssid     = "ssid"; // Your ssid
const char* password = "password"; // Your Password

OneWire  ds(2);  // on pin 2 (a 4.7K resistor is necessary)
WiFiServer server(80);

void setup() {
Serial.begin(115200);
delay(10);

// Connect to WiFi network
Serial.println();
Serial.println();
Serial.print("Connecting to ");
Serial.println(ssid);

WiFi.begin(ssid, password);

while (WiFi.status() != WL_CONNECTED) {
delay(500);
Serial.print(".");
}
Serial.println("");
Serial.println("WiFi connected");

// Start the server
server.begin();
Serial.println("Server started");

// Print the IP address
Serial.println(WiFi.localIP());
}

void loop() {

byte i;
byte present = 0;
byte type_s;
byte data[12];
byte addr[8];
float celsius, fahrenheit;

if ( !ds.search(addr)) {
Serial.println("No more addresses.");
Serial.println();
ds.reset_search();
delay(250);
return;
}

Serial.print("ROM =");
for ( i = 0; i < 8; i++) {
Serial.write(' ');
Serial.print(addr[i], HEX);
}

if (OneWire::crc8(addr, 7) != addr[7]) {
Serial.println("CRC is not valid!");
return;
}
Serial.println();

// the first ROM byte indicates which chip
switch (addr[0]) {
case 0x10:
Serial.println("  Chip = DS18S20");  // or old DS1820
type_s = 1;
break;
case 0x28:
Serial.println("  Chip = DS18B20");
type_s = 0;
break;
case 0x22:
Serial.println("  Chip = DS1822");
type_s = 0;
break;
default:
Serial.println("Device is not a DS18x20 family device.");
return;
}

ds.reset();
ds.select(addr);
ds.write(0x44, 1);        // start conversion, with parasite power on at the end

delay(1000);     // maybe 750ms is enough, maybe not
// we might do a ds.depower() here, but the reset will take care of it.

present = ds.reset();
ds.select(addr);
ds.write(0xBE);         // Read Scratchpad

Serial.print("  Data = ");
Serial.print(present, HEX);
Serial.print(" ");
for ( i = 0; i < 9; i++) {           // we need 9 bytes
data[i] = ds.read();
Serial.print(data[i], HEX);
Serial.print(" ");
}
Serial.print(" CRC=");
Serial.print(OneWire::crc8(data, 8), HEX);
Serial.println();

int16_t raw = (data[1] << 8) | data[0];
if (type_s) {
raw = raw << 3; // 9 bit resolution default
if (data[7] == 0x10) {
// "count remain" gives full 12 bit resolution
raw = (raw & 0xFFF0) + 12 - data[6];
}
} else {
byte cfg = (data[4] & 0x60);
// at lower res, the low bits are undefined, so let's zero them
if (cfg == 0x00) raw = raw & ~7;  // 9 bit resolution, 93.75 ms
else if (cfg == 0x20) raw = raw & ~3; // 10 bit res, 187.5 ms
else if (cfg == 0x40) raw = raw & ~1; // 11 bit res, 375 ms
//// default is 12 bit resolution, 750 ms conversion time
}
celsius = (float)raw / 16.0;
fahrenheit = celsius * 1.8 + 32.0;
Serial.print("  Temperature = ");
Serial.print(celsius);
Serial.print(" Celsius, ");
Serial.print(fahrenheit);
Serial.println(" Fahrenheit");

WiFiClient client = server.available();
client.println("HTTP/1.1 200 OK");
client.println("Content-Type: text/html");
client.println("Connection: close");  // the connection will be closed after completion of the response
client.println("Refresh: 5");  // refresh the page automatically every 5 sec
client.println();
client.println("<!DOCTYPE HTML>");
client.println("<html>");
client.print("<p style='text-align: center;'>&nbsp;</p>");
client.print("<p style='text-align: center;'><span style='font-size: x-large;'><strong>ESP8266 and DS18B20 Temperature Sensor Server</strong></span></p>");
client.print("<p style='text-align: center;'><span style='font-size: x-large;'><strong>www.elec-cafe.com</strong></span></p>");
client.print("<p style='text-align: center;'><span style='color: #0000ff;'><strong style='font-size: large;'>Temperature = ");
client.println(celsius);
client.print("</strong></span><h style='text-align: center;'><span style='color: #0000ff;'><strong style='font-size: large;'><sup>o</sup>C</strong></span></h></p>");
client.print("<p style='text-align: center;'>&nbsp;</p>");
client.print("<p style='text-align: center;'>&nbsp;</p>");
client.print("<p style='text-align: center;'>&nbsp;");
client.print("</p>");
client.println("</html>");
delay(5000);
}