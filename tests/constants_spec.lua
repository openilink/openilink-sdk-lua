package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

local ilink = require("openilink")

assert(ilink.MediaImage == 1, "MediaImage constant mismatch")
assert(ilink.MediaVideo == 2, "MediaVideo constant mismatch")
assert(ilink.MediaFile == 3, "MediaFile constant mismatch")
assert(ilink.MediaVoice == 4, "MediaVoice constant mismatch")

assert(ilink.EncryptAES128ECB == 1, "EncryptAES128ECB constant mismatch")

assert(ilink.VoiceFormatUnknown == -1, "VoiceFormatUnknown constant mismatch")
assert(ilink.VoiceFormatAMR == 0, "VoiceFormatAMR constant mismatch")
assert(ilink.VoiceFormatSPEEX == 1, "VoiceFormatSPEEX constant mismatch")
assert(ilink.VoiceFormatMP3 == 2, "VoiceFormatMP3 constant mismatch")
assert(ilink.VoiceFormatWAVE == 3, "VoiceFormatWAVE constant mismatch")
assert(ilink.VoiceFormatSILK == 4, "VoiceFormatSILK constant mismatch")

assert(ilink.DefaultVoiceSampleRate == 24000, "DefaultVoiceSampleRate constant mismatch")

return true
