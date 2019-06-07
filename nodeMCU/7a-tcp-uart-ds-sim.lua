-- ESP8266 TCP DS18B20 SIM800L

local M = {}

local comrade = {
  "+7XXXXXXXXXX", 
  "+7XXXXXXXXXX", 
  "+7XXXXXXXXXX"
};

local cfg={
  ssid = "ssid",
  pwd = "password",
  save = false
}

local ds = { 
  addr = string.char(0x28, 0xA1, 0xBD, 0x53, 0x03, 0x00, 0x00, 0x62),
  temp = 1360, -- 1360 0x0550 85 C   
  tick = 0,
  pin = 4 -- gpio0 = 3, gpio2 = 4
}

local GSM = {
  NO = 0,
  OK = 1,
  SM = 2,
  REG = 3,
  BELL = 4
}

local MEASURE_INTERVAL = 10000 -- timer interval in milliseconds
local uartResponse = nil
local uartWaiting = nil
local telNumber = nil
local report = nil
local ds_tmr = nil
local socket = nil

local function debugLog(data)
  if socket ~= nil then
    socket:send(data)
  end
end

local function sendReport()
  tmr.delay(5000000) -- microseconds to busyloop for
  uart.write(0, 'ATH\r\n')
  tmr.delay(5000000) -- microseconds to busyloop for
  uart.write(0, 'AT+CMGS='..telNumber..'\r\n')
  tmr.delay(1000000) -- microseconds to busyloop for
  if uartResponse == GSM_SM then
    debugLog('report: '..report)
    uart.write(0, report)
    uart.write(0, CTRL_Z)
  else
    uart.write(0, ESCAPE)
  end
  uart.write(0, '\r\n\r\n')
  tmr.delay(5000000);
  uart.write(0, 'AT+CMGD=1,4') -- удалить все СМС
end

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
      debugLog('ds.temp: '..ds.temp..' ds.tick: '..ds.tick)
    else
      ds.temp = 1360  -- 0x0550 85 C   
    end
  end)
end

function M.start()

  -- configures the communication parameters of the UART
  -- uart.setup moved in file init.lua
  -- uart.setup(0, 115200, 8, uart.PARITY_NONE, uart.STOPBITS_1, 0) 

  -- register callback function, when '\n' is received.
  uart.on("data", "\n",
    function(data)
      debugLog('sim: '..data)
      uartResponse = nil
      if uartWaiting and string.len(data) > 1 then
        if uartWaiting == GSM.OK and string.sub(data,1,2) == "OK" then
          uartResponse = GSM.OK
        elseif uartWaiting == GSM.SM and string.sub(data,1,1) == ">" then
          uartResponse = GSM.SM
        elseif uartWaiting == GSM.REG and string.sub(data,1,6) == "+CREG:" then
          -- _, _, key, value = string.find(data, "%+CREG: (%w+)%,(%w+)")
          _, _, key, value = string.find(data, "%+CREG: (%d+),(%d+)")
          if value == "1" then 
            uartResponse = GSM.REG
          end
        end
      end
    end, 0
  )

  local function performModem(command, waiting)
    debugLog('esp: '..command)
    uartWaiting = waiting
    uart.write(0, command..'\r\n')
    tmr.delay(1000000) -- microseconds to busyloop for
    uartWaiting = nil
    return uartResponse == waiting
  end

  repeat until performModem('AT', GSM_OK)
  repeat until performModem('AT', GSM_OK)
  repeat until performModem('AT', GSM_OK)
  repeat until performModem('AT+CREG?', GSM_RG)
  repeat until performModem('ATE0', GSM_OK)          -- Set echo mode off
  repeat until performModem('AT+CLIP=1', GSM_OK)     -- Set caller ID on
  repeat until performModem('AT+CMGF=1', GSM_OK)     -- Set SMS to text mode
  repeat until performModem('AT+CSCS="GSM"', GSM_OK) -- Character set of the mobile
  
  uart.on("data", "\n",
    function(data)
      debugLog('sim: '..data)
      uartResponse = nil
      if uartWaiting and string.len(data) > 6 then
        if uartWaiting == GSM.BELL and string.sub(data,1,6) == "+CLIP:" then
          -- при входящем вызове модем SIM800L выдает раз в секунду строки
          -- RING
          -- +CLIP: "+7XXXXXXXXXX",145,"",0,"",0
          local callerNumber
          local comradeNumber
          _, _, callerNumber = string.find(data, '%+CLIP: "(%+%d+)"')
          for _, comradeNumber in ipairs(comrade) do
            if comradeNumber == callerNumber then 
              uartResponse = GSM.BELL 
              telNumber = comradeNumber
            end
          end
        end
      end
    end, 0
  )
  
  ow.setup(ds.pin)
  if ds_tmr then ds_tmr:unregister() end
  ds_tmr = tmr.create()
  -- measure interval in milliseconds
  ds_tmr:register(10000, tmr.ALARM_AUTO, readTemperature)
  ds_tmr:start()

  wifi.sta.config(cfg) -- соединяемся с точкой доступа
  sv = net.createServer(net.TCP, 60)
  sv:listen(3333, function(c)
    if socket ~= nil then
      socket:close()
    end
    socket = c
  end)
end

return M
