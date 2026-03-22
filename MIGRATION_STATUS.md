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
  - gap: depends on unimplemented upload pipeline
- `cdn.go`: not implemented
  - gap: AES-128-ECB, upload/download, key parser
- `voice.go`: not implemented
  - gap: SILK decode and WAV build helpers
- `errors.go`: done

## Iteration Plan

- Iteration 2:
  - add CDN upload/download pipeline
  - add AES-128-ECB + PKCS#7 helpers
- Iteration 3:
  - add voice download/decode/wav helpers
  - add integration tests with mocked CDN/API
