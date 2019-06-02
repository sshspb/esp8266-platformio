-- file wifi-timer.lua
-- wifi station socket server timer

cfg={}
cfg.ssid="NorthSide"
cfg.pwd="password"
cfg.save=false
wifi.sta.config(cfg) -- соединяемся с точкой доступа
cfg = nil

mytimer = tmr.create() -- Создаем таймер
print("Wait..."); 
mytimer:register(1000, tmr.ALARM_AUTO, 
  function (t)
    print("status = " .. wifi.sta.status())
    if (wifi.sta.status() == 5) then
      print(wifi.sta.getip())
      sv=net.createServer(net.TCP)  --Create Server
      function receiver(sck, data)    
        print(data)  -- Print received data
        sck:send("Recived: "..data)  -- Send reply
      end
      if sv then
        -- в консоле unix-машины командой 
        -- $ telnet 192.168.0.100 3333
        -- соединяемся с данным сервером
        sv:listen(3333, function(conn)
          conn:on("receive", receiver)
          conn:send("Hello!")
        end)
      end
      print("Started.")
      t:unregister()
    end
  end
)
mytimer:start()  -- стартуем таймер

collectgarbage()

--[[
wifi.sta.status() returns number： 0~5
0 == wifi.STA_IDLE:       STATION_IDLE,
1 == wifi.STA_CONNECTING: STATION_CONNECTING,
2 == wifi.STA_WRONGPWD:   STATION_WRONG_PASSWORD,
3 == wifi.STA_APNOTFOUND: STATION_NO_AP_FOUND,
4 == wifi.STA_FAIL:       STATION_CONNECT_FAIL,
5 == wifi.STA_GOTIP:      STATION_GOT_IP.
--]]
