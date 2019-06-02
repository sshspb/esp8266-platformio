ds = {}
ds.sens = {}
ds.temp = {}
ds.tick = {}

ds.sens[1] = string.char(0x28, 0xA1, 0xBD, 0x53, 0x03, 0x00, 0x00, 0x62)
ds.temp[1] = 1360  -- 0x0550 0550h  85 C   
ds.tick[1] = 0

ds.measure = function ()
  local pin = 4   -- gpio0 = 3, gpio2 = 4
  local addr = ds.sens[1]
  print(string.format("address: %s", ("%02X:%02X:%02X:%02X:%02X:%02X:%02X:%02X"):format(addr:byte(1,8))))
  ow.reset(pin)
  ow.select(pin, addr)
  ow.write(pin, 0x44, 0)
  tmr.create():alarm(760, tmr.ALARM_SINGLE, function ()
    local present = ow.reset(pin)
    ow.select(pin, addr)
    ow.write(pin, 0xBE, 0)
    local data = ow.read_bytes(pin, 9)
    local crc = ow.crc8(string.sub(data,1,8))
    print("P="..present)
    print(data:byte(1,9))
    print("CRC="..crc.." scratchpad(9)="..data:byte(9))
    if crc == data:byte(9) then
      ds.tick[1] = tmr.now()
      local tA = (data:byte(1) + data:byte(2) * 256) * 625
      local tH = tA / 10000
      local tL = (tA%10000)/1000 + ((tA%1000)/100 >= 5 and 1 or 0)
      print("Temperature = "..tH.."."..tL.." Centigrade")
    else
      print("Temperature CRC is not valid!")
    end
  end)
end

ow.setup(4)
measure_tmr = tmr.create()
measure_tmr:register(10000, tmr.ALARM_AUTO, ds.measure)
measure_tmr:start()
