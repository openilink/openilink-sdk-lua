local M = {}

local b64chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

function M.ensureTrailingSlash(u)
  if u:sub(-1) == "/" then
    return u
  end
  return u .. "/"
end

function M.joinURL(baseURL, endpoint)
  local base = M.ensureTrailingSlash(baseURL)
  local path = endpoint:gsub("^/+", "")
  return base .. path
end

function M.urlEncode(s)
  return (tostring(s):gsub("([^%w%-%_%.%~])", function(c)
    return string.format("%%%02X", string.byte(c))
  end))
end

function M.shellQuote(s)
  return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

function M.readFile(path, mode)
  if type(io) ~= "table" or type(io.open) ~= "function" then
    return nil
  end
  local f = io.open(path, mode or "rb")
  if not f then
    return nil
  end
  local data = f:read("*a")
  f:close()
  return data
end

function M.writeFile(path, data, mode)
  if type(io) ~= "table" or type(io.open) ~= "function" then
    return nil, "io.open is unavailable"
  end
  local f, err = io.open(path, mode or "wb")
  if not f then
    return nil, err
  end
  f:write(data)
  f:close()
  return true
end

function M.removeFile(path)
  if path and path ~= "" then
    os.remove(path)
  end
end

function M.randomBytes(n)
  if type(io) == "table" and type(io.open) == "function" then
    local f = io.open("/dev/urandom", "rb")
    if f then
      local data = f:read(n)
      f:close()
      if data and #data == n then
        return data
      end
    end
  end

  local out = {}
  for i = 1, n do
    out[i] = string.char(math.random(0, 255))
  end
  return table.concat(out)
end

function M.hexEncode(bytes)
  return (bytes:gsub(".", function(c)
    return string.format("%02x", string.byte(c))
  end))
end

function M.base64Encode(data)
  local out = {}
  local len = #data
  local i = 1

  while i <= len do
    local b1 = string.byte(data, i) or 0
    local b2 = string.byte(data, i + 1) or 0
    local b3 = string.byte(data, i + 2) or 0

    local n = b1 * 65536 + b2 * 256 + b3
    local c1 = math.floor(n / 262144) % 64
    local c2 = math.floor(n / 4096) % 64
    local c3 = math.floor(n / 64) % 64
    local c4 = n % 64

    out[#out + 1] = b64chars:sub(c1 + 1, c1 + 1)
    out[#out + 1] = b64chars:sub(c2 + 1, c2 + 1)

    if i + 1 <= len then
      out[#out + 1] = b64chars:sub(c3 + 1, c3 + 1)
    else
      out[#out + 1] = "="
    end

    if i + 2 <= len then
      out[#out + 1] = b64chars:sub(c4 + 1, c4 + 1)
    else
      out[#out + 1] = "="
    end

    i = i + 3
  end

  return table.concat(out)
end

function M.randomWechatUIN()
  local bytes = M.randomBytes(4)
  local n = 0
  for i = 1, 4 do
    n = n * 256 + string.byte(bytes, i)
  end
  return M.base64Encode(tostring(n))
end

function M.nowUnixMs()
  return math.floor(os.time() * 1000)
end

function M.generateClientID()
  return string.format("sdk-%d-%s", M.nowUnixMs(), M.hexEncode(M.randomBytes(4)))
end

function M.sleepSeconds(seconds)
  if seconds <= 0 then
    return
  end

  local cmd = string.format("sleep %s", tostring(seconds))
  os.execute(cmd)
end

function M.isArray(tbl)
  if type(tbl) ~= "table" then
    return false
  end

  local max = 0
  local count = 0
  for k, _ in pairs(tbl) do
    if type(k) ~= "number" or k <= 0 or k % 1 ~= 0 then
      return false
    end
    if k > max then
      max = k
    end
    count = count + 1
  end

  if count == 0 then
    return true
  end
  return max == count
end

function M.lastValue(t)
  local value
  for _, v in ipairs(t) do
    value = v
  end
  return value
end

return M
