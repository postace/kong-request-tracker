local json = require "cjson"

local rep = string.rep
local sub = string.sub
local find = string.find
local decode_base64 = ngx.decode_base64

--- Tokenize a string by delimiter
-- Used to separate the header, claims and signature part of a JWT
-- @param str String to tokenize
-- @param div Delimiter
-- @param len Number of parts to retrieve
-- @return A table of strings
local function tokenize(str, div, len)
  local result, pos = {}, 0

  local iter = function()
    return find(str, div, pos, true)
  end

  for st, sp in iter do
    result[#result + 1] = sub(str, pos, st-1)
    pos = sp + 1
    len = len - 1
    if len <= 1 then
      break
    end
  end

  result[#result + 1] = sub(str, pos)
  return result
end

--- base 64 decode
-- @param input String to base64 decode
-- @return Base64 decoded string
local function base64_decode(input)
  local remainder = #input % 4

  if remainder > 0 then
    local padlen = 4 - remainder
    input = input .. rep("=", padlen)
  end

  input = input:gsub("-", "+"):gsub("_", "/")
  return decode_base64(input)
end

--- parse jwt claims, but do not verify
-- @param input String to parse
-- @return jwt claims json
local function parse_jwt_claims(token)
  if token == nil then
    return {}
  end

  if token:find("Bearer", 1, true) then
    token = token:gsub("Bearer%s+", "")
  end

  -- Get b64 parts
  local _, claims_64, _ = unpack(tokenize(token, ".", 3))

  return json.decode(base64_decode(claims_64))
end

local _M = {}

_M.parse_jwt_claims = parse_jwt_claims

return _M
