local constants = require("openilink.constants")
local util = require("openilink.util")
local errors = require("openilink.errors")

local M = {}

local AESBlockSize = 16

local function bxor(a, b)
  local result = 0
  local bit = 1

  while a > 0 or b > 0 do
    local aBit = a % 2
    local bBit = b % 2
    if aBit ~= bBit then
      result = result + bit
    end
    a = math.floor(a / 2)
    b = math.floor(b / 2)
    bit = bit * 2
  end

  return result
end

local function xorMany(...)
  local result = 0
  for i = 1, select("#", ...) do
    result = bxor(result, select(i, ...))
  end
  return result
end

local function mod(a, b)
  local r = a % b
  if r < 0 then
    r = r + b
  end
  return r
end

local function rotl8(value, shift)
  shift = shift % 8
  if shift == 0 then
    return value
  end
  local left = (value * 2 ^ shift) % 256
  local right = math.floor(value / 2 ^ (8 - shift))
  return left + right
end

local function xtime(value)
  local out = value * 2
  if out >= 256 then
    out = out - 256
    out = bxor(out, 0x1B)
  end
  return out
end

local function gfMul(a, b)
  local result = 0
  while b > 0 do
    if b % 2 == 1 then
      result = bxor(result, a)
    end
    b = math.floor(b / 2)
    a = xtime(a)
  end
  return result
end

local function gfInv(value)
  if value == 0 then
    return 0
  end
  for i = 1, 255 do
    if gfMul(value, i) == 1 then
      return i
    end
  end
  return 0
end

local function buildSBoxes()
  local sbox = {}
  local invSBox = {}

  for value = 0, 255 do
    local inv = gfInv(value)
    local transformed = xorMany(inv, rotl8(inv, 1), rotl8(inv, 2), rotl8(inv, 3), rotl8(inv, 4), 0x63)
    sbox[value + 1] = transformed
    invSBox[transformed + 1] = value
  end

  return sbox, invSBox
end

local SBox, InvSBox = buildSBoxes()
local Rcon = {}
do
  local value = 1
  for i = 1, 10 do
    Rcon[i] = value
    value = xtime(value)
  end
end

local function toBytes(data)
  local bytes = {}
  for i = 1, #data do
    bytes[i] = string.byte(data, i)
  end
  return bytes
end

local function fromBytes(bytes)
  local out = {}
  for i = 1, #bytes do
    out[i] = string.char(bytes[i])
  end
  return table.concat(out)
end

local function subBytes(state, box)
  local out = {}
  for i = 1, #state do
    out[i] = box[state[i] + 1]
  end
  return out
end

local function shiftRows(state)
  local out = {}
  for row = 0, 3 do
    for col = 0, 3 do
      out[col * 4 + row + 1] = state[((col + row) % 4) * 4 + row + 1]
    end
  end
  return out
end

local function invShiftRows(state)
  local out = {}
  for row = 0, 3 do
    for col = 0, 3 do
      out[col * 4 + row + 1] = state[mod(col - row, 4) * 4 + row + 1]
    end
  end
  return out
end

local function mixColumns(state)
  local out = {}

  for col = 0, 3 do
    local index = col * 4 + 1
    local a0 = state[index]
    local a1 = state[index + 1]
    local a2 = state[index + 2]
    local a3 = state[index + 3]

    out[index] = xorMany(gfMul(a0, 2), gfMul(a1, 3), a2, a3)
    out[index + 1] = xorMany(a0, gfMul(a1, 2), gfMul(a2, 3), a3)
    out[index + 2] = xorMany(a0, a1, gfMul(a2, 2), gfMul(a3, 3))
    out[index + 3] = xorMany(gfMul(a0, 3), a1, a2, gfMul(a3, 2))
  end

  return out
end

local function invMixColumns(state)
  local out = {}

  for col = 0, 3 do
    local index = col * 4 + 1
    local a0 = state[index]
    local a1 = state[index + 1]
    local a2 = state[index + 2]
    local a3 = state[index + 3]

    out[index] = xorMany(gfMul(a0, 14), gfMul(a1, 11), gfMul(a2, 13), gfMul(a3, 9))
    out[index + 1] = xorMany(gfMul(a0, 9), gfMul(a1, 14), gfMul(a2, 11), gfMul(a3, 13))
    out[index + 2] = xorMany(gfMul(a0, 13), gfMul(a1, 9), gfMul(a2, 14), gfMul(a3, 11))
    out[index + 3] = xorMany(gfMul(a0, 11), gfMul(a1, 13), gfMul(a2, 9), gfMul(a3, 14))
  end

  return out
