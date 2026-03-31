local constants = require("openilink.constants")
local errors = require("openilink.errors")

local M = {}

local function pick(tbl, ...)
  if type(tbl) ~= "table" then
    return nil
  end
  for i = 1, select("#", ...) do
    local key = select(i, ...)
    if tbl[key] ~= nil then
      return tbl[key]
    end
  end
  return nil
end

local function le16(value)
  local n = tonumber(value) or 0
  return string.char(n % 256, math.floor(n / 256) % 256)
end

local function le32(value)
  local n = tonumber(value) or 0
  return string.char(
    n % 256,
    math.floor(n / 256) % 256,
    math.floor(n / 65536) % 256,
    math.floor(n / 16777216) % 256
  )
end

function M.BuildWAV(pcm, sampleRate, numChannels, bitsPerSample)
  pcm = pcm or ""
  sampleRate = tonumber(sampleRate) or constants.DefaultVoiceSampleRate or 24000
  numChannels = tonumber(numChannels) or 1
  bitsPerSample = tonumber(bitsPerSample) or 16

  local dataSize = #pcm
  local byteRate = sampleRate * numChannels * bitsPerSample / 8
  local blockAlign = numChannels * bitsPerSample / 8

  return table.concat({
    "RIFF",
    le32(36 + dataSize),
    "WAVE",
    "fmt ",
    le32(16),
    le16(1),
    le16(numChannels),
    le32(sampleRate),
    le32(byteRate),
    le16(blockAlign),
    le16(bitsPerSample),
    "data",
    le32(dataSize),
    pcm,
  })
end

function M.extendClient(Client)
  function Client:downloadVoice(voice)
    if type(self.silkDecoder) ~= "function" then
      return nil, errors.runtimeError("ilink: no SILK decoder configured; set opts.silkDecoder when creating the client")
    end

    local voiceItem = voice
    local media = pick(voiceItem, "media", "Media")

    if type(media) ~= "table" and type(voiceItem) == "table" then
      if pick(voiceItem, "encrypt_query_param", "EncryptQueryParam", "full_url", "FullURL") ~= nil then
        media = voiceItem
        voiceItem = {}
      end
    end

    if type(media) ~= "table" then
      return nil, errors.runtimeError("ilink: voice item or media is nil")
    end

    local data, downloadErr = self:downloadMedia(media)
    if not data then
      return nil, errors.runtimeError("ilink: download voice: " .. tostring(downloadErr))
    end

    local sampleRate = tonumber(pick(voiceItem, "sample_rate", "SampleRate")) or constants.DefaultVoiceSampleRate
    if sampleRate <= 0 then
      sampleRate = constants.DefaultVoiceSampleRate
    end

    local pcm, decodeErr = self.silkDecoder(data, sampleRate)
    if type(pcm) ~= "string" then
      return nil, errors.runtimeError("ilink: decode voice: " .. tostring(decodeErr))
    end

    return M.BuildWAV(pcm, sampleRate, 1, 16), nil
  end
end

return M
