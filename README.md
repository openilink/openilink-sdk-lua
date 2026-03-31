# openilink-sdk-lua

Lua SDK migration for [openilink-sdk-go](https://github.com/openilink/openilink-sdk-go).

## Current Scope

Current Lua parity covers the main Go SDK workflow:

- QR login flow (`fetchQRCode`, `pollQRStatus`, `loginWithQR`)
- QR redirect handling (`scaned_but_redirect`) and fixed `loginBaseURL`
- Long polling (`getUpdates`, `monitor`) with retry/backoff
- Message send path (`sendMessage`, `sendText`, `push`)
- Config and typing (`getConfig`, `sendTyping`)
- MIME helper and text extraction helper
- Media send helpers (`sendImage`, `sendVideo`, `sendFileAttachment`, `sendMediaFile`)
- CDN upload/download helpers (`uploadFile`, `downloadMedia`, `downloadMediaRaw`, `downloadFile`, `downloadRaw`)
- AES-128-ECB + PKCS#7 helpers
- Voice download + WAV wrapping (`downloadVoice`, `BuildWAV`)
- Constant parity additions (`Media*`, `EncryptAES128ECB`, `VoiceFormat*`)
- Attachment filename mode: default keeps legacy `file_name`; opt-in basename via `useBasenameForAttachmentName = true`

## Directory Layout

- `lua/openilink/*.lua`: SDK source
- `examples/echo_bot.lua`: echo bot example
- `tests/*.lua`: mock-based regression scripts

## Quick Start

```lua
package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

local ilink = require("openilink")
local client = ilink.newClient("")

local result, err = client:loginWithQR({
  onQRCode = function(img) print(img) end,
})
assert(result and result.connected, err or result.message)
```

## Media Helpers

```lua
local ilink = require("openilink")

local client = ilink.newClient("token", {
  silkDecoder = function(data, sampleRate)
    -- return PCM bytes for the decrypted voice payload
  end,
})

local uploaded = assert(client:uploadFile("hello", "user-id", ilink.MediaFile))
assert(uploaded.download_encrypted_query_param ~= "")
```

## HTTP Transport

Default transport uses `curl` command line (`openilink.http.CurlAdapter`).

Requirements:

- `curl` executable in `PATH`
- `md5sum` executable in `PATH` for `uploadFile`

Voice decoding also requires a caller-provided `silkDecoder` callback. The SDK
downloads and decrypts the voice payload, then passes the raw bytes to that
callback and wraps the returned PCM bytes as WAV.

You can inject your own adapter with the same interface:

```lua
local client = ilink.newClient("token", {
  useBasenameForAttachmentName = true, -- optional: align with Go basename behavior
  httpAdapter = {
    request = function(_, opts)
      -- return { status = 200, body = "{}", headers = {} }, nil
    end,
  },
})
```

## Run Tests

```sh
lua tests/run.lua
```

If Lua runtime is unavailable in your environment, install Lua first and then
run the same command.

## Migration Notes

See `MIGRATION_STATUS.md` for module-by-module parity with the Go SDK.
