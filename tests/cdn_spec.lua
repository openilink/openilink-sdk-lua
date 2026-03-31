package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

local Client = require("openilink.client")
local cdn = require("openilink.cdn")
local constants = require("openilink.constants")
local json = require("openilink.json")

do
  local key = string.char(0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15)
  local payloads = {
    "",
    "hello",
    string.rep("x", 16),
    string.rep("y", 37),
  }

  for _, payload in ipairs(payloads) do
    local ciphertext, encErr = cdn.EncryptAESECB(payload, key)
    assert(ciphertext and not encErr, "EncryptAESECB should succeed")
    assert(#ciphertext == cdn.AESECBPaddedSize(#payload), "AESECBPaddedSize mismatch")

    local plaintext, decErr = cdn.DecryptAESECB(ciphertext, key)
    assert(plaintext and not decErr, "DecryptAESECB should succeed")
    assert(plaintext == payload, "AES round trip mismatch")
  end

  local rawKey = string.char(16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1)
  local rawDecoded, rawErr = cdn.ParseAESKey(require("openilink.util").base64Encode(rawKey))
  assert(rawDecoded and not rawErr and rawDecoded == rawKey, "ParseAESKey raw format mismatch")

  local hexEncoded = require("openilink.util").base64Encode("00112233445566778899aabbccddeeff")
  local hexDecoded, hexErr = cdn.ParseAESKey(hexEncoded)
  assert(hexDecoded and not hexErr, "ParseAESKey hex format mismatch")
  assert(#hexDecoded == 16, "ParseAESKey hex output size mismatch")
end

do
  local uploadRequests = {}
  local downloadKey = string.char(0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15)
  local ciphertext = assert(cdn.EncryptAESECB("download-body", downloadKey))

  local mock = {}

  function mock:request(opts)
    uploadRequests[#uploadRequests + 1] = opts

    if opts.url:find("/ilink/bot/getuploadurl", 1, true) then
      local body = json.decode(opts.body)
      assert(body.media_type == constants.MediaFile, "upload media_type mismatch")
      assert(body.no_need_thumb == true, "upload no_need_thumb mismatch")
      return {
        status = 200,
        body = '{"ret":0,"upload_full_url":"https://upload.example.test/direct"}',
        headers = {},
      }, nil
    end

    if opts.url == "https://upload.example.test/direct" then
      assert(opts.headers["Content-Type"] == "application/octet-stream", "CDN upload content type mismatch")
      return {
        status = 200,
        body = "",
        headers = {
          ["x-encrypted-param"] = "download-param",
        },
      }, nil
    end

    if opts.url == "https://cdn.example.test/raw" then
      return {
        status = 200,
        body = ciphertext,
        headers = {},
      }, nil
    end

    error("unexpected url: " .. tostring(opts.url))
  end

  local client = Client.new("token", {
    baseURL = "https://api.example.test",
    cdnBaseURL = "https://cdn.example.test",
    httpAdapter = mock,
  })

  local uploaded, uploadErr = client:uploadFile("hello upload", "user-a", constants.MediaFile)
  assert(uploaded and not uploadErr, "uploadFile should succeed")
  assert(uploaded.download_encrypted_query_param == "download-param", "uploadFile download param mismatch")
  assert(uploaded.file_size == #"hello upload", "uploadFile raw size mismatch")
  assert(uploadRequests[2].url == "https://upload.example.test/direct", "upload_full_url should be preferred")

  local plaintext, downloadErr = client:downloadMedia({
    full_url = "https://cdn.example.test/raw",
    aes_key = require("openilink.util").base64Encode(downloadKey),
  })
  assert(plaintext and not downloadErr, "downloadMedia should succeed")
  assert(plaintext == "download-body", "downloadMedia decrypt mismatch")
end

return true
