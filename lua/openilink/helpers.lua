local constants = require("openilink.constants")

local M = {}

function M.IsMediaItem(item)
  if type(item) ~= "table" then
    return false
  end

  local t = item.type
  return t == constants.ItemImage
    or t == constants.ItemVideo
    or t == constants.ItemFile
    or t == constants.ItemVoice
end

function M.ExtractText(msg)
  if type(msg) ~= "table" or type(msg.item_list) ~= "table" then
    return ""
  end

  for _, item in ipairs(msg.item_list) do
    if item.type == constants.ItemText and item.text_item and item.text_item.text then
      local text = item.text_item.text
      local ref = item.ref_msg
      if ref and ref.message_item and not M.IsMediaItem(ref.message_item) then
        local refBody = ""
        if ref.message_item.text_item and ref.message_item.text_item.text then
          refBody = ref.message_item.text_item.text
        end
        local title = ref.title or ""
        if title ~= "" or refBody ~= "" then
          text = string.format("[quote: %s | %s]\n%s", title, refBody, text)
        end
      end
      return text
    end
  end

  for _, item in ipairs(msg.item_list) do
    if item.type == constants.ItemVoice and item.voice_item and item.voice_item.text then
      return item.voice_item.text
    end
  end

  return ""
end

return M
