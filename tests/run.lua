package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

local tests = {
  "tests/json_spec",
  "tests/client_spec",
}

for _, mod in ipairs(tests) do
  local ok, err = pcall(require, mod)
  if not ok then
    io.stderr:write(string.format("[FAIL] %s: %s\n", mod, tostring(err)))
    os.exit(1)
  end
  io.stdout:write(string.format("[PASS] %s\n", mod))
end
