-- esp8266 tcp <-> uart

local function tcp2uart()
  uart.setup(0, 9600, 8, uart.PARITY_NONE, uart.STOPBITS_1, 0)
  sv=net.createServer(net.TCP, 60)
  global_c = nil
  
  sv:listen(3333, function(c)
    if global_c~=nil then
      global_c:close()
    end
    global_c=c
    c:on("receive",function(sck,pl)	uart.write(0,pl) end)
  end)
  
  uart.on("data","\n", function(data)
    if global_c~=nil then
      global_c:send(data)
    end
  end, 0)
end

local function start()
  cfg={}
  cfg.ssid="ssid"
  cfg.pwd="password"
  cfg.save=false
  wifi.sta.config(cfg) -- соединяемся с точкой доступа
  
  wifi_tmr = tmr.create()
  wifi_tmr:register(1000, tmr.ALARM_AUTO, 
    function (t)
      if (wifi.sta.status() == 5) then
        --print(wifi.sta.getip())
        t:unregister()
        tcp2uart()
      end
    end
  )
  wifi_tmr:start()
end

return  { start = start }
