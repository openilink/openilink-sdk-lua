package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

local Client = require("openilink.client")

local mock = { calls = {} }

function mock:request(opts)
  self.calls[#self.calls + 1] = opts

  if opts.url:find("/ilink/bot/sendmessage", 1, true) then
    return { status = 200, body = '{"ret":0}', headers = {} }, nil
  end

  if opts.url:find("/ilink/bot/getupdates", 1, true) then
    return {
      status = 200,
      body = '{"ret":0,"msgs":[],"get_updates_buf":"buf-2","longpolling_timeout_ms":31000}',
      headers = {},
    }, nil
  end

  return { status = 200, body = "{}", headers = {} }, nil
end

local client = Client.new("test-token", {
  baseURL = "https://example.test",
  httpAdapter = mock,
})

local clientID, sendErr = client:sendText("userA", "hello", "ctx-1")
assert(clientID and not sendErr, "sendText should succeed")

local pushID, pushErr = client:push("userA", "hi")
assert(pushID == nil and pushErr, "push without context token should fail")

client:setContextToken("userA", "ctx-2")
local pushOK, pushErr2 = client:push("userA", "hi again")
assert(pushOK and not pushErr2, "push with context token should succeed")

local updates, updatesErr = client:getUpdates("buf-1", 1000)
assert(updates and not updatesErr, "getUpdates should succeed")
assert(updates.get_updates_buf == "buf-2", "getUpdates buffer mismatch")

return true
