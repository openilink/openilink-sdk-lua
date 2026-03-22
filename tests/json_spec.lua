package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

local json = require("openilink.json")

local encoded = json.encode({
  a = 1,
  b = true,
  c = { "x", 2 },
  d = json.null,
})
assert(type(encoded) == "string", "json.encode should return string")

local decoded = json.decode('{"a":1,"b":true,"c":["x",2],"d":null}')
assert(decoded.a == 1, "json.decode number mismatch")
assert(decoded.b == true, "json.decode boolean mismatch")
assert(decoded.c[1] == "x" and decoded.c[2] == 2, "json.decode array mismatch")
assert(decoded.d == json.null, "json.decode null sentinel mismatch")

local escaped = json.decode('{"line":"a\\nb"}')
assert(escaped.line == "a\nb", "json string escape mismatch")

return true