end

local function addRoundKey(state, expandedKey, round)
  local out = {}
  local offset = round * AESBlockSize
  for i = 1, AESBlockSize do
    out[i] = bxor(state[i], expandedKey[offset + i])
  end
  return out
end

local function expandKey(key)
  if #key ~= AESBlockSize then
    return nil, errors.runtimeError("ilink: aes key must be exactly 16 bytes")
  end

  local expanded = toBytes(key)
  local bytesGenerated = AESBlockSize
  local rconIndex = 1

  while bytesGenerated < 176 do
    local temp = {
      expanded[bytesGenerated - 3],
      expanded[bytesGenerated - 2],
      expanded[bytesGenerated - 1],
      expanded[bytesGenerated],
    }

    if bytesGenerated % AESBlockSize == 0 then
      temp = { temp[2], temp[3], temp[4], temp[1] }
      for i = 1, 4 do
        temp[i] = SBox[temp[i] + 1]
      end
      temp[1] = bxor(temp[1], Rcon[rconIndex])
      rconIndex = rconIndex + 1
    end

    for i = 1, 4 do
      expanded[bytesGenerated + i] = bxor(expanded[bytesGenerated - AESBlockSize + i], temp[i])
    end
    bytesGenerated = bytesGenerated + 4
  end

  return expanded, nil
end

local function encryptBlock(block, expandedKey)
  local state = addRoundKey(toBytes(block), expandedKey, 0)

  for round = 1, 9 do
    state = subBytes(state, SBox)
    state = shiftRows(state)
    state = mixColumns(state)
    state = addRoundKey(state, expandedKey, round)
  end

  state = subBytes(state, SBox)
  state = shiftRows(state)
  state = addRoundKey(state, expandedKey, 10)

  return fromBytes(state)
end

local function decryptBlock(block, expandedKey)
  local state = addRoundKey(toBytes(block), expandedKey, 10)

  for round = 9, 1, -1 do
    state = invShiftRows(state)
    state = subBytes(state, InvSBox)
    state = addRoundKey(state, expandedKey, round)
    state = invMixColumns(state)
  end

  state = invShiftRows(state)
  state = subBytes(state, InvSBox)
  state = addRoundKey(state, expandedKey, 0)

  return fromBytes(state)
end

