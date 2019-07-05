-- Access Point: ESP8266 UDP DS18B20 SIM800L
--[[
 Использование grConsole:
 на узле что в роли консоли необходим udp-сервер, например, на Node.js:
 
const dgram = require('dgram');
const server = dgram.createSocket('udp4');
server.on('error', (err) => {
  console.log(`server error:\n${err.stack}`);
  server.close();
});
server.on('message', (msg, rinfo) => {
  console.log(`server got: ${msg} from ${rinfo.address}:${rinfo.port}`);
});
server.on('listening', () => {
  const address = server.address();
  console.log(`server listening ${address.address}:${address.port}`);
});
server.bind(41234);   // server listening 0.0.0.0:41234
// or  server.bind(41234, '192.168.0.6');

 Использование grUDPSocket:
 на узле что в роли консоли необходим udp-слиент, например, на Node.js:
 
const PORT = 5050;
const HOST = '192.168.0.141';
const message = new Buffer('BB 444 1200 2000');
const dgram = require('dgram');
const server = dgram.createSocket('udp4');
server.send(message, 0, message.length, PORT, HOST, function(err, bytes) {
  if (err) throw err;
  console.log('UDP message sent to ' + HOST +':'+ PORT);
});
]]
local grComrade = {"+79219258698", "+79213303129", "+79214201935"}
local grRouter = {ssid = "NorthSide", pwd = "fxbdytfxbdyt1"}
local cfgsta = {ip = "192.168.0.141", netmask = "255.255.255.0", gateway = "192.168.0.1"}
local grAccessPoint = {ssid = "grusesp01", pwd = "grusesp01"}
local cfgap = {ip="192.168.4.1", netmask="255.255.255.0", gateway="192.168.4.1"}
local grDallas = { 
  pin = 4, -- gpio0 = 3, gpio2 = 4
  addr = string.char(0x28, 0xA1, 0xBD, 0x53, 0x03, 0x00, 0x00, 0x62)
}
local grRings = 0
local grSimIsFree = true
local grStatusTimer = tmr.create()
local grBusyTimer = tmr.create()
local grReadTimer = tmr.create()
local grAthTimer = tmr.create()
local grCmgsTimer = tmr.create()
local grSecTimer = tmr.create()
local grMeasureTimer = tmr.create()
local grMeasureInterval = 60000 -- in milliseconds
local grSensor = {}
local grUDPSocket = nil
--[[
local grConsole = {}
grConsole.socket = nil
grConsole.put = function(data) 
  if wifi.sta.status() == wifi.STA_GOTIP then
    if grConsole.socket == nil then 
      grConsole.socket = net.createUDPSocket() 
    end
    grConsole.socket:send(41234, '192.168.0.6', data) 
  end
end
]]
local function grReadTemperature()
  if grRings > 7 then
    uart.write(0, 'AT+CLIP=1\r')
  end
  ow.reset(grDallas.pin)
  ow.select(grDallas.pin, grDallas.addr)
  ow.write(grDallas.pin, 0x44, 0)
  grReadTimer:alarm(900, tmr.ALARM_SINGLE, function ()
    ow.reset(grDallas.pin)
    ow.select(grDallas.pin, grDallas.addr)
    ow.write(grDallas.pin, 0xBE, 0)
    local data = ow.read_bytes(grDallas.pin, 9)
    if ow.crc8(string.sub(data,1,8)) == data:byte(9) then
      local key = string.format("%x",grDallas.addr:byte(8))
      if grSensor[key] == nil then 
        grSensor[key] = {}
      end
      grSensor[key].temp = data:byte(1) + data:byte(2) * 256  -- Centigrade*16
      grSensor[key].tick = tmr.time() -- system uptime in seconds, 31 bits
      grSensor[key].heap = node.heap()
      --grConsole.put(string.format("%s %d %d %d", key, grSensor[key].temp, grSensor[key].tick, grSensor[key].heap))
    end
  end)
end

local function grReport(telNumber)
  grAthTimer:alarm(5000, tmr.ALARM_SINGLE, function ()
    uart.write(0, 'ATH\r')
    grCmgsTimer:alarm(5000, tmr.ALARM_SINGLE, function ()
      uart.write(0, 'AT+CMGS="'..telNumber..'"\r')
      grSecTimer:alarm(1000, tmr.ALARM_SINGLE, function ()
        local report = ""
        local tA, tI, tF
        for key, sensor in pairs(grSensor) do 
          tA = sensor.temp * 625
          tI = tA / 10000
          tF = (tA%10000)/1000 + ((tA%1000)/100 >= 5 and 1 or 0)
          report = report .. string.format("%s %d.%d %d %d\r\n", key, tI, tF, tmr.time()-sensor.tick, sensor.heap)
        end
        uart.write(0, report)
        uart.write(0, '\26') -- CTRL_Z
        grRings = 0
        --grConsole.put('grReport: \r\n'..report)
      end)
    end)
  end)
end

local function grConfig()
  uart.setup(0, 9600, 8, uart.PARITY_NONE, uart.STOPBITS_1, 1)
  -- register uart callback function, when '\n' is received.
  uart.on("data", "\n",
    function(data)
      -- при входящем вызове модем SIM800L выдает 
      -- RING
      -- +CLIP: "+7XXXXXXXXXX",145,"",0,"",0
      if grSimIsFree and string.sub(data,1,4) == "RING" then
        grRings = grRings + 1
      elseif grSimIsFree and string.sub(data,1,6) == "+CLIP:" then
        -- на последующие RING/+CLIP не реагировать 60 секунд
        grSimIsFree = false
        grBusyTimer:alarm(60000, tmr.ALARM_SINGLE, function () grSimIsFree = true end)
        local callerNumber
        local comradeNumber
        _, _, callerNumber = string.find(data, '%+CLIP: "(%+%d+)"')
        for _, comradeNumber in ipairs(grComrade) do
          if comradeNumber == callerNumber then 
            grReport(comradeNumber)
            break
          end
        end
      end
    end, 0)
  uart.write(0, 'AT+CLIP=1\r')

  wifi.setmode(wifi.STATIONAP)
  wifi.sta.setip(cfgsta)
  wifi.ap.setip(cfgap)
  grStatusTimer:register(1000, tmr.ALARM_AUTO,
    function (t)
      if (wifi.sta.status() == wifi.STA_GOTIP) then
        grUDPSocket = net.createUDPSocket() 
        grUDPSocket:listen(5050)
        grUDPSocket:on("receive", function(s, data, port, ip)
          local key, temp, tick, heap = string.match(data, "(%x+)%s+(%d+)%s+(%d+)%s+(%d+)")
          if grSensor[key] == nil then 
            grSensor[key] = {}
          end
          grSensor[key].temp = tonumber(temp)
          grSensor[key].tick = tmr.time()
          grSensor[key].heap = tonumber(heap)
          --grConsole.put(string.format("sensor %s %s %s %s", key, temp, tick, heap))
        end)
        t:unregister()
      end
    end
  )
  grStatusTimer:start()
  wifi.sta.config({ssid = grRouter.ssid, pwd = grRouter.pwd})
  wifi.ap.config({ssid = grAccessPoint.ssid, pwd = grAccessPoint.pwd})
  
  ow.setup(grDallas.pin)  -- ds18b20 1-wire temperature sensor
  grMeasureTimer:register(grMeasureInterval, tmr.ALARM_AUTO, grReadTemperature)
  grMeasureTimer:start()
end

grConfig()
