## Lua

Руководство по языку [Lua](https://www.lua.org/) доступно на английском https://www.lua.org/manual/5.3/ и русском http://lua.org.ru/contents_ru.html языках.

Краткий обзор Lua от Tyler Neylon: http://tylerneylon.com/a/learn-lua/

Подробная wiki-справка: http://lua-users.org/wiki/TutorialDirectory

Краткая справка, в формате PDF: http://lua-users.org/files/wiki_insecure/users/thomasl/luarefv51single.pdf

## NodeMCU

Открытый бесплатный проект [NodeMCU](https://github.com/nodemcu/nodemcu-firmware) это прошивка на основе Lua для ESP8266 WiFi SOC от Espressif. NodeMCU реализован на C в среде в [Espressif NON-OS SDK](https://github.com/espressif/ESP8266_NONOS_SDK) и использует встроенную файловую систему SPIFFS на основе флэш-памяти.

NodeMCU модульная, что позволяет собрать прошивку только из требуемых модулей.
Существует сайт, [https://nodemcu-build.com](https://nodemcu-build.com), на котором можно собрать NodeMCU с необходимыми модулями. 
Исходные коды модулей можно найти здесь:[https://github.com/nodemcu/nodemcu-firmware/tree/master/lua_modules](https://github.com/nodemcu/nodemcu-firmware/tree/master/lua_modules).

Подробная документация по NodeMCU тут: [https://nodemcu.readthedocs.io/en/master/](https://nodemcu.readthedocs.io/en/master/)

Существует одноимённая отладочная плата NodeMCU Development board, или [ESP8266 12-E NodeMCU Kit](https://www.nodemcu.com/index_en.html)

![NodeMCU Development board appearance](images/NodeMCUv1.0-kit.jpg)

![NodeMCU Development board pinout](images/NodeMCUv1.0-pinout.jpg)
    
![NodeMCU Development board GPIOs](images/NodeMCUv1.0-GPIOs.jpg)

Контакты ввода/вывода в устройстве NoddMCU отображаются на внутренние контакты GPIO (General Purpose Input/Output) ESP8266 следующим образом:
```
D0 GPIO16
D1 GPIO5   D3 GPIO0   D5 GPIO14   D7 GPIO13    D9 GPIO3   D11 GPIO9     
D2 GPIO4   D4 GPIO2   D6 GPIO12   D8 GPIO15   D10 GPIO1   D12 GPIO10 
```

Питание модуля NodeMcu, варианты:
```
5-18 В через контакт Vin;
5 В через USB-разъем;
3,3 В через вывод 3V3.
```

Электрические характеристики модуля ESP-12E
```
3.3 V рабочее напряжение
15 mA максимально допустимый ток контакта GPIO
12 - 200 mA ток потребления в рабочем режиме
Less than 200 uA ток потребления в режиме ожидания (standby)
```

## esptool.py

Прошивку NodeMCU можно осуществить с помощью [esptool](https://github.com/espressif/esptool) — а Python-based, open source, platform independent, utility to communicate with the ROM bootloader in Espressif ESP8266 & ESP32 chips.
```
esptool.py --port COM4 write_flash 0x00000 The_NodeMCU_Firmware.bin
esptool.py --port /dev/ttyUSB0 write_flash 0x00000 The_NodeMCU_Firmware.bin
```
To erase the entire flash chip (all data replaced with 0xFF bytes):
```
esptool.py erase_flash
```
Read SPI flash id
```
esptool.py flash_id
```
Welcome to the [esptool wiki](https://github.com/espressif/esptool/wiki) !

#### Порядок действий при прошивке NodeMCU:

Установить esp-01 в режим прошивки - замкнуть ключ Flash и подать питание (или перезагрузить кнопкой Reset).
```
D:\doc\esp8266\nodemcu\firmware>esptool.py --port COM4 flash_id
esptool.py v2.6
Serial port COM4
Connecting....
Detecting chip type... ESP8266
Chip is ESP8266EX
Features: WiFi
MAC: 84:f3:eb:7f:d2:56
Uploading stub...
Running stub...
Stub running...
Manufacturer: 85
Device: 6014
Detected flash size: 1MB
Hard resetting via RTS pin...
```

Перезагрузить esp-01 в режим прошивки - при замкнутом ключе Flash нажать кнопку Reset.
```
D:\doc\esp8266\nodemcu\firmware>esptool.py --port COM4 write_flash 0x00000 nodemcu-master-8-modules-2019-05-31-00-20-03-integer.bin
esptool.py v2.6
Serial port COM4
Connecting........_____....._____....._____.....____
Detecting chip type... ESP8266
Chip is ESP8266EX
Features: WiFi
MAC: 84:f3:eb:7f:d2:56
Uploading stub...
Running stub...
Stub running...
Configuring flash size...
Auto-detected Flash size: 1MB
Flash params set to 0x0220
Compressed 421888 bytes to 272895...
Wrote 421888 bytes (272895 compressed) at 0x00000000 in 31.2 seconds (effective 108.3 kbit/s)...
Hash of data verified.

Leaving...
Hard resetting via RTS pin...
```


## ESPlorer

Для написания и заливки Lua-скриптов есть утилита [ESPlorer](http://esp8266.ru/esplorer/) — the essential multiplatforms tools for any ESP8266 developer from luatool author’s, required JAVA (Standard Edition - SE ver 7 and above) installed.
- [ESPlorer source code on GitHub](https://github.com/4refr0nt/ESPlorer)
- [Download ESPlorer.zip](http://esp8266.ru/esplorer-latest/?f=ESPlorer.zip)

## init.lua

При ниличии скрипта с именем ``init.lua`` он стартует автоматически после запуска NodeMCU, а основной скрипт, например, ``main.lua``, запускается из ``init.lua``. При некоторых критических ошибках NodeMCU может перезагружаться. И самое страшное, что может случиться – это циклическая перезагрузка. Поэтому, при отладке кода, лучше запускать скрипты вручную, и только после того как все ошибки будут устранены, добавлять его в ``init.lua``.

Кроме того введём в ``init.lua`` задержку в на запуск основного скрипта. Таким образом, если мы допустим ошибку и NodeMCU уйдет в циклическую перезагрузку, после перезагрузки у нас будет 15 секунд для того чтобы удалить или исправить дефектный скрипт.
```
-- файл init.lua
-- задержка, чтобы скрипт запускался не сразу, а по истечению 15 сек, 
-- в случаи критической ошибки, чтобы исправить ее или удалить скрипт.
local mytimer = tmr.create() -- Создаем таймер
print("Wait... 15s"); 
mytimer:register(15000, tmr.ALARM_SINGLE, function (t) 
  -- таймер выполниться один раз через 15 сек 
  print("Start");
  dofile("example.lua") --Запуск нашего скрипта 
  t:unregister()
end)
mytimer:start()  -- стартуем таймер
```
Смотри также [https://nodemcu.readthedocs.io/en/latest/upload/#initlua](https://nodemcu.readthedocs.io/en/latest/upload/#initlua)
