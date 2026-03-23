local constants = require("openilink.constants")

local M = {}

local function le16(n)
  local b1 = n % 256
  local b2 = math.floor(n / 256) % 256
  return string.char(b1, b2)
end

local function le32(n)
  local b1 = n % 256
  local b2 = math.floor(n / 256) % 256
  local b3 = math.floor(n / 65536) % 256
  local b4 = math.floor(n / 16777216) % 256
  return string.char(b1, b2, b3, b4)
end

function M.BuildWAV(pcm, sampleRate, numChannels, bitsPerSample)
  local pcmData = pcm or ""
  local sr = tonumber(sampleRate) or constants.DefaultVoiceSampleRate
  if sr <= 0 then
    sr = constants.DefaultVoiceSampleRate
  end

  local channels = tonumber(numChannels) or 1
  if channels <= 0 then
    channels = 1
  end

  local bits = tonumber(bitsPerSample) or 16
  if bits <= 0 then
    bits = 16
  end

  local dataSize = #pcmData
  local byteRate = math.floor(sr * channels * bits / 8)
  local blockAlign = math.floor(channels * bits / 8)

  local header = table.concat({
    "RIFF",
    le32(36 + dataSize),
    "WAVE",
    "fmt ",
    le32(16),
    le16(1),
    le16(channels),
    le32(sr),
    le32(byteRate),
    le16(blockAlign),
    le16(bits),
    "data",
    le32(dataSize),
  })

  return header .. pcmData
end

return M
