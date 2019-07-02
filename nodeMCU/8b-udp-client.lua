-- Station
local grHost = {ssid = "grusesp01", pwd = "grusesp01"}
local grDallas = { 
  pin = 4, -- gpio0 = 3, gpio2 = 4
  -- addr = string.char(0x28, 0x97, 0xC1, 0x53, 0x03, 0x00, 0x00, 0x71)
  addr = string.char(0x28, 0x9D, 0x96, 0x53, 0x03, 0x00, 0x00, 0x7A)
}
local grReadTimer = tmr.create()
local grMeasureTimer = tmr.create()
local grMeasureInterval = 60000 -- in milliseconds

local grConsole = {}
grConsole.ip = '192.168.4.1'
grConsole.port = 5050
grConsole.socket = nil
grConsole.put = function(data) 
  if wifi.sta.status() == wifi.STA_GOTIP then
    if grConsole.socket == nil then 
      grConsole.socket = net.createUDPSocket() 
    end
    grConsole.socket:send(grConsole.port, grConsole.ip, data) 
  end
end

local function grReadTemperature()
  ow.reset(grDallas.pin)
  ow.select(grDallas.pin, grDallas.addr)
  ow.write(grDallas.pin, 0x44, 0)
  grReadTimer:alarm(900, tmr.ALARM_SINGLE, function ()
    ow.reset(grDallas.pin)
    ow.select(grDallas.pin, grDallas.addr)
    ow.write(grDallas.pin, 0xBE, 0)
    local data = ow.read_bytes(grDallas.pin, 9)
    local temp = (ow.crc8(string.sub(data,1,8)) == data:byte(9)) and data:byte(1)+data:byte(2)*256 or 1360
    grConsole.put(string.format("%x %d %d %d", grDallas.addr:byte(8), temp, tmr.time(), node.heap()))
  end)
end

  wifi.setmode(wifi.STATION)
  wifi.sta.setip({
    ip = "192.168.4.2",
    netmask = "255.255.255.0",
    gateway = "192.168.4.1"
  })
  -- wifi.eventmon.register(wifi.eventmon.STA_GOT_IP, function(T) end)
  wifi.sta.config({ssid = grHost.ssid, pwd = grHost.pwd})
  
  ow.setup(grDallas.pin)  -- ds18b20 1-wire temperature sensor
  grMeasureTimer:register(grMeasureInterval, tmr.ALARM_AUTO, grReadTemperature)
  grMeasureTimer:start()
