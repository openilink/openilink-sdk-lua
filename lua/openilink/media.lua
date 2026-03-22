local constants = require("openilink.constants")
local util = require("openilink.util")
local mime = require("openilink.mime")
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

local function mediaAESKey(hexKey)
  if not hexKey then
    return ""
  end
  return util.base64Encode(hexKey)
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
                encrypt_type = 1,
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
                encrypt_type = 1,
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
                encrypt_type = 1,
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
      mediaType = 2
    elseif mime.IsImageMIME(guessedMIME) then
      mediaType = 1
    else
      mediaType = 3
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

    if mediaType == 2 then
      return self:sendVideo(to, contextToken, uploaded)
    elseif mediaType == 1 then
      return self:sendImage(to, contextToken, uploaded)
    end
    return self:sendFileAttachment(to, contextToken, fileName, uploaded)
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

  function Client:downloadVoice(_media)
    return nil, errors.runtimeError("ilink: downloadVoice is not implemented in Lua iteration 1")
  end
end

return M
