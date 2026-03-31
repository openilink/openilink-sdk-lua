local util = require("openilink.util")
local errors = require("openilink.errors")

local M = {}

local function parseHeaders(raw)
  local blocks = {}
  local current = nil

  for line in (raw or ""):gmatch("[^\r\n]+") do
    if line:match("^HTTP/%d") then
      current = {
        status = tonumber(line:match("%s(%d%d%d)%s")) or tonumber(line:match("%s(%d%d%d)$")),
        headers = {},
      }
      blocks[#blocks + 1] = current
    else
      local k, v = line:match("^([^:]+):%s*(.*)$")
      if k and current then
        current.headers[k:lower()] = v
      end
    end
  end

  local last = blocks[#blocks]
  if not last then
    return nil, {}
  end
  return last.status, last.headers
end

local CurlAdapter = {}
CurlAdapter.__index = CurlAdapter

function CurlAdapter.new()
  return setmetatable({}, CurlAdapter)
end

function CurlAdapter:request(opts)
  local method = opts.method or "GET"
  local url = assert(opts.url, "http request url is required")
  local headers = opts.headers or {}
  local timeoutMs = opts.timeoutMs or 15000
  local timeoutSec = math.max(1, math.ceil(timeoutMs / 1000))

  local responseHeaderFile = os.tmpname()
  local responseBodyFile = os.tmpname()
  local stderrFile = os.tmpname()
  local requestBodyFile = nil

  local cmdParts = {
    "curl",
    "-sS",
    "-X", method,
    "-m", tostring(timeoutSec),
    "-D", util.shellQuote(responseHeaderFile),
    "-o", util.shellQuote(responseBodyFile),
  }

  for k, v in pairs(headers) do
    cmdParts[#cmdParts + 1] = "-H"
    cmdParts[#cmdParts + 1] = util.shellQuote(string.format("%s: %s", k, v))
  end

  if opts.body then
    requestBodyFile = os.tmpname()
    local ok, writeErr = util.writeFile(requestBodyFile, opts.body, "wb")
    if not ok then
      util.removeFile(responseHeaderFile)
      util.removeFile(responseBodyFile)
      util.removeFile(stderrFile)
      return nil, errors.runtimeError("ilink: write request body failed: " .. tostring(writeErr))
    end
    cmdParts[#cmdParts + 1] = "--data-binary"
    cmdParts[#cmdParts + 1] = "@" .. util.shellQuote(requestBodyFile)
  end

  cmdParts[#cmdParts + 1] = util.shellQuote(url)
  local command = table.concat(cmdParts, " ") .. " 2>" .. util.shellQuote(stderrFile)

  local ok, why, code = os.execute(command)
  local exitCode = util.parseExecResult(ok, why, code)

  local headerRaw = util.readFile(responseHeaderFile, "rb") or ""
  local body = util.readFile(responseBodyFile, "rb") or ""
  local stderr = util.readFile(stderrFile, "rb") or ""

  util.removeFile(responseHeaderFile)
  util.removeFile(responseBodyFile)
  util.removeFile(stderrFile)
  util.removeFile(requestBodyFile)

  if exitCode ~= 0 then
    if exitCode == 28 then
      return nil, errors.timeoutError("ilink: request timeout")
    end
    return nil, errors.runtimeError(string.format("ilink: curl exit=%d stderr=%s", exitCode, stderr:gsub("%s+$", "")))
  end

  local status, parsedHeaders = parseHeaders(headerRaw)
  if not status then
    return nil, errors.runtimeError("ilink: cannot parse response status from curl output")
  end

  return {
    status = status,
    body = body,
    headers = parsedHeaders,
  }, nil
end

M.CurlAdapter = CurlAdapter

function M.newCurlAdapter()
  return CurlAdapter.new()
end

return M
