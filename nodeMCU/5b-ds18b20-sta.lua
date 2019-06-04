-- esp8266 esp-01 ds18b20 wifi sta
-- измерение температуры датчиком ds18b20
-- создание wifi-станции и передача данных на сервер

local ds = {}

ds.temp = 1360  -- 0x0550 0550h  85 C   
ds.time = 0

ds.measure = function()
  local pin = 4   -- gpio0 = 3, gpio2 = 4
  local addr = string.char(0x28, 0xA1, 0xBD, 0x53, 0x03, 0x00, 0x00, 0x62)
  ow.reset(pin)
  ow.select(pin, addr)
  ow.write(pin, 0x44, 0)
  tmr.create():alarm(1000, tmr.ALARM_SINGLE, function ()
    local present = ow.reset(pin)
    ow.select(pin, addr)
    ow.write(pin, 0xBE, 0)
    local data = ow.read_bytes(pin, 9)
    local crc = ow.crc8(string.sub(data,1,8))
    print("P="..present)
    if crc == data:byte(9) then
      ds.time = tmr.time()
      ds.temp = data:byte(1) + data:byte(2) * 256
      local tA = ds.temp * 625
      local tH = tA / 10000
      local tL = (tA%10000)/1000 + ((tA%1000)/100 >= 5 and 1 or 0)
      print("time="..ds.time.." temperature = "..tH.."."..tL.." Centigrade")
    else
      print("Temperature CRC is not valid!")
    end
  end)
end

ds.createTransmitter = function()  
  local cfg={}
  cfg.ssid="ssid"
  cfg.pwd="password"
  cfg.save=false
  wifi.sta.config(cfg) -- соединяемся с точкой доступа
  local wifi_tmr = tmr.create()
  print("Wait wifi..."); 
  wifi_tmr:register(1000, tmr.ALARM_AUTO, 
    function (t)
      print("status = " .. wifi.sta.status())
      if (wifi.sta.status() == 5) then
        print(wifi.sta.getip())
        sck = net.createConnection(net.TCP, 0)
        t:unregister()
        t:register(10000, tmr.ALARM_AUTO,
          function(t)
            if sck then
              sck:on("receive", function(sck, c) print(c) end)
              sck:on("connection", 
                function(sck, c) 
                  sck:send("TEMP 2 "..ds.temp.." "..ds.time.."\r\n",
                    function(sent) sck:close() end
                  ) 
                end
              )
              sck:connect(3333, "192.168.0.6")
            end
          end
        )
        t:start()
      end
    end
  )
  wifi_tmr:start()
end

ds.start = function()
  ow.setup(4)
  
  local measure_tmr = tmr.create()
  measure_tmr:register(10000, tmr.ALARM_AUTO, ds.measure)
  measure_tmr:start()
  
  ds.createTransmitter()
end

return ds

--[[
-- для отладки на узле 192.168.0.6 создаём TCP-сервер на Node.js
$ cat server.js

const net = require('net');
var textChunk = '';
const server = net.createServer((socket) => {
  // 'connection' listener
  console.log('client connected');
  socket.on('data', (data) => {
    console.log(data);
    textChunk = data.toString('utf8');
    console.log(textChunk);
  });
  socket.on('end', () => {
    console.log('client disconnected');
  });
});
server.on('error', (err) => {
  throw err;
});
server.listen(3333, () => {
  console.log('server bound');
});

]]
