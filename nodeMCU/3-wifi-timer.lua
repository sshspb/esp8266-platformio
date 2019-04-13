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
0: STATION_IDLE,
1: STATION_CONNECTING,
2: STATION_WRONG_PASSWORD,
3: STATION_NO_AP_FOUND,
4: STATION_CONNECT_FAIL,
5: STATION_GOT_IP.
--]]
