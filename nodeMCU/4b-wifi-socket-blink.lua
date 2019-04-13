-- file wifi-socket-blink.lua
-- wifistation socketserver eventmon blink

--Set Pin mode
led_pin = 4  -- GPIO2
gpio.mode(led_pin, gpio.OUTPUT)

-- Register callback for WiFi event monitor
wifi.eventmon.register(wifi.eventmon.STA_GOT_IP, 
  function(T)
    print("\n\tSTA - GOT IP".."\n\tStation IP: "..T.IP..
    "\n\tSubnet mask: "..T.netmask.."\n\tGateway IP: "..T.gateway)

    sv=net.createServer(net.TCP)  --Create Server
    function receiver(sck, data)    
      if string.sub (data, 0, 1) == "1" then
        gpio.write(led_pin, gpio.HIGH)
      else
        if string.sub (data, 0, 1) == "0" then
          gpio.write(led_pin, gpio.LOW)
        end
      end
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
    -- Unregister callback for WiFi event monitor
    wifi.eventmon.unregister(wifi.eventmon.STA_GOT_IP)
 end)

--WiFi STA Settup
ipcfg = {
  ip = "192.168.0.11",
  netmask = "255.255.255.0",
  gateway = "192.168.0.1"
}
wifi.sta.setip(ipcfg)
ipcfg = nil

stacfg = {
  ssid = "NorthSide",
  pwd = "fxbdytfxbdyt1",
  save = false
}
wifi.sta.config(stacfg) -- соединяемся с точкой доступа
stacfg = nil

collectgarbage()
