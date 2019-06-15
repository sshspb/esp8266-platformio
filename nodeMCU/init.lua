-- задержка в init.lua, чтобы скрипт запускался не сразу, 
-- а по истечению 15 сек, чтобы, в случаи критической ошибки, 
-- исправить или удалить скрипт.
tmr.create():alarm(15000, tmr.ALARM_SINGLE, function()
  (require("example")).start()
end)
