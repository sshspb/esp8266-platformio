-- задержка в init.lua, чтобы скрипт запускался не сразу, а по истечению 15 сек, 
-- чтобы, в случаи критической ошибки, исправить или удалить скрипт.
local mytimer = tmr.create() -- Создаем таймер
print("Wait... 15s"); 
mytimer:register(15000, tmr.ALARM_SINGLE, function (t) 
  -- таймер выполниться один раз через 15 сек 
  print("Start");
  dofile("example.lua") --Запуск нашего скрипта 
  t:unregister()
end)
mytimer:start()  -- стартуем таймер
