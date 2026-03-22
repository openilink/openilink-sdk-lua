local util = require("openilink.util")

local M = {}
M.null = {}

local escapeMap = {
  ['"'] = '\\"',
  ['\\'] = '\\\\',
  ['\b'] = '\\b',
  ['\f'] = '\\f',
  ['\n'] = '\\n',
  ['\r'] = '\\r',
  ['\t'] = '\\t',
}

local function encodeString(s)
  return '"' .. s:gsub('[%z\1-\31\\"]', function(c)
    return escapeMap[c] or string.format("\\u%04x", string.byte(c))
  end) .. '"'
end

local function encodeValue(value)
  local t = type(value)
  if value == nil or value == M.null then
    return "null"
  elseif t == "boolean" then
    return value and "true" or "false"
  elseif t == "number" then
    if value ~= value or value == math.huge or value == -math.huge then
      error("json: invalid number")
    end
    return tostring(value)
  elseif t == "string" then
    return encodeString(value)
  elseif t == "table" then
    if util.isArray(value) then
      local out = {}
      for i = 1, #value do
        out[#out + 1] = encodeValue(value[i])
      end
      return "[" .. table.concat(out, ",") .. "]"
    end

    local out = {}
    for k, v in pairs(value) do
      if type(k) ~= "string" then
        error("json: object keys must be strings")
      end
      out[#out + 1] = encodeString(k) .. ":" .. encodeValue(v)
    end
    return "{" .. table.concat(out, ",") .. "}"
  end

  error("json: unsupported type " .. t)
end

function M.encode(value)
  return encodeValue(value)
end

local function decoder(str)
  local i = 1
  local len = #str

  local function skipWs()
    while i <= len do
      local c = str:sub(i, i)
      if c == " " or c == "\t" or c == "\n" or c == "\r" then
        i = i + 1
      else
        break
      end
    end
  end

  local parseValue

  local function parseString()
    i = i + 1
    local out = {}
    while i <= len do
      local c = str:sub(i, i)
      if c == '"' then
        i = i + 1
        return table.concat(out)
      end
      if c == "\\" then
        local esc = str:sub(i + 1, i + 1)
        if esc == '"' or esc == "\\" or esc == "/" then
          out[#out + 1] = esc
          i = i + 2
        elseif esc == "b" then
          out[#out + 1] = "\b"
          i = i + 2
        elseif esc == "f" then
          out[#out + 1] = "\f"
          i = i + 2
        elseif esc == "n" then
          out[#out + 1] = "\n"
          i = i + 2
        elseif esc == "r" then
          out[#out + 1] = "\r"
          i = i + 2
        elseif esc == "t" then
          out[#out + 1] = "\t"
          i = i + 2
        elseif esc == "u" then
          local hex = str:sub(i + 2, i + 5)
          if not hex:match("^%x%x%x%x$") then
            error("json: invalid unicode escape at position " .. i)
          end
          local code = tonumber(hex, 16)
          if code <= 0x7F then
            out[#out + 1] = string.char(code)
          elseif code <= 0x7FF then
            local b1 = 0xC0 + math.floor(code / 0x40)
            local b2 = 0x80 + (code % 0x40)
            out[#out + 1] = string.char(b1, b2)
          else
            local b1 = 0xE0 + math.floor(code / 0x1000)
            local b2 = 0x80 + (math.floor(code / 0x40) % 0x40)
            local b3 = 0x80 + (code % 0x40)
            out[#out + 1] = string.char(b1, b2, b3)
          end
          i = i + 6
        else
          error("json: invalid escape at position " .. i)
        end
      else
        out[#out + 1] = c
        i = i + 1
      end
    end

    error("json: unterminated string")
  end

  local function parseNumber()
    local startPos = i
    if str:sub(i, i) == "-" then
      i = i + 1
    end

    if str:sub(i, i) == "0" then
      i = i + 1
    else
      if not str:sub(i, i):match("%d") then
        error("json: invalid number at position " .. i)
      end
      while str:sub(i, i):match("%d") do
        i = i + 1
      end
    end

    if str:sub(i, i) == "." then
      i = i + 1
      if not str:sub(i, i):match("%d") then
        error("json: invalid fraction at position " .. i)
      end
      while str:sub(i, i):match("%d") do
        i = i + 1
      end
    end

    local e = str:sub(i, i)
    if e == "e" or e == "E" then
      i = i + 1
      local sign = str:sub(i, i)
      if sign == "+" or sign == "-" then
        i = i + 1
      end
      if not str:sub(i, i):match("%d") then
        error("json: invalid exponent at position " .. i)
      end
      while str:sub(i, i):match("%d") do
        i = i + 1
      end
    end

    local raw = str:sub(startPos, i - 1)
    return tonumber(raw)
  end

  local function parseArray()
    i = i + 1
    skipWs()
    local arr = {}
    if str:sub(i, i) == "]" then
      i = i + 1
      return arr
    end

    while true do
      arr[#arr + 1] = parseValue()
      skipWs()
      local c = str:sub(i, i)
      if c == "]" then
        i = i + 1
        return arr
      elseif c == "," then
        i = i + 1
        skipWs()
      else
        error("json: expected ',' or ']' at position " .. i)
      end
    end
  end

  local function parseObject()
    i = i + 1
    skipWs()
    local obj = {}
    if str:sub(i, i) == "}" then
      i = i + 1
      return obj
    end

    while true do
      if str:sub(i, i) ~= '"' then
        error("json: expected object key at position " .. i)
      end
      local key = parseString()
      skipWs()
      if str:sub(i, i) ~= ":" then
        error("json: expected ':' at position " .. i)
      end
      i = i + 1
      skipWs()
      obj[key] = parseValue()
      skipWs()
      local c = str:sub(i, i)
      if c == "}" then
        i = i + 1
        return obj
      elseif c == "," then
        i = i + 1
        skipWs()
      else
        error("json: expected ',' or '}' at position " .. i)
      end
    end
  end

  local function parseLiteral(token, value)
    if str:sub(i, i + #token - 1) ~= token then
      error("json: invalid token at position " .. i)
    end
    i = i + #token
    return value
  end

  parseValue = function()
    skipWs()
    local c = str:sub(i, i)
    if c == '"' then
      return parseString()
    elseif c == "{" then
      return parseObject()
    elseif c == "[" then
      return parseArray()
    elseif c == "t" then
      return parseLiteral("true", true)
    elseif c == "f" then
      return parseLiteral("false", false)
    elseif c == "n" then
      return parseLiteral("null", M.null)
    else
      return parseNumber()
    end
  end

  local value = parseValue()
  skipWs()
  if i <= len then
    error("json: trailing data at position " .. i)
  end
  return value
end

function M.decode(str)
  if type(str) ~= "string" then
    error("json: input must be string")
  end
  return decoder(str)
end

return M
