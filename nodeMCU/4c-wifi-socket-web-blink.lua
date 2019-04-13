-- file wifi-socket-web-blink.lua
-- wifistation eventmon socketserver web blink

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
    
    --Create HTTP Server
    http=net.createServer(net.TCP)

    function receive_http(sck, data)    
      local request = string.match(data,"([^\r,\n]*)[\r,\n]",1)
      if request == 'GET /on HTTP/1.1' then
        gpio.write(led_pin, gpio.HIGH)
      end
      if request == 'GET /off HTTP/1.1' then
        gpio.write(led_pin, gpio.LOW)
      end  
 
      sck:on("sent", function(sck) sck:close() end)
   
      local response = "HTTP/1.0 200 OK\r\nServer: NodeMCU on ESP8266\r\nContent-Type: text/html\r\n\r\n"..
     "<html><title>NodeMCU on ESP8266</title><body>"..
     "<h1>NodeMCU on ESP8266</h1>"..
     "<hr>"..
     "<a href=\"on\">On</a> <a href=\"off\">Off</a>"..
     "</body></html>"
      sck:send(response)
    end
 
    if http then
      http:listen(80, function(conn)
        conn:on("receive", receive_http)
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
