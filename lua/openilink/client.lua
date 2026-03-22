local constants = require("openilink.constants")
local util = require("openilink.util")
local json = require("openilink.json")
local http = require("openilink.http")
local errors = require("openilink.errors")
local media = require("openilink.media")

local Client = {}
Client.__index = Client

local function pick(tableLike, ...)
  if type(tableLike) ~= "table" then
    return nil
  end
  for i = 1, select("#", ...) do
    local key = select(i, ...)
    if tableLike[key] ~= nil then
      return tableLike[key]
    end
  end
  return nil
end

local function callCallback(callbacks, camel, pascal, ...)
  if type(callbacks) ~= "table" then
    return
  end
  local fn = callbacks[camel] or callbacks[pascal]
  if type(fn) == "function" then
    fn(...)
  end
end

function Client.new(token, opts)
  opts = opts or {}

  local self = setmetatable({
    baseURL = opts.baseURL or opts.base_url or constants.DefaultBaseURL,
    cdnBaseURL = opts.cdnBaseURL or opts.cdn_base_url or constants.DefaultCDNBaseURL,
    token = token or "",
    botType = opts.botType or opts.bot_type or constants.DefaultBotType,
    version = opts.version or constants.DefaultVersion,
    routeTag = opts.routeTag or opts.route_tag,
    httpAdapter = opts.httpAdapter or opts.http_adapter or http.newCurlAdapter(),
    json = opts.json or json,
    contextTokens = {},
  }, Client)

  return self
end

function Client:setToken(token)
  self.token = token or ""
end

function Client:setBaseURL(baseURL)
  self.baseURL = baseURL
end

function Client:getToken()
  return self.token
end

function Client:getBaseURL()
  return self.baseURL
end

function Client:_buildBaseInfo()
  return { channel_version = self.version }
end

