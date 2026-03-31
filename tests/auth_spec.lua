package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

local Client = require("openilink.client")
local errors = require("openilink.errors")

do
  local mock = {
    calls = {},
    pollCount = 0,
  }

  function mock:request(opts)
    self.calls[#self.calls + 1] = opts

    if opts.url:find("get_bot_qrcode", 1, true) then
      assert(opts.url:find("https://login.example.test/", 1, true), "fetchQRCode should use loginBaseURL")
      return {
        status = 200,
        body = '{"qrcode":"qr-1","qrcode_img_content":"img-1"}',
        headers = {},
      }, nil
    end

    if opts.url:find("https://login.example.test/", 1, true) then
      self.pollCount = self.pollCount + 1
      return {
        status = 200,
        body = '{"status":"scaned_but_redirect","redirect_host":"poll.example.test"}',
        headers = {},
      }, nil
    end

    if opts.url:find("https://poll.example.test/", 1, true) then
      return {
        status = 200,
        body = '{"status":"confirmed","bot_token":"bot-token","ilink_bot_id":"bot-id","baseurl":"https://api-session.example.test","ilink_user_id":"user-1"}',
        headers = {},
      }, nil
    end

    error("unexpected url: " .. tostring(opts.url))
  end

  local client = Client.new("", {
    baseURL = "https://api.example.test",
    loginBaseURL = "https://login.example.test",
    httpAdapter = mock,
  })

  local seenQRCode = nil
  local result, err = client:loginWithQR({
    onQRCode = function(img) seenQRCode = img end,
  }, {
    timeoutSec = 2,
  })

  assert(result and not err, "loginWithQR should succeed")
  assert(result.connected == true, "loginWithQR connected mismatch")
  assert(result.bot_token == "bot-token", "loginWithQR token mismatch")
  assert(result.base_url == "https://api-session.example.test", "loginWithQR base URL mismatch")
  assert(seenQRCode == "img-1", "QR callback mismatch")
  assert(client:getBaseURL() == "https://api-session.example.test", "client baseURL should update after login")
  assert(client:getToken() == "bot-token", "client token should update after login")
end

do
  local mock = {}

  function mock:request(_opts)
    return nil, errors.httpError(500, "boom")
  end

  local client = Client.new("", {
    baseURL = "https://login.example.test",
    httpAdapter = mock,
  })

  local resp, err = client:pollQRStatus("qr-1")
  assert(resp and not err, "pollQRStatus should absorb transport errors")
  assert(resp.status == "wait", "pollQRStatus should return wait on transport error")
end

return true
