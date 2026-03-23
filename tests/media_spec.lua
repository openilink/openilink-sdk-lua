package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

local Client = require("openilink.client")
local json = require("openilink.json")

local function newMockAdapter()
  local mock = {
    calls = {},
    fileName = nil,
  }

  function mock:request(opts)
    self.calls[#self.calls + 1] = opts
    if opts.url:find("/ilink/bot/sendmessage", 1, true) then
      local payload = assert(json.decode(opts.body), "sendmessage payload decode failed")
      local item = payload.msg and payload.msg.item_list and payload.msg.item_list[1]
      if item and item.file_item then
        self.fileName = item.file_item.file_name
      end
      return { status = 200, body = '{"ret":0}', headers = {} }, nil
    end
    return { status = 200, body = "{}", headers = {} }, nil
  end

  return mock
end

local function withStubUpload(client)
  function client:uploadFile(_data, _to, _mediaType)
    return {
      download_encrypted_query_param = "qparam",
      aes_key = "00112233445566778899aabbccddeeff",
      file_size = 12,
      ciphertext_size = 16,
    }, nil
  end
end

do
  local mock = newMockAdapter()
  local client = Client.new("token", {
    baseURL = "https://example.test",
    httpAdapter = mock,
  })
  withStubUpload(client)

  local clientID, err = client:sendMediaFile("u1", "ctx1", "file-data", "folder/sub/report.pdf", "")
  assert(clientID and not err, "sendMediaFile default mode should succeed")
  assert(mock.fileName == "folder/sub/report.pdf", "default behavior should preserve original file_name")
end

do
  local mock = newMockAdapter()
  local client = Client.new("token", {
    baseURL = "https://example.test",
    httpAdapter = mock,
    useBasenameForAttachmentName = true,
  })
  withStubUpload(client)

  local clientID, err = client:sendMediaFile("u2", "ctx2", "file-data", "folder/sub/report.pdf", "")
  assert(clientID and not err, "sendMediaFile basename mode should succeed")
  assert(mock.fileName == "report.pdf", "basename mode should use file base name")
end

do
  local mock = newMockAdapter()
  local client = Client.new("token", {
    baseURL = "https://example.test",
    httpAdapter = mock,
  })
  withStubUpload(client)
  client:setUseBasenameForAttachmentName(true)

  local clientID, err = client:sendMediaFile("u3", "ctx3", "file-data", "foo\\bar\\a.txt", "")
  assert(clientID and not err, "sendMediaFile should succeed after setter toggle")
  assert(mock.fileName == "a.txt", "setter should enable basename behavior")
end

return true
