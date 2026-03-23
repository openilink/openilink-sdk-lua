# openilink-sdk-lua

Lua SDK migration for [openilink-sdk-go](https://github.com/openilink/openilink-sdk-go).

## Iteration 1 Scope

This first iteration ports the core bot workflow:

- QR login flow (`fetchQRCode`, `pollQRStatus`, `loginWithQR`)
- Long polling (`getUpdates`, `monitor`) with retry/backoff
- Message send path (`sendMessage`, `sendText`, `push`)
- Config and typing (`getConfig`, `sendTyping`)
- MIME helper and text extraction helper
- Media message builders (`sendImage`, `sendVideo`, `sendFileAttachment`, `sendMediaFile`)
- Voice/WAV helper (`BuildWAV`) and decoder hook (`silkDecoder`, `downloadVoice`)
- Constant parity additions (`Media*`, `EncryptAES128ECB`, `VoiceFormat*`)
- Attachment filename mode: default keeps legacy `file_name`; opt-in basename via `useBasenameForAttachmentName = true`

Not implemented yet in iteration 1:

- CDN upload/download encryption pipeline
- End-to-end voice download/decrypt pipeline (depends on CDN implementation)

## Directory Layout

- `lua/openilink/*.lua`: SDK source
- `examples/echo_bot.lua`: echo bot example
- `tests/*.lua`: minimal test scripts

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

## HTTP Transport

Default transport uses `curl` command line (`openilink.http.CurlAdapter`).

Requirements:

- `curl` executable in `PATH`

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

If Lua runtime is unavailable in your environment, run the same command once Lua is installed.

## Migration Notes

See `MIGRATION_STATUS.md` for module-by-module parity with the Go SDK.
