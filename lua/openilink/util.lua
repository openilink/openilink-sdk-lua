local M = {}

local b64chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local b64lookup = {}

for i = 1, #b64chars do
  b64lookup[b64chars:sub(i, i)] = i - 1
end

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

function M.parseExecResult(ok, why, code)
  if ok == true then
    return 0
  end
  if type(ok) == "number" then
    if ok > 255 then
      return math.floor(ok / 256)
    end
    return ok
  end
  if type(code) == "number" then
    return code
  end
  return 1
end

function M.commandExists(name)
  local ok, why, code = os.execute("command -v " .. tostring(name) .. " >/dev/null 2>&1")
  return M.parseExecResult(ok, why, code) == 0
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

function M.hexDecode(hex)
  hex = tostring(hex or "")
  if #hex % 2 ~= 0 or hex:find("[^0-9a-fA-F]") then
    return nil, "invalid hex"
  end

  local out = {}
  for i = 1, #hex, 2 do
    local byte = tonumber(hex:sub(i, i + 1), 16)
    out[#out + 1] = string.char(byte)
  end
  return table.concat(out), nil
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

function M.base64DecodeFlexible(data)
  local normalized = tostring(data or ""):gsub("%s+", ""):gsub("%-", "+"):gsub("_", "/")
  local remainder = #normalized % 4

  if remainder == 1 then
    return nil, "invalid base64 length"
  end
  if remainder > 0 then
    normalized = normalized .. string.rep("=", 4 - remainder)
  end

  local out = {}
  for i = 1, #normalized, 4 do
    local c1 = normalized:sub(i, i)
    local c2 = normalized:sub(i + 1, i + 1)
    local c3 = normalized:sub(i + 2, i + 2)
    local c4 = normalized:sub(i + 3, i + 3)

    local v1 = b64lookup[c1]
    local v2 = b64lookup[c2]
    local v3 = c3 == "=" and 0 or b64lookup[c3]
    local v4 = c4 == "=" and 0 or b64lookup[c4]

    if v1 == nil or v2 == nil or (c3 ~= "=" and v3 == nil) or (c4 ~= "=" and v4 == nil) then
      return nil, "invalid base64 character"
    end

    local n = v1 * 262144 + v2 * 4096 + v3 * 64 + v4
    out[#out + 1] = string.char(math.floor(n / 65536) % 256)
    if c3 ~= "=" then
      out[#out + 1] = string.char(math.floor(n / 256) % 256)
    end
    if c4 ~= "=" then
      out[#out + 1] = string.char(n % 256)
    end
  end

  return table.concat(out), nil
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
  return string.format("openclaw-weixin:%d-%s", M.nowUnixMs(), M.hexEncode(M.randomBytes(4)))
end

function M.encodeClientVersion(version)
  local major, minor, patch = tostring(version or ""):match("^(%d+)%.(%d+)%.(%d+)$")
  major = tonumber(major) or 0
  minor = tonumber(minor) or 0
  patch = tonumber(patch) or 0
  return major * 65536 + minor * 256 + patch
end

function M.trimString(value)
  return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

function M.basename(path)
  local normalized = tostring(path or ""):gsub("[/\\]+$", "")
  if normalized == "" then
    return ""
  end
  local name = normalized:match("([^/\\]+)$")
  return name or normalized
end

function M.md5Hex(data)
  local inputFile = os.tmpname()
  local outputFile = os.tmpname()
  local stderrFile = os.tmpname()

  local ok, writeErr = M.writeFile(inputFile, data or "", "wb")
  if not ok then
    M.removeFile(inputFile)
    M.removeFile(outputFile)
    M.removeFile(stderrFile)
    return nil, "write md5 input failed: " .. tostring(writeErr)
  end

  if not M.commandExists("md5sum") then
    M.removeFile(inputFile)
    M.removeFile(outputFile)
    M.removeFile(stderrFile)
    return nil, "md5sum is not available in PATH"
  end

  local command = string.format(
    "md5sum %s >%s 2>%s",
    M.shellQuote(inputFile),
    M.shellQuote(outputFile),
    M.shellQuote(stderrFile)
  )
  local execOk, why, code = os.execute(command)
  local exitCode = M.parseExecResult(execOk, why, code)

  local output = M.readFile(outputFile, "rb") or ""
  local stderr = M.readFile(stderrFile, "rb") or ""

  M.removeFile(inputFile)
  M.removeFile(outputFile)
  M.removeFile(stderrFile)

  if exitCode ~= 0 then
    return nil, string.format("md5sum exit=%d stderr=%s", exitCode, stderr:gsub("%s+$", ""))
  end

  local digest = output:match("^([0-9a-fA-F]+)")
  if not digest or #digest ~= 32 then
    return nil, "unexpected md5sum output"
  end

  return digest:lower(), nil
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
