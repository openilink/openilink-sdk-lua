package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

local Client = require("openilink.client")
local cdn = require("openilink.cdn")
local voice = require("openilink.voice")
local util = require("openilink.util")

do
  local pcm = string.rep("\0", 480)
  local wav = voice.BuildWAV(pcm, 24000, 1, 16)
  assert(#wav == 44 + #pcm, "BuildWAV size mismatch")
  assert(wav:sub(1, 4) == "RIFF", "BuildWAV missing RIFF header")
  assert(wav:sub(9, 12) == "WAVE", "BuildWAV missing WAVE header")
  assert(wav:sub(37, 40) == "data", "BuildWAV missing data chunk")
end

do
  local key = string.char(0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15)
  local encryptedVoice = assert(cdn.EncryptAESECB("silk-data", key))
  local seenSampleRate = nil

  local mock = {}

  function mock:request(opts)
    if opts.url == "https://cdn.example.test/voice" then
      return {
        status = 200,
        body = encryptedVoice,
        headers = {},
      }, nil
    end
    error("unexpected url: " .. tostring(opts.url))
  end

  local client = Client.new("token", {
    httpAdapter = mock,
    silkDecoder = function(data, sampleRate)
      seenSampleRate = sampleRate
      assert(data == "silk-data", "downloadVoice decoder input mismatch")
      return string.rep("\1\0", 8), nil
    end,
  })

  local wav, err = client:downloadVoice({
    sample_rate = 16000,
    media = {
      full_url = "https://cdn.example.test/voice",
      aes_key = util.base64Encode(key),
    },
  })

  assert(wav and not err, "downloadVoice should succeed")
  assert(seenSampleRate == 16000, "downloadVoice sample rate mismatch")
  assert(wav:sub(1, 4) == "RIFF", "downloadVoice should return WAV data")
end

do
  local client = Client.new("token")
  local _, missingDecoderErr = client:downloadVoice({
    media = {
      encrypt_query_param = "encrypted",
      aes_key = "aes-key",
    },
  })
  assert(
    missingDecoderErr and tostring(missingDecoderErr):find("no SILK decoder configured", 1, true),
    "downloadVoice should require silkDecoder"
  )
end

return true