local function pkcs7Pad(data)
  local padding = AESBlockSize - (#data % AESBlockSize)
  if padding == 0 then
    padding = AESBlockSize
  end
  return data .. string.rep(string.char(padding), padding)
end

local function pkcs7Unpad(data)
  if #data == 0 then
    return nil, errors.runtimeError("ilink: pkcs7 unpad: empty data")
  end

  local padding = string.byte(data, -1)
  if padding == 0 or padding > AESBlockSize or padding > #data then
    return nil, errors.runtimeError("ilink: pkcs7 unpad: invalid padding " .. tostring(padding))
  end

  for i = #data - padding + 1, #data do
    if string.byte(data, i) ~= padding then
      return nil, errors.runtimeError("ilink: pkcs7 unpad: inconsistent padding")
    end
  end

  return data:sub(1, #data - padding), nil
end

function M.EncryptAESECB(plaintext, key)
  local expandedKey, err = expandKey(key)
  if not expandedKey then
    return nil, err
  end

  local padded = pkcs7Pad(plaintext or "")
  local out = {}
  for i = 1, #padded, AESBlockSize do
    out[#out + 1] = encryptBlock(padded:sub(i, i + AESBlockSize - 1), expandedKey)
  end
  return table.concat(out), nil
end

function M.DecryptAESECB(ciphertext, key)
  local expandedKey, err = expandKey(key)
  if not expandedKey then
    return nil, err
  end

  ciphertext = ciphertext or ""
  if #ciphertext % AESBlockSize ~= 0 then
    return nil, errors.runtimeError("ilink: ciphertext not multiple of block size")
  end

  local out = {}
  for i = 1, #ciphertext, AESBlockSize do
    out[#out + 1] = decryptBlock(ciphertext:sub(i, i + AESBlockSize - 1), expandedKey)
  end

  return pkcs7Unpad(table.concat(out))
end

function M.AESECBPaddedSize(plaintextSize)
  local size = tonumber(plaintextSize) or 0
  return math.floor((size + 1 + AESBlockSize - 1) / AESBlockSize) * AESBlockSize
end

function M.BuildCDNDownloadURL(cdnBaseURL, encryptedQueryParam)
  return tostring(cdnBaseURL) .. "/download?encrypted_query_param=" .. util.urlEncode(encryptedQueryParam)
end

function M.BuildCDNUploadURL(cdnBaseURL, uploadParam, fileKey)
  return tostring(cdnBaseURL) .. "/upload?encrypted_query_param=" .. util.urlEncode(uploadParam)
    .. "&filekey=" .. util.urlEncode(fileKey)
end

function M.ParseAESKey(aesKeyBase64)
  local decoded, err = util.base64DecodeFlexible(aesKeyBase64)
  if not decoded then
    return nil, errors.runtimeError("ilink: decode aes_key: " .. tostring(err))
  end

  if #decoded == AESBlockSize then
    return decoded, nil
  end

  if #decoded == 32 and not decoded:find("[^0-9a-fA-F]") then
    local raw, hexErr = util.hexDecode(decoded)
    if not raw then
      return nil, errors.runtimeError("ilink: decode hex aes_key: " .. tostring(hexErr))
    end
    return raw, nil
  end

  return nil, errors.runtimeError(
    string.format("ilink: aes_key must decode to 16 raw bytes or 32-char hex, got %d bytes", #decoded)
  )
end

local function randomHex(byteCount)
  return util.hexEncode(util.randomBytes(byteCount))
end

local function mediaField(media, ...)
  if type(media) ~= "table" then
    return nil
  end
  for i = 1, select("#", ...) do
    local key = select(i, ...)
    if media[key] ~= nil then
      return media[key]
    end
  end
  return nil
end

local function pickHeader(headers, name)
  if type(headers) ~= "table" then
    return nil
  end
  local lowerName = tostring(name):lower()
  for key, value in pairs(headers) do
    if tostring(key):lower() == lowerName then
      return value
    end
  end
  return nil
end

local function resolveCDNDownloadURL(client, media)
  local fullURL = mediaField(media, "full_url", "FullURL")
  if fullURL and fullURL ~= "" then
    return fullURL, nil
  end

  local queryParam = mediaField(media, "encrypt_query_param", "EncryptQueryParam")
  if queryParam and queryParam ~= "" then
    return M.BuildCDNDownloadURL(client.cdnBaseURL, queryParam), nil
  end

  return nil, errors.runtimeError("ilink: cdn media has no full_url or encrypt_query_param")
end

function M.extendClient(Client)
  function Client:_uploadToCDN(cdnURL, ciphertext)
    local lastErr = nil

    for attempt = 1, constants.UploadMaxRetries do
      local resp, err = self.httpAdapter:request({
        method = "POST",
        url = cdnURL,
        headers = {
          ["Content-Type"] = "application/octet-stream",
        },
        body = ciphertext,
        timeoutMs = constants.DefaultCDNTimeoutMs,
      })

      if resp then
        if resp.status ~= 200 then
          local errMsg = pickHeader(resp.headers, "x-error-message")
          if not errMsg or errMsg == "" then
            errMsg = resp.body or ""
          end
          if not errMsg or errMsg == "" then
            errMsg = "status " .. tostring(resp.status)
          end
          lastErr = errors.httpError(resp.status, errMsg)
          if resp.status >= 400 and resp.status < 500 then
            return nil, lastErr
          end
        else
          local downloadParam = pickHeader(resp.headers, "x-encrypted-param")
          if not downloadParam or downloadParam == "" then
            return nil, errors.runtimeError("ilink: cdn response missing x-encrypted-param header")
          end
          return downloadParam, nil
        end
      else
        lastErr = err
      end

      if attempt < constants.UploadMaxRetries then
        util.sleepSeconds(constants.RetryDelaySec)
      end
    end

    return nil, errors.runtimeError(
      string.format("ilink: cdn upload failed after %d attempts: %s", constants.UploadMaxRetries, tostring(lastErr))
    )
  end

  function Client:uploadFile(plaintext, toUserID, mediaType)
    local rawMD5, md5Err = util.md5Hex(plaintext or "")
    if not rawMD5 then
      return nil, errors.runtimeError("ilink: md5 upload preparation failed: " .. tostring(md5Err))
    end

    local rawSize = #(plaintext or "")
    local fileSize = M.AESECBPaddedSize(rawSize)
    local fileKey = randomHex(16)
    local aesKey = util.randomBytes(16)
    local aesKeyHex = util.hexEncode(aesKey)

    local uploadResp, uploadErr = self:getUploadURL({
      filekey = fileKey,
      media_type = mediaType,
      to_user_id = toUserID,
      rawsize = rawSize,
      rawfilemd5 = rawMD5,
      filesize = fileSize,
      no_need_thumb = true,
      aeskey = aesKeyHex,
    })
    if not uploadResp then
      return nil, errors.runtimeError("ilink: getUploadUrl: " .. tostring(uploadErr))
    end

    if (uploadResp.ret or 0) ~= 0 then
      return nil, errors.apiError(uploadResp.ret or 0, uploadResp.errcode or 0, uploadResp.errmsg or "")
    end

    local uploadFullURL = util.trimString(mediaField(uploadResp, "upload_full_url", "UploadFullURL"))
    local uploadParam = mediaField(uploadResp, "upload_param", "UploadParam")
    local cdnURL = nil
    if uploadFullURL ~= "" then
      cdnURL = uploadFullURL
    elseif uploadParam and uploadParam ~= "" then
      cdnURL = M.BuildCDNUploadURL(self.cdnBaseURL, uploadParam, fileKey)
    else
      return nil, errors.runtimeError(
        "ilink: getUploadUrl returned no upload URL (need upload_full_url or upload_param)"
      )
    end

    local ciphertext, encErr = M.EncryptAESECB(plaintext or "", aesKey)
    if not ciphertext then
      return nil, encErr
    end

    local downloadParam, cdnErr = self:_uploadToCDN(cdnURL, ciphertext)
    if not downloadParam then
      return nil, cdnErr
    end

    return {
      file_key = fileKey,
      download_encrypted_query_param = downloadParam,
      aes_key = aesKeyHex,
      file_size = rawSize,
      ciphertext_size = #ciphertext,
    }, nil
  end

  function Client:downloadMedia(media)
    if type(media) ~= "table" then
      return nil, errors.runtimeError("ilink: media is nil")
    end

    local key, keyErr = M.ParseAESKey(mediaField(media, "aes_key", "AESKey"))
    if not key then
      return nil, keyErr
    end

    local downloadURL, urlErr = resolveCDNDownloadURL(self, media)
    if not downloadURL then
      return nil, urlErr
    end

    local ciphertext, err = self:_doGet(downloadURL, nil, constants.DefaultCDNTimeoutMs)
    if not ciphertext then
      return nil, errors.runtimeError("ilink: cdn download: " .. tostring(err))
    end

    local plaintext, decErr = M.DecryptAESECB(ciphertext, key)
    if not plaintext then
      return nil, errors.runtimeError("ilink: cdn decrypt: " .. tostring(decErr))
    end

    return plaintext, nil
  end

  function Client:downloadFile(encryptedQueryParam, aesKeyBase64)
    return self:downloadMedia({
      encrypt_query_param = encryptedQueryParam,
      aes_key = aesKeyBase64,
    })
  end

  function Client:downloadMediaRaw(media)
    if type(media) ~= "table" then
      return nil, errors.runtimeError("ilink: media is nil")
    end

    local downloadURL, urlErr = resolveCDNDownloadURL(self, media)
    if not downloadURL then
      return nil, urlErr
    end

    local data, err = self:_doGet(downloadURL, nil, constants.DefaultCDNTimeoutMs)
    if not data then
      return nil, errors.runtimeError("ilink: cdn download: " .. tostring(err))
    end

    return data, nil
  end

  function Client:downloadRaw(encryptedQueryParam)
    return self:downloadMediaRaw({
      encrypt_query_param = encryptedQueryParam,
    })
  end
end

return M
