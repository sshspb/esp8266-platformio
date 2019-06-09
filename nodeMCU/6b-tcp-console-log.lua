-- tcp console log

C = {
  port = 3333,
  ip = '192.168.0.6',
  socket = nil,
  semafor = false,
  buffer = '',
  text = '',
  
}

C.setSemafor = function() 
    C.semafor = true 
    if string.len(C.buffer) > 0 then
      C.put('')
    end
end

C.put = function(data)
    if string.len(data) > 0 and string.len(C.buffer) < 1000 then
      C.buffer = C.buffer..data..'\n'
    end
    if C.socket ~= nil then
      if C.semafor and string.len(C.buffer) > 0 then 
        C.text, C.buffer, C.semafor = C.buffer, '', false
        C.socket:send(C.text)
      end
    end
end
  
C.init = function()
      client = net.createConnection(net.TCP, 0)
      client:on("connection", function(sck, c) 
        print('event connection')
        if C.socket ~= nil then
          C.socket:close()
        end
        C.socket = sck
        C.semafor = true 
        C.socket:on("sent", function(s) C.setSemafor() end )

        C.put('How do you do?')
        C.put('Thank you, I am well')
      end)
      client:connect(3333, "192.168.0.6")
end

--return C

--- test ---

router = {
  ssid = "NorthSide",
  pwd = "fxbdytfxbdyt1"
}

wifi.setmode(wifi.STATION, false)
wifi.eventmon.register(wifi.eventmon.STA_GOT_IP, 
  function(T)
    print("\n\tSTA - GOT IP"..
    "\n\tStation IP: "..T.IP..
    "\n\tSubnet mask: "..T.netmask..
    "\n\tGateway IP: "..T.gateway)
    if C ~= nil then C.init() end
  end
)
wifi.sta.config({ssid = router.ssid, pwd  = router.pwd, save = false})

C.put('Hello, world')