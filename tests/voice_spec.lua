package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

local Client = require("openilink.client")
local voice = require("openilink.voice")

local function u16le(buf, offset)
  local b1, b2 = string.byte(buf, offset, offset + 1)
  return b1 + b2 * 256
end

local function u32le(buf, offset)
  local b1, b2, b3, b4 = string.byte(buf, offset, offset + 3)
  return b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
end

do
  local pcm = string.char(1, 0, 2, 0)
  local wav = voice.BuildWAV(pcm, 24000, 1, 16)

  assert(#wav == 48, "WAV length mismatch")
  assert(wav:sub(1, 4) == "RIFF", "WAV should start with RIFF")
  assert(wav:sub(9, 12) == "WAVE", "WAV should include WAVE signature")
  assert(u32le(wav, 25) == 24000, "WAV sample rate mismatch")
  assert(u16le(wav, 23) == 1, "WAV channel mismatch")
  assert(u16le(wav, 35) == 16, "WAV bitsPerSample mismatch")
  assert(wav:sub(45) == pcm, "WAV payload mismatch")
end

do
  local client = Client.new("token")
  local _, missingDecoderErr = client:downloadVoice({
    media = {
      encrypt_query_param = "encrypted",
      aes_key = "aes-key",
    },
  })
  assert(missingDecoderErr and tostring(missingDecoderErr):find("no SILK decoder configured", 1, true), "downloadVoice should require silkDecoder")
end

do
  local client = Client.new("token", {
    silkDecoder = function(data, sampleRate)
      assert(data == "cipher-voice", "decoder data mismatch")
      assert(sampleRate == 24000, "decoder sample rate mismatch")
      return string.char(16, 0, 32, 0), nil
    end,
  })

  function client:downloadFile(encryptedQueryParam, aesKey)
    assert(encryptedQueryParam == "encrypted", "downloadFile query mismatch")
    assert(aesKey == "aes-key", "downloadFile aes key mismatch")
    return "cipher-voice", nil
  end

  local wav, err = client:downloadVoice({
    media = {
      encrypt_query_param = "encrypted",
      aes_key = "aes-key",
    },
  })

  assert(wav and not err, "downloadVoice should succeed with custom decoder")
  assert(wav:sub(1, 4) == "RIFF", "downloadVoice should return WAV bytes")
  assert(u32le(wav, 25) == 24000, "downloadVoice should apply default sample rate")
end

return true
