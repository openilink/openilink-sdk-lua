package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

local ilink = require("openilink")

local client = ilink.newClient("")

local result, err = client:loginWithQR({
  onQRCode = function(img)
    print("Scan QR code:")
    print(img)
  end,
  onScanned = function()
    print("Scanned. Confirm on WeChat...")
  end,
  onExpired = function(attempt, maxAttempts)
    print(string.format("QR expired (%d/%d), refreshing...", attempt, maxAttempts))
  end,
})

if not result then
  error(err)
end
if not result.connected then
  error("login failed: " .. tostring(result.message))
end

print("Connected BotID=" .. tostring(result.bot_id))

local stop = false

client:monitor(function(msg)
  local text = ilink.ExtractText(msg)
  if text ~= "" then
    print(string.format("[%s] %s", tostring(msg.from_user_id), text))
    local _, pushErr = client:push(msg.from_user_id, "echo: " .. text)
    if pushErr then
      print("push failed: " .. tostring(pushErr))
    end
  end
end, {
  onBufUpdate = function(buf)
    local f = io.open("sync_buf.dat", "wb")
    if f then
      f:write(buf)
      f:close()
    end
  end,
  shouldStop = function()
    return stop
  end,
  onError = function(e)
    io.stderr:write(tostring(e) .. "\n")
  end,
})
