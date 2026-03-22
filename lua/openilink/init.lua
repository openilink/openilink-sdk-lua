local constants = require("openilink.constants")
local errors = require("openilink.errors")
local mime = require("openilink.mime")
local helpers = require("openilink.helpers")
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

M.ErrNoContextToken = errors.ErrNoContextToken

for k, v in pairs(constants) do
  M[k] = v
end

return M
