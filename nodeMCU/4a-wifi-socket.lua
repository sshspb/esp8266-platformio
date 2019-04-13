-- file wifi-socket.lua
-- wifi station socket server eventmon

cfg={}
cfg.ssid="NorthSide"
cfg.pwd="fxbdytfxbdyt1"
cfg.save=false

wifi.eventmon.register(wifi.eventmon.STA_GOT_IP, 
  function(T)
    print("\n\tSTA - GOT IP".."\n\tStation IP: "..T.IP..
    "\n\tSubnet mask: "..T.netmask.."\n\tGateway IP: "..T.gateway)

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
     
 end)

wifi.sta.config(cfg) -- соединяемся с точкой доступа
cfg = nil

collectgarbage()
