local M = {}

M.DefaultBaseURL = "https://ilinkai.weixin.qq.com"
M.DefaultCDNBaseURL = "https://novac2c.cdn.weixin.qq.com/c2c"
M.DefaultBotType = "3"
M.ILinkAppID = "bot"
M.DefaultVersion = "2.1.1"

M.DefaultLongPollTimeoutMs = 35000
M.DefaultAPITimeoutMs = 15000
M.DefaultConfigTimeoutMs = 10000
M.DefaultCDNTimeoutMs = 60000
M.DefaultVoiceSampleRate = 24000
M.DefaultLoginTimeoutSec = 8 * 60
M.QRLongPollTimeoutMs = 35000
M.MaxQRRefreshCount = 3
M.UploadMaxRetries = 3

M.MaxConsecutiveFailures = 3
M.BackoffDelaySec = 30
M.RetryDelaySec = 2

M.MsgTypeNone = 0
M.MsgTypeUser = 1
M.MsgTypeBot = 2

M.StateNew = 0
M.StateGenerating = 1
M.StateFinish = 2

M.ItemNone = 0
M.ItemText = 1
M.ItemImage = 2
M.ItemVoice = 3
M.ItemFile = 4
M.ItemVideo = 5

M.Typing = 1
M.CancelTyping = 2
M.EncryptAES128ECB = 1

M.MediaImage = 1
M.MediaVideo = 2
M.MediaFile = 3
M.MediaVoice = 4

M.VoiceFormatUnknown = -1
M.VoiceFormatAMR = 0
M.VoiceFormatSPEEX = 1
M.VoiceFormatMP3 = 2
M.VoiceFormatWAVE = 3
M.VoiceFormatSILK = 4

return M
