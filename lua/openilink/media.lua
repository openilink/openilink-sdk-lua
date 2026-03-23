local constants = require("openilink.constants")
local util = require("openilink.util")
local mime = require("openilink.mime")
local errors = require("openilink.errors")
local voice = require("openilink.voice")

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

local function mediaAESKey(hexKey)
  if not hexKey then
    return ""
  end
  return util.base64Encode(hexKey)
end

local function baseName(path)
  if type(path) ~= "string" or path == "" then
    return ""
  end
  local normalized = path:gsub("\\", "/")
  local name = normalized:match("([^/]+)$")
  return name or normalized
end

function M.extendClient(Client)
  function Client:sendImage(to, contextToken, uploaded)
    local clientID = util.generateClientID()
    local queryParam = pick(uploaded, "download_encrypted_query_param", "DownloadEncryptedQueryParam")
    local aesHex = pick(uploaded, "aes_key", "AESKey")
    local ciphertextSize = pick(uploaded, "ciphertext_size", "CiphertextSize") or 0

    local msg = {
      msg = {
        to_user_id = to,
        client_id = clientID,
        message_type = constants.MsgTypeBot,
        message_state = constants.StateFinish,
        context_token = contextToken,
        item_list = {
          {
            type = constants.ItemImage,
            image_item = {
              media = {
                encrypt_query_param = queryParam,
                aes_key = mediaAESKey(aesHex),
                encrypt_type = constants.EncryptAES128ECB,
              },
              mid_size = ciphertextSize,
            },
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

  function Client:sendVideo(to, contextToken, uploaded)
    local clientID = util.generateClientID()
    local queryParam = pick(uploaded, "download_encrypted_query_param", "DownloadEncryptedQueryParam")
    local aesHex = pick(uploaded, "aes_key", "AESKey")
    local ciphertextSize = pick(uploaded, "ciphertext_size", "CiphertextSize") or 0

    local msg = {
      msg = {
        to_user_id = to,
        client_id = clientID,
        message_type = constants.MsgTypeBot,
        message_state = constants.StateFinish,
        context_token = contextToken,
        item_list = {
          {
            type = constants.ItemVideo,
            video_item = {
              media = {
                encrypt_query_param = queryParam,
                aes_key = mediaAESKey(aesHex),
                encrypt_type = constants.EncryptAES128ECB,
              },
              video_size = ciphertextSize,
            },
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

  function Client:sendFileAttachment(to, contextToken, fileName, uploaded)
    local clientID = util.generateClientID()
    local queryParam = pick(uploaded, "download_encrypted_query_param", "DownloadEncryptedQueryParam")
    local aesHex = pick(uploaded, "aes_key", "AESKey")
    local fileSize = pick(uploaded, "file_size", "FileSize") or 0

    local msg = {
      msg = {
        to_user_id = to,
        client_id = clientID,
        message_type = constants.MsgTypeBot,
        message_state = constants.StateFinish,
        context_token = contextToken,
        item_list = {
          {
            type = constants.ItemFile,
            file_item = {
              media = {
                encrypt_query_param = queryParam,
                aes_key = mediaAESKey(aesHex),
                encrypt_type = constants.EncryptAES128ECB,
              },
              file_name = fileName,
              len = tostring(fileSize),
            },
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

  function Client:sendMediaFile(to, contextToken, data, fileName, caption)
    local mediaType
    local guessedMIME = mime.MIMEFromFilename(fileName)
    if mime.IsVideoMIME(guessedMIME) then
      mediaType = constants.MediaVideo
    elseif mime.IsImageMIME(guessedMIME) then
      mediaType = constants.MediaImage
    else
      mediaType = constants.MediaFile
    end

    local uploaded, upErr = self:uploadFile(data, to, mediaType)
    if not uploaded then
      return nil, upErr
    end

    if caption and caption ~= "" then
      local _, captionErr = self:sendText(to, caption, contextToken)
      if captionErr then
        return nil, captionErr
      end
    end

    if mediaType == constants.MediaVideo then
      return self:sendVideo(to, contextToken, uploaded)
    elseif mediaType == constants.MediaImage then
      return self:sendImage(to, contextToken, uploaded)
    end

    local attachmentFileName = fileName
    if self.useBasenameForAttachmentName then
      attachmentFileName = baseName(fileName)
    end

    return self:sendFileAttachment(to, contextToken, attachmentFileName, uploaded)
  end

  function Client:uploadFile(_plaintext, _toUserID, _mediaType)
    return nil, errors.runtimeError("ilink: uploadFile is not implemented in Lua iteration 1")
  end

  function Client:downloadFile(_encryptedQueryParam, _aesKeyBase64)
    return nil, errors.runtimeError("ilink: downloadFile is not implemented in Lua iteration 1")
  end

  function Client:downloadRaw(_encryptedQueryParam)
    return nil, errors.runtimeError("ilink: downloadRaw is not implemented in Lua iteration 1")
  end

  function Client:downloadVoice(voiceItem)
    local decoder = self.silkDecoder
    if type(decoder) ~= "function" then
      return nil, errors.runtimeError("ilink: no SILK decoder configured; set silkDecoder on client options")
    end

    local mediaItem = pick(voiceItem, "media", "Media")
    if type(mediaItem) ~= "table" then
      return nil, errors.runtimeError("ilink: voice item or media is nil")
    end

    local encryptedQueryParam = pick(mediaItem, "encrypt_query_param", "EncryptQueryParam")
    local aesKey = pick(mediaItem, "aes_key", "AESKey")
    if not encryptedQueryParam or encryptedQueryParam == "" or not aesKey or aesKey == "" then
      return nil, errors.runtimeError("ilink: voice media is missing encrypt_query_param or aes_key")
    end

    local ciphertext, downloadErr = self:downloadFile(encryptedQueryParam, aesKey)
    if not ciphertext then
      return nil, errors.runtimeError("ilink: download voice: " .. tostring(downloadErr))
    end

    local sampleRate = tonumber(pick(voiceItem, "sample_rate", "SampleRate")) or constants.DefaultVoiceSampleRate
    if sampleRate <= 0 then
      sampleRate = constants.DefaultVoiceSampleRate
    end

    local ok, pcmOrErr, decoderErr = pcall(decoder, ciphertext, sampleRate)
    if not ok then
      return nil, errors.runtimeError("ilink: decode voice: " .. tostring(pcmOrErr))
    end
    if not pcmOrErr then
      return nil, errors.runtimeError("ilink: decode voice: " .. tostring(decoderErr))
    end

    return voice.BuildWAV(pcmOrErr, sampleRate, 1, 16), nil
  end
end

return M
