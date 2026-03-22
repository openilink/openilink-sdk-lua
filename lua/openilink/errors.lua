local M = {}

local function stringify(tbl)
  return tbl.message
end

function M.apiError(ret, errCode, errMsg)
  local e = {
    kind = "APIError",
    ret = ret or 0,
    errCode = errCode or 0,
    errMsg = errMsg or "",
  }
  e.message = string.format("ilink: api error ret=%s errcode=%s errmsg=%s", tostring(e.ret), tostring(e.errCode), e.errMsg)
  return setmetatable(e, { __tostring = stringify })
end

function M.httpError(statusCode, body)
  local e = {
    kind = "HTTPError",
    statusCode = statusCode,
    body = body or "",
  }
  e.message = string.format("ilink: http %s: %s", tostring(statusCode), e.body)
  return setmetatable(e, { __tostring = stringify })
end

function M.timeoutError(message)
  local e = {
    kind = "TimeoutError",
    message = message or "ilink: timeout",
  }
  return setmetatable(e, { __tostring = stringify })
end

function M.runtimeError(message)
  local e = {
    kind = "RuntimeError",
    message = message,
  }
  return setmetatable(e, { __tostring = stringify })
end

M.ErrNoContextToken = setmetatable({
  kind = "ErrNoContextToken",
  message = "ilink: no cached context token; user must send a message first",
}, { __tostring = stringify })

function M.isSessionExpired(err)
  if type(err) ~= "table" then
    return false
  end
  if err.kind ~= "APIError" then
    return false
  end
  return err.errCode == -14 or err.ret == -14
end

return M
