local constants = require("openilink.constants")
local errors = require("openilink.errors")
local mime = require("openilink.mime")
local helpers = require("openilink.helpers")
local cdn = require("openilink.cdn")
local voice = require("openilink.voice")
local Client = require("openilink.client")

local M = {}

M.Client = Client
M.newClient = Client.new

M.Constants = constants
M.Errors = errors

M.ExtractText = helpers.ExtractText
M.IsMediaItem = helpers.IsMediaItem

M.MIMEFromFilename = mime.MIMEFromFilename
M.ExtensionFromMIME = mime.ExtensionFromMIME
M.IsImageMIME = mime.IsImageMIME
M.IsVideoMIME = mime.IsVideoMIME
M.EncryptAESECB = cdn.EncryptAESECB
M.DecryptAESECB = cdn.DecryptAESECB
M.AESECBPaddedSize = cdn.AESECBPaddedSize
M.BuildCDNDownloadURL = cdn.BuildCDNDownloadURL
M.BuildCDNUploadURL = cdn.BuildCDNUploadURL
M.ParseAESKey = cdn.ParseAESKey
M.BuildWAV = voice.BuildWAV

M.ErrNoContextToken = errors.ErrNoContextToken

for k, v in pairs(constants) do
  M[k] = v
end

return M
