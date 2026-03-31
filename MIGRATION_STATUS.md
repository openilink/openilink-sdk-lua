# Migration Status: Go -> Lua

Reference repository:

- https://github.com/openilink/openilink-sdk-go

## Parity Table

- `client.go`: partial
  - done: client config, common headers, encoded client version, doPost/doGet, getUpdates, sendMessage, sendText, getConfig, sendTyping, getUploadURL, context token cache, push
  - gap: Lua client does not expose raw HTTP response metadata or request cancellation context
- `auth.go`: done
  - done: fetch QR, poll QR status, QR redirect handling, login flow with callbacks and QR refresh
- `monitor.go`: done
  - done: retry/backoff, session-expired handling, dynamic poll timeout, context-token cache update
- `helpers.go`: partial
  - done: ExtractText, client version encoding, client ID format alignment, trim helpers
  - gap: timeout type check differs because transport is adapter-based
- `mime.go`: done
- `media.go`: done
  - done: send image/video/file message builders, MIME router, upload pipeline integration
  - done: attachment filename compatibility switch (`useBasenameForAttachmentName`, default legacy)
- `cdn.go`: done
  - done: AES-128-ECB + PKCS#7, upload/download helpers, full URL preference, key parser
  - gap: upload hashing currently depends on `md5sum` being available in `PATH`
- `voice.go`: done
  - done: voice download/decrypt, caller-provided SILK decoder integration, WAV builder
  - gap: no bundled SILK decoder implementation in Lua
- `errors.go`: done
- `types.go`: partial
  - done: key response fields and constants are represented in Lua tables/constants
  - done: aligned exported constants for `UploadMediaType`, `EncryptType`, `VoiceFormat`, `DefaultVoiceSampleRate`
  - gap: Go typed response wrappers and raw response attachment are not modeled 1:1

## Remaining Gaps

- no native request cancellation API equivalent to Go `context.Context`
- no bundled SILK decoder implementation; callers must inject `silkDecoder`
- no raw HTTP response metadata attachment on decoded Lua response tables
