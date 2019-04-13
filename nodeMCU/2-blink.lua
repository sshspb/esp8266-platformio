-- file blink.lua

-- variant 1 - delay 
my_pin_nummber = 4  -- ESP8266 pin GPIO2
gpio.mode(my_pin_nummber, gpio.OUTPUT)
while 1 do
  gpio.write(my_pin_nummber, gpio.HIGH)
  tmr.delay(1000000)   -- wait 1,000,000 us = 1 second
  gpio.write(my_pin_nummber, gpio.LOW)
  tmr.delay(1000000)   -- wait 1,000,000 us = 1 second
end
-- ------------------------------

-- variant 2 - timer
pin = 4  -- ESP8266 pin GPIO2
status = gpio.LOW
duration = 1000  -- 1 second duration for timer
gpio.mode(pin, gpio.OUTPUT)
gpio.write(pin, gpio.LOW)
mytimer = tmr.create()
mytimer:register(duration, tmr.ALARM_AUTO, 
  function ()
    if status == gpio.LOW then
        status = gpio.HIGH
    else
        status = gpio.LOW
    end
    gpio.write(pin, status)
  end
)
mytimer:start()
-- ------------------------------

-- variant 3 - serout
my_pin_nummber = 4  -- ESP8266 pin GPIO2
-- Устанавливаем режим работы как вывод
gpio.mode (my_pin_nummber, gpio.OUTPUT)
-- Задать высокий уровень
gpio.write (my_pin_nummber, gpio.HIGH)
-- Задать низкий уровень
gpio.write (my_pin_nummber, gpio.LOW)
-- Мигаем светодиодом 10 раз
gpio.serout (1, gpio.HIGH, {+990000,990000}, 10, 1)
-- ------------------------------
