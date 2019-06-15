-- ESP8266 TCP DS18B20 SIM800L

local M = {}

console = require("tcp-console-log")
comrade = require("comrade")
router = require("router")

local simIsFree = true
local ds = { 
  addr = string.char(0x28, 0xA1, 0xBD, 0x53, 0x03, 0x00, 0x00, 0x62),
  temp = 1360, -- 1360 0x0550 85 C   
  tick = 0,
  pin = 4, -- gpio0 = 3, gpio2 = 4
  interval = 30000, -- measure interval in milliseconds
  timer = tmr.create()
}

local function readTemperature()
  ow.reset(ds.pin)
  ow.select(ds.pin, ds.addr)
  ow.write(ds.pin, 0x44, 0)
  tmr.create():alarm(760, tmr.ALARM_SINGLE, function ()
    ow.reset(ds.pin)
    ow.select(ds.pin, ds.addr)
    ow.write(ds.pin, 0xBE, 0)
    local data = ow.read_bytes(ds.pin, 9)
    local crc = ow.crc8(string.sub(data,1,8))
    if crc == data:byte(9) then
      ds.temp = data:byte(1) + data:byte(2) * 256  -- t Centigrade * 16
      ds.tick = tmr.time() -- system uptime in seconds, 31 bits
      local nh = tostring (node.heap())
      console.put('ds.temp: '..ds.temp..' ds.tick: '..ds.tick..' node.heap: '..nh)
    else
      ds.temp = 1360  -- 0x0550 85 C   
    end
  end)
end

local function sendReport(telNumber)
  ds.timer:unregister()
  tmr.delay(5000000) -- microseconds to busyloop for
  uart.write(0, 'ATH\r')
  tmr.delay(5000000) -- microseconds to busyloop for
  uart.write(0, 'AT+CMGS="'..telNumber..'"\r')
  tmr.delay(1000000) -- microseconds to busyloop for
  local tA = ds.temp * 625
  local tI = tA / 10000
  local tF = (tA%10000)/1000 + ((tA%1000)/100 >= 5 and 1 or 0)
  local report = string.format("test t = %d.%d C\r\n", tI, tF)
  console.put(report)
  uart.write(0, report)
  uart.write(0, '\26') -- CTRL_Z
  uart.write(0, '\r')
  tmr.delay(5000000) -- microseconds to busyloop for
  uart.write(0, 'AT+CMGD=1,4') -- удалить все СМС
  ds.timer:register(ds.interval, tmr.ALARM_AUTO, readTemperature)
  ds.timer:start()
end

function M.start()
  -- register callback function, when '\n' is received.
  uart.on("data", "\n",
    function(data)
      if simIsFree then console.put('simIsFree == true')
      else console.put('simIsFree == false') end
      console.put('from sim: '..data)
      if simIsFree and string.sub(data,1,6) == "+CLIP:" then
        simIsFree = false
        tmr.create():alarm(60000, tmr.ALARM_SINGLE, function () simIsFree = true end)
        -- при входящем вызове модем SIM800L выдает раз в секунду строки
        -- RING
        -- +CLIP: "+7XXXXXXXXXX",145,"",0,"",0
        local callerNumber
        local comradeNumber
        _, _, callerNumber = string.find(data, '%+CLIP: "(%+%d+)"')
        for _, comradeNumber in ipairs(comrade) do
          if comradeNumber == callerNumber then 
            console.put('telNumber: '..comradeNumber)
            sendReport(comradeNumber)
            break
          end
        end
      end
    end, 0
  )
  uart.setup(0, 115200, 8, uart.PARITY_NONE, uart.STOPBITS_1, 0)
  --uart.setup(0, 9600, 8, uart.PARITY_NONE, uart.STOPBITS_1, 0)

  -- configure ESP as a station
  wifi.setmode(wifi.STATION, false)
  -- соединяемся с точкой доступа
  wifi.eventmon.register(wifi.eventmon.STA_GOT_IP, 
    function(T)
      console.put("\nSTA - GOT IP"..
        "\nStation IP: "..T.IP..
        "\nSubnet mask: "..T.netmask..
        "\nGateway IP: "..T.gateway)
      console.init()
      local i = 0
      sim_tmr = tmr.create()
      sim_tmr:register(2000, tmr.ALARM_AUTO,
        function(t) 
          i = i + 1
          if i > 3 then 
            t:unregister()
            uart.write(0, 'AT+CLIP=1\r')
          else
            uart.write(0, 'AT\r')
          end
        end
      )
      sim_tmr:start()
    end
  )
  wifi.sta.config({ssid = router.ssid, pwd  = router.pwd, save = false})
  
  ow.setup(ds.pin)
  ds.timer:register(ds.interval, tmr.ALARM_AUTO, readTemperature)
  ds.timer:start()
end

return M
