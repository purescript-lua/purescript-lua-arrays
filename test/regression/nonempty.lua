-- Regression guard for Data/Array/NonEmpty/Internal.lua.
--
-- traverse1Impl ports a JS routine that uses `new Cont(...)` / `new ConsCell(...)`.
-- The Lua rewrite must build fresh table nodes, not mutate a phantom `this`
-- (issue #73). We exercise it with the Identity applicative, where map/apply
-- are plain application and the effect is the identity — so traverse1 over an
-- array must return that same array.
--
-- Run from the repo root: `lua test/regression/nonempty.lua`.
local I = dofile("src/Data/Array/NonEmpty/Internal.lua")

local failures = 0

local function eqArray(a, b)
  if type(a) ~= "table" then return false end
  if #a ~= #b then return false end
  for i = 1, #a do if a[i] ~= b[i] then return false end end
  return true
end

local function show(a)
  if type(a) ~= "table" then return tostring(a) end
  local parts = {}
  for i = 1, #a do parts[i] = tostring(a[i]) end
  return "{" .. table.concat(parts, ", ") .. "}"
end

-- Identity applicative.
local function map(g) return function(v) return g(v) end end
local function apply(vf) return function(vx) return vf(vx) end end
local function f(x) return x end

do
  local ok, res = pcall(function() return I.traverse1Impl(apply, map, f)({10, 20, 30}) end)
  if not ok then
    failures = failures + 1
    print("FAIL - traverse1 errors: " .. tostring(res))
  elseif not eqArray(res, {10, 20, 30}) then
    failures = failures + 1
    print("FAIL - traverse1 identity: got " .. show(res) .. ", want {10, 20, 30}")
  else
    print("ok   - traverse1 identity returns input")
  end
end

do
  local ok, res = pcall(function() return I.traverse1Impl(apply, map, f)({42}) end)
  if ok and eqArray(res, {42}) then
    print("ok   - traverse1 singleton")
  else
    failures = failures + 1
    print("FAIL - traverse1 singleton: " .. (ok and show(res) or tostring(res)))
  end
end

if failures > 0 then error(failures .. " regression check(s) failed") end
print("purescript-lua-arrays: NonEmpty FFI regression checks passed")
