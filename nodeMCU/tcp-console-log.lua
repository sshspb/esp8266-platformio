-- tcp console log
-- Вывод отладочной информации по WiFi на tcp-сервер-консоль
-- при отсутствии возможности использовать UART
--[[
 Использование:
 первоначально инициализировать модуль C.init() и 
 далее выводить текст функцией C.put(data)
 Примечание:
 на узле что в роли консоли необходим tcp-сервер, 
 например такой, на Node.js:

const net = require('net');
const PORT = 3333;
var textChunk = '';
const server = net.createServer((socket) => {
  // 'connection' listener
  console.log('client connected' + socket.remoteAddress +':'+ socket.remotePort);
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
server.listen(PORT, () => {
  console.log('server bound');
});
]]

local C = {
  port = 3333, -- ip и port узла что будет в роли консоли
  ip = '192.168.0.6',
  socket = nil,
  semafor = false,
  buffer = '',
  text = '',
  connected = false
}

C.setSemafor = function() 
  --print('in setSemafor')
  -- разрешить печать
  C.semafor = true 
  -- если в буфере текст, на печать
  if string.len(C.buffer) > 0 then
    C.put('')
  end
end

C.put = function(data)
  --print('in put: '..data)
  -- текст data накапливаем в buffer
  if string.len(data) > 0 and string.len(C.buffer) < 1000 then
    C.buffer = C.buffer..data..'\n'
  end
  if C.connected == true and C.socket ~= nil then
    if C.semafor and string.len(C.buffer) > 0 then 
      -- текст из buffer в промежуточную переменную text 
      -- и установить семафором semafor что socket:send занят
      C.text, C.buffer, C.semafor = C.buffer, '', false
      -- на печать содержимое text
      C.socket:send(C.text)
    else
      --print('C.semafor == nil or string.len(C.buffer) == 0')
    end
   else
     --print('C.connected ~= true or C.socket == nil')
  end
end
  
C.init = function()
  -- создание tcp-клиента
  client = net.createConnection(net.TCP, 0)
  client:on("connection", function(sck, c) 
    --if C.socket ~= nil then C.socket:close() end
    C.socket = sck
    C.setSemafor()
    C.put('client on event connection')
    C.socket:on("sent", function(s) C.setSemafor() end )
    C.connected = true
  end)
  -- соединение с tcp-сервером-консолью
  client:connect(C.port, C.ip)
end

return C
