do
-- ESP8266 TCP DS18B20 SIM800L
local grComrade = {"+7XXXXXXXXXX", "+7XXXXXXXXXX", "+7XXXXXXXXXX"}
local grRouter = {ssid = "WifiAccessPoint", pwd = "password"}

-- Вывод отладочной информации по WiFi на UDP-сервер-консоль
local grConsole = {}
--[[
 Использование:
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
]]
grConsole.socket = nil
grConsole.put = function(data) 
  if wifi.sta.status() == wifi.STA_GOTIP then
    if grConsole.socket == nil then 
      grConsole.socket = net.createUDPSocket() 
    end
    grConsole.socket:send(41234, '192.168.0.6', data) 
  else
    wifi.sta.config({ssid = grRouter.ssid, pwd  = grRouter.pwd, save = false})
  end
end

local grDallas = { 
  pin = 4, -- gpio0 = 3, gpio2 = 4
  -- addr = string.char(0x28, 0xA1, 0xBD, 0x53, 0x03, 0x00, 0x00, 0x62),
  addr = string.char(0x28, 0x97, 0xC1, 0x53, 0x03, 0x00, 0x00, 0x71),
  temp = 1360, -- 1360 0x0550 85 C   
  tick = 0
}
local grSimIsFree = true
local grStartTimer = tmr.create()
local grSecTimer = tmr.create()
local grBusyTimer = tmr.create()
local grReadTimer = tmr.create()
local grAthTimer = tmr.create()
local grCmgsTimer = tmr.create()
local grMeasureTimer = tmr.create()
local grMeasureInterval = 60000 -- in milliseconds

local function grReadTemperature()

  ow.reset(grDallas.pin)
  ow.select(grDallas.pin, grDallas.addr)
  ow.write(grDallas.pin, 0x44, 0)
  grReadTimer:alarm(900, tmr.ALARM_SINGLE, function ()
    ow.reset(grDallas.pin)
    ow.select(grDallas.pin, grDallas.addr)
    ow.write(grDallas.pin, 0xBE, 0)
    local data = ow.read_bytes(grDallas.pin, 9)
    local crc = ow.crc8(string.sub(data,1,8))
    if crc == data:byte(9) then
      grDallas.temp = data:byte(1) + data:byte(2) * 256  -- t Centigrade * 16
      grDallas.tick = tmr.time() -- system uptime in seconds, 31 bits
      local nh = tostring (node.heap())
      grConsole.put('temp: '..grDallas.temp..' tick: '..grDallas.tick..' heap: '..nh)
    else
      grDallas.temp = 1360  -- 0x0550 85 C   
    end
  end)
end

local function grReport(telNumber)
  grAthTimer:alarm(5000, tmr.ALARM_SINGLE, function ()
    uart.write(0, 'ATH\r')
    grConsole.put('grReport: ATH')
    grCmgsTimer:alarm(5000, tmr.ALARM_SINGLE, function ()
      uart.write(0, 'AT+CMGS="'..telNumber..'"\r')
      grConsole.put('grReport: AT+CMGS="'..telNumber..'"')
      grSecTimer:alarm(1000, tmr.ALARM_SINGLE, function ()
        local tA = grDallas.temp * 625
        local tI = tA / 10000
        local tF = (tA%10000)/1000 + ((tA%1000)/100 >= 5 and 1 or 0)
        local report = string.format("test t = %d.%d C\26", tI, tF)
        uart.write(0, report)
        -- uart.write(0, '\26') -- CTRL_Z
        grConsole.put('grReport: '..report)
      end)
    end)
  end)
end

local function grConfig()
  wifi.setmode(wifi.STATION, false)
  wifi.sta.setip({
    ip = "192.168.0.141",
    netmask = "255.255.255.0",
    gateway = "192.168.0.1"
  })
  wifi.eventmon.register(wifi.eventmon.STA_GOT_IP, 
    function(T)
      grConsole.put("\nSTA - GOT IP"..
        "\nStation IP: "..T.IP..
        "\nSubnet mask: "..T.netmask..
        "\nGateway IP: "..T.gateway)
    end
  )
  wifi.sta.config({ssid = grRouter.ssid, pwd  = grRouter.pwd, save = false})
  
  -- register uart callback function, when '\n' is received.
  uart.on("data", "\n",
    function(data)
      if grSimIsFree then grConsole.put('grSimIsFree == true')
      else grConsole.put('grSimIsFree == false') end
      grConsole.put('from sim: '..data)
      -- при входящем вызове модем SIM800L выдает раз в секунду строки
      -- RING
      -- +CLIP: "+7XXXXXXXXXX",145,"",0,"",0
      if grSimIsFree and string.sub(data,1,6) == "+CLIP:" then
        -- на последующие RING/+CLIP не реагировать 60 секунд
        grSimIsFree = false
        grBusyTimer:alarm(60000, tmr.ALARM_SINGLE, function () grSimIsFree = true end)
        local callerNumber
        local comradeNumber
        _, _, callerNumber = string.find(data, '%+CLIP: "(%+%d+)"')
        for _, comradeNumber in ipairs(grComrade) do
          if comradeNumber == callerNumber then 
            grConsole.put('telNumber: '..comradeNumber)
            grReport(comradeNumber)
            break
          end
        end
      elseif string.sub(data,1,4) == "quit" then
          uart.on("data") -- unregister callback function
          grConsole.put('unregister callback function')
      end
    end, 0)
  
  ow.setup(grDallas.pin)  -- ds18b20 1-wire temperature sensor
  grMeasureTimer:register(grMeasureInterval, tmr.ALARM_AUTO, grReadTemperature)
  grMeasureTimer:start()
end

local function grStart()
  local i = 0
  grStartTimer:register(2000, tmr.ALARM_AUTO,
    function(t) 
      i = i + 1
      if i == 1 then
        uart.write(0, 'AT\r\n')
      elseif i == 2 then
        uart.write(0, 'AT\r\n')
      elseif i == 3 then 
        t:unregister()
        uart.write(0, 'AT+CLIP=1\r\n')
        grConfig()
      end
    end
  )
  grStartTimer:start()
end

grStart()

end
