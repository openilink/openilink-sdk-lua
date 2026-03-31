local constants = require("openilink.constants")
local util = require("openilink.util")
local mime = require("openilink.mime")
local cdn = require("openilink.cdn")
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

function M.extendClient(Client)
  cdn.extendClient(Client)
  voice.extendClient(Client)

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
      attachmentFileName = util.basename(fileName)
    end

    return self:sendFileAttachment(to, contextToken, attachmentFileName, uploaded)
  end
end

return M
