local M = {}

local extToMIME = {
  [".pdf"] = "application/pdf",
  [".doc"] = "application/msword",
  [".docx"] = "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
  [".xls"] = "application/vnd.ms-excel",
  [".xlsx"] = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  [".ppt"] = "application/vnd.ms-powerpoint",
  [".pptx"] = "application/vnd.openxmlformats-officedocument.presentationml.presentation",
  [".txt"] = "text/plain",
  [".csv"] = "text/csv",
  [".zip"] = "application/zip",
  [".tar"] = "application/x-tar",
  [".gz"] = "application/gzip",
  [".mp3"] = "audio/mpeg",
  [".ogg"] = "audio/ogg",
  [".wav"] = "audio/wav",
  [".mp4"] = "video/mp4",
  [".mov"] = "video/quicktime",
  [".webm"] = "video/webm",
  [".mkv"] = "video/x-matroska",
  [".avi"] = "video/x-msvideo",
  [".png"] = "image/png",
  [".jpg"] = "image/jpeg",
  [".jpeg"] = "image/jpeg",
  [".gif"] = "image/gif",
  [".webp"] = "image/webp",
  [".bmp"] = "image/bmp",
}

local mimeToExt = {
  ["application/pdf"] = ".pdf",
  ["application/msword"] = ".doc",
  ["application/vnd.openxmlformats-officedocument.wordprocessingml.document"] = ".docx",
  ["application/vnd.ms-excel"] = ".xls",
  ["application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"] = ".xlsx",
  ["application/vnd.ms-powerpoint"] = ".ppt",
  ["application/vnd.openxmlformats-officedocument.presentationml.presentation"] = ".pptx",
  ["text/plain"] = ".txt",
  ["text/csv"] = ".csv",
  ["application/zip"] = ".zip",
  ["application/x-tar"] = ".tar",
  ["application/gzip"] = ".gz",
  ["audio/mpeg"] = ".mp3",
  ["audio/ogg"] = ".ogg",
  ["audio/wav"] = ".wav",
  ["video/mp4"] = ".mp4",
  ["video/quicktime"] = ".mov",
  ["video/webm"] = ".webm",
  ["video/x-matroska"] = ".mkv",
  ["video/x-msvideo"] = ".avi",
  ["image/png"] = ".png",
  ["image/jpeg"] = ".jpg",
  ["image/gif"] = ".gif",
  ["image/webp"] = ".webp",
  ["image/bmp"] = ".bmp",
}

local function fileExtension(filename)
  local ext = filename:match("(%.[^%./]+)$")
  if not ext then
    return ""
  end
  return ext:lower()
end

function M.MIMEFromFilename(filename)
  local ext = fileExtension(filename or "")
  return extToMIME[ext] or "application/octet-stream"
end

function M.ExtensionFromMIME(mime)
  local base = tostring(mime or "")
  local idx = base:find(";", 1, true)
  if idx then
    base = base:sub(1, idx - 1)
  end
  base = base:gsub("^%s+", ""):gsub("%s+$", "")
  return mimeToExt[base] or ".bin"
end

function M.IsImageMIME(mime)
  return tostring(mime or ""):sub(1, 6) == "image/"
end

function M.IsVideoMIME(mime)
  return tostring(mime or ""):sub(1, 6) == "video/"
end

return M
