# Migration Status: Go -> Lua

Reference repository:

- https://github.com/openilink/openilink-sdk-go

## Parity Table

- `client.go`: partial
  - done: client config, headers, doPost/doGet, getUpdates, sendMessage, sendText, getConfig, sendTyping, getUploadURL, context token cache, push
  - gap: no request context cancellation API in Lua iteration 1
- `auth.go`: done
  - done: fetch QR, poll QR status, login flow with callbacks and QR refresh
- `monitor.go`: done
  - done: retry/backoff, session-expired handling, dynamic poll timeout, context-token cache update
- `helpers.go`: partial
  - done: ExtractText
  - gap: timeout type check differs because transport is adapter-based
- `mime.go`: done
- `media.go`: partial
  - done: send image/video/file message builders and MIME router
  - done: use exported constants for media types/encrypt type
  - done: attachment filename compatibility switch (`useBasenameForAttachmentName`, default legacy)
  - gap: depends on unimplemented upload pipeline
- `cdn.go`: not implemented
  - gap: AES-128-ECB, upload/download, key parser
- `voice.go`: partial
  - done: `BuildWAV`, `silkDecoder` option wiring, `downloadVoice` decode flow (requires `downloadFile`)
  - gap: end-to-end voice path still blocked by CDN download/decrypt implementation
- `types.go`: partial
  - done: aligned exported constants for `UploadMediaType`, `EncryptType`, `VoiceFormat`, `DefaultVoiceSampleRate`
  - gap: no strict Lua struct type layer (table-based runtime mapping)
- `errors.go`: done

## Iteration Plan

- Iteration 2:
  - add CDN upload/download pipeline
  - add AES-128-ECB + PKCS#7 helpers
- Iteration 3:
  - add voice download/decode/wav helpers
  - add integration tests with mocked CDN/API