function Client:_buildHeaders(body)
  local headers = {
    ["Content-Type"] = "application/json",
    ["AuthorizationType"] = "ilink_bot_token",
    ["Content-Length"] = tostring(#body),
    ["X-WECHAT-UIN"] = util.randomWechatUIN(),
  }

  if self.token and self.token ~= "" then
    headers["Authorization"] = "Bearer " .. self.token
  end
  if self.routeTag and self.routeTag ~= "" then
    headers["SKRouteTag"] = self.routeTag
  end

  return headers
end

function Client:_routeTagHeaders()
  local headers = {}
  if self.routeTag and self.routeTag ~= "" then
    headers["SKRouteTag"] = self.routeTag
  end
  return headers
end

function Client:_decodeJSON(data, label)
  local ok, decoded = pcall(self.json.decode, data)
  if not ok then
    return nil, errors.runtimeError(string.format("ilink: decode %s response failed: %s", label, tostring(decoded)))
  end
  return decoded, nil
end

function Client:_doPost(endpoint, bodyTable, timeoutMs)
  local ok, bodyOrErr = pcall(self.json.encode, bodyTable)
  if not ok then
    return nil, errors.runtimeError("ilink: encode request failed: " .. tostring(bodyOrErr))
  end
  local body = bodyOrErr
  local url = util.joinURL(self.baseURL, endpoint)
  local resp, err = self.httpAdapter:request({
    method = "POST",
    url = url,
    headers = self:_buildHeaders(body),
    body = body,
    timeoutMs = timeoutMs,
  })
  if not resp then
    return nil, err
  end
  if resp.status < 200 or resp.status >= 300 then
    return nil, errors.httpError(resp.status, resp.body)
  end
  return resp.body, nil
end

function Client:_doGet(url, headers, timeoutMs)
  local resp, err = self.httpAdapter:request({
    method = "GET",
    url = url,
    headers = headers or {},
    timeoutMs = timeoutMs,
  })
  if not resp then
    return nil, err
  end
  if resp.status < 200 or resp.status >= 300 then
    return nil, errors.httpError(resp.status, resp.body)
  end
  return resp.body, nil
end

function Client:getUpdates(getUpdatesBuf, timeoutMs)
  local reqBody = {
    get_updates_buf = getUpdatesBuf or "",
    base_info = self:_buildBaseInfo(),
  }

  local timeout = constants.DefaultLongPollTimeoutMs
  if tonumber(timeoutMs) and tonumber(timeoutMs) > 0 then
    timeout = tonumber(timeoutMs)
  end

  local data, err = self:_doPost("ilink/bot/getupdates", reqBody, timeout)
  if not data then
    if err and err.kind == "TimeoutError" then
      return {
        ret = 0,
        msgs = {},
        get_updates_buf = getUpdatesBuf or "",
      }, nil
    end
    return nil, err
  end

  return self:_decodeJSON(data, "getUpdates")
end

function Client:sendMessage(msg)
  msg.base_info = self:_buildBaseInfo()

  local data, err = self:_doPost("ilink/bot/sendmessage", msg, constants.DefaultAPITimeoutMs)
  if not data then
    return nil, err
  end

  if data == "" then
    return true, nil
  end

  local decoded, decErr = self:_decodeJSON(data, "sendMessage")
  if decErr then
    return nil, decErr
  end
  local ret = decoded.ret or 0
  local errCode = decoded.errcode or 0
  if ret ~= 0 or errCode ~= 0 then
    return nil, errors.apiError(ret, errCode, decoded.errmsg or "")
  end
  return true, nil
end

function Client:sendText(to, text, contextToken)
  local clientID = util.generateClientID()
  local msg = {
    msg = {
      to_user_id = to,
      client_id = clientID,
      message_type = constants.MsgTypeBot,
      message_state = constants.StateFinish,
      context_token = contextToken,
      item_list = {
        {
          type = constants.ItemText,
          text_item = { text = text },
        },
      },
    },
  }

  local ok, err = self:sendMessage(msg)
  if not ok then
    return nil, err
  end
  return clientID, nil
end

function Client:getConfig(userID, contextToken)
  local reqBody = {
    ilink_user_id = userID,
    context_token = contextToken,
    base_info = self:_buildBaseInfo(),
  }

  local data, err = self:_doPost("ilink/bot/getconfig", reqBody, constants.DefaultConfigTimeoutMs)
  if not data then
    return nil, err
  end

  local decoded, decErr = self:_decodeJSON(data, "getConfig")
  if decErr then
    return nil, decErr
  end

  local ret = decoded.ret or 0
  local errCode = decoded.errcode or 0
  if ret ~= 0 or errCode ~= 0 then
    return nil, errors.apiError(ret, errCode, decoded.errmsg or "")
  end

  return decoded, nil
end

function Client:sendTyping(userID, typingTicket, status)
  local reqBody = {
    ilink_user_id = userID,
    typing_ticket = typingTicket,
    status = status,
    base_info = self:_buildBaseInfo(),
  }

  local data, err = self:_doPost("ilink/bot/sendtyping", reqBody, constants.DefaultConfigTimeoutMs)
  if not data then
    return nil, err
  end

  if data == "" then
    return true, nil
  end

  local decoded, decErr = self:_decodeJSON(data, "sendTyping")
  if decErr then
    return nil, decErr
  end

  local ret = decoded.ret or 0
  local errCode = decoded.errcode or 0
  if ret ~= 0 or errCode ~= 0 then
    return nil, errors.apiError(ret, errCode, decoded.errmsg or "")
  end

  return true, nil
end

function Client:getUploadURL(req)
  req.base_info = self:_buildBaseInfo()
  local data, err = self:_doPost("ilink/bot/getuploadurl", req, constants.DefaultAPITimeoutMs)
  if not data then
    return nil, err
  end
  local decoded, decErr = self:_decodeJSON(data, "getUploadURL")
  if decErr then
    return nil, decErr
  end
  if (decoded.ret or 0) ~= 0 then
    return nil, errors.apiError(decoded.ret, decoded.errcode or 0, decoded.errmsg or "")
  end
  return decoded, nil
end

function Client:fetchQRCode()
  local botType = self.botType
  if not botType or botType == "" then
    botType = constants.DefaultBotType
  end

  local url = util.joinURL(self.baseURL, "ilink/bot/get_bot_qrcode") .. "?bot_type=" .. util.urlEncode(botType)
  local headers = self:_routeTagHeaders()

  local data, err = self:_doGet(url, headers, constants.DefaultAPITimeoutMs)
  if not data then
    return nil, err
  end
  return self:_decodeJSON(data, "fetchQRCode")
end

function Client:pollQRStatus(qrcode)
  local url = util.joinURL(self.baseURL, "ilink/bot/get_qrcode_status") .. "?qrcode=" .. util.urlEncode(qrcode)
  local headers = self:_routeTagHeaders()
  headers["iLink-App-ClientVersion"] = "1"

  local data, err = self:_doGet(url, headers, constants.QRLongPollTimeoutMs)
  if not data then
    if err and err.kind == "TimeoutError" then
      return { status = "wait" }, nil
    end
    return nil, err
  end
  return self:_decodeJSON(data, "pollQRStatus")
end

function Client:loginWithQR(callbacks, opts)
  callbacks = callbacks or {}
  opts = opts or {}

  local timeoutSec = opts.timeoutSec or opts.timeout_sec or constants.DefaultLoginTimeoutSec
  local start = os.time()

  local qr, err = self:fetchQRCode()
  if not qr then
    return nil, err
  end

  callCallback(callbacks, "onQRCode", "OnQRCode", qr.qrcode_img_content)

  local scannedNotified = false
  local refreshCount = 1
  local currentQR = qr.qrcode

  while (os.time() - start) < timeoutSec do
    local status, pollErr = self:pollQRStatus(currentQR)
    if not status then
      return nil, pollErr
    end

    if status.status == "wait" then
      -- keep polling
    elseif status.status == "scaned" then
      if not scannedNotified then
        scannedNotified = true
        callCallback(callbacks, "onScanned", "OnScanned")
      end
    elseif status.status == "expired" then
      refreshCount = refreshCount + 1
      if refreshCount > constants.MaxQRRefreshCount then
        return {
          connected = false,
          message = "QR code expired too many times",
        }, nil
      end

      callCallback(callbacks, "onExpired", "OnExpired", refreshCount, constants.MaxQRRefreshCount)
      local newQR, qrErr = self:fetchQRCode()
      if not newQR then
        return nil, qrErr
      end
      currentQR = newQR.qrcode
      scannedNotified = false
      callCallback(callbacks, "onQRCode", "OnQRCode", newQR.qrcode_img_content)
    elseif status.status == "confirmed" then
      if not status.ilink_bot_id or status.ilink_bot_id == "" then
        return {
          connected = false,
          message = "server did not return bot ID",
        }, nil
      end

      self:setToken(status.bot_token)
      if status.baseurl and status.baseurl ~= "" then
        self:setBaseURL(status.baseurl)
      end

      return {
        connected = true,
        bot_token = status.bot_token,
        bot_id = status.ilink_bot_id,
        base_url = status.baseurl,
        user_id = status.ilink_user_id,
        message = "connected",
      }, nil
    end

    util.sleepSeconds(1)
  end

  return {
    connected = false,
    message = "login timeout",
  }, nil
end

function Client:setContextToken(userID, token)
  self.contextTokens[userID] = token
end

function Client:getContextToken(userID)
  return self.contextTokens[userID]
end

function Client:push(to, text)
  local contextToken = self:getContextToken(to)
  if not contextToken then
    return nil, errors.ErrNoContextToken
  end
  return self:sendText(to, text, contextToken)
end

function Client:monitor(handler, opts)
  opts = opts or {}

  local buf = pick(opts, "initialBuf", "InitialBuf", "initial_buf") or ""
  local failures = 0
  local nextTimeoutMs = nil

  local onError = pick(opts, "onError", "OnError", "on_error")
  if type(onError) ~= "function" then
    onError = function() end
  end

  local onBufUpdate = pick(opts, "onBufUpdate", "OnBufUpdate", "on_buf_update")
  local onSessionExpired = pick(opts, "onSessionExpired", "OnSessionExpired", "on_session_expired")
  local shouldStop = pick(opts, "shouldStop", "ShouldStop", "should_stop")

  while true do
    local sleepSeconds = 0

    if type(shouldStop) == "function" and shouldStop() then
      return true, nil
    end

    local resp, err = self:getUpdates(buf, nextTimeoutMs)
    if not resp then
      failures = failures + 1
      onError(errors.runtimeError(string.format("getUpdates (%d/%d): %s", failures, constants.MaxConsecutiveFailures, tostring(err))))

      if failures >= constants.MaxConsecutiveFailures then
        failures = 0
        sleepSeconds = constants.BackoffDelaySec
      else
        sleepSeconds = constants.RetryDelaySec
      end
    else
      if (resp.longpolling_timeout_ms or 0) > 0 then
        nextTimeoutMs = resp.longpolling_timeout_ms
      end

      local ret = resp.ret or 0
      local errCode = resp.errcode or 0
      if ret ~= 0 or errCode ~= 0 then
        local apiErr = errors.apiError(ret, errCode, resp.errmsg or "")
        if errors.isSessionExpired(apiErr) then
          if type(onSessionExpired) == "function" then
            onSessionExpired()
          end
          onError(apiErr)
          failures = 0
          sleepSeconds = 3600
        else
          failures = failures + 1
          onError(errors.runtimeError(string.format("getUpdates (%d/%d): %s", failures, constants.MaxConsecutiveFailures, tostring(apiErr))))
          if failures >= constants.MaxConsecutiveFailures then
            failures = 0
            sleepSeconds = constants.BackoffDelaySec
          else
            sleepSeconds = constants.RetryDelaySec
          end
        end
      else
        failures = 0

        if resp.get_updates_buf and resp.get_updates_buf ~= "" then
          buf = resp.get_updates_buf
          if type(onBufUpdate) == "function" then
            onBufUpdate(buf)
          end
        end

        for _, msg in ipairs(resp.msgs or {}) do
          if msg.context_token and msg.from_user_id then
            self:setContextToken(msg.from_user_id, msg.context_token)
          end

          local ok, callbackErr = pcall(handler, msg)
          if not ok then
            onError(errors.runtimeError("ilink: monitor handler panic: " .. tostring(callbackErr)))
          end
        end
      end
    end

    if sleepSeconds > 0 then
      util.sleepSeconds(sleepSeconds)
    end
  end
end

media.extendClient(Client)

return Client
