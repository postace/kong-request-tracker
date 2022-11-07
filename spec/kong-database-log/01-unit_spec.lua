_G._TEST = true

local PLUGIN_NAME = "kong-database-log"
local jwt = require("kong.plugins.kong-database-log.jwt")
local handler = require("kong.plugins.kong-database-log.handler")

describe(PLUGIN_NAME .. ": (jwt)", function()

  it("should return empty table if token is nil", function()
    local claims = jwt.parse_jwt_claims(nil)

    assert.is_nil(next(claims))
  end)

  it("should return error when parse invalid jwt", function()
    local ok, _ = pcall(jwt.parse_jwt_claims, "Bearer 12345")

    assert.falsy(ok)
  end)

  it("should parse jwt success", function()
    local token = "Bearer   eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJzdWIiOiIwMDAxMDAwMTE1IiwiYXV0aFNvdXJjZSI6ImludmVzdG9yIiwicm9sZXMiOlsiaW52ZXN0b3IiXSwiaXNzIjoiRE5TRSIsImludmVzdG9ySWQiOiIwMDAxMDAwMTE1IiwiZnVsbE5hbWUiOiJOZ3V54buFbiBWxINuIE3Dom0iLCJzZXNzaW9uSWQiOiIzNGVkZDVjNi0zYjhkLTRhYmMtYjBjOC1jMjhiZTlhNzIyMjgiLCJ1c2VySWQiOiIzYTJlNTUyOS0yOWE3LTRlNjctOGZiNS01MTQwYmUzOWYwYTciLCJhdWQiOlsiYXVkaWVuY2UiXSwiY3VzdG9tZXJFbWFpbCI6ImVudHJhZGUudGVzdGVyQGdtYWlsLmNvbSIsImN1c3RvZHlDb2RlIjoiMDY0QzAwMDExNSIsImN1c3RvbWVySWQiOiIwMDAxMDAwMTE1IiwiZXhwIjoxNjY3ODE4ODg4LCJjdXN0b21lck1vYmlsZSI6IjAxMTExMTExMTEiLCJpYXQiOjE2Njc3OTAwODgsInVzZXJuYW1lIjoiMDY0QzAwMDExNSIsInN0YXR1cyI6IkFDVElWRSJ9.HB8AQKC_-FeUfRiXunsTxN3SyAX5wyc1PGr2Zakjryc_4k4OHBYb9k-nAc1TJTJCF7dy3HCIPIwoRVv0-N8e4ceZcn5sPf9HM3Ak_xkl3DFwr7Pho4WnwpT9YmOaqGVSRKgdzIr07X00pu0JLnNsd5q5ciYyUJVbA3hbmpYxmp0"
    local _, claims = pcall(jwt.parse_jwt_claims, token)

    assert.not_nil(claims.investorId)
  end)
end)

describe(PLUGIN_NAME .. ": (handler)", function()

  it("test split array to equally size", function()
    arr = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13 }

    array_of_array = handler._split_array(arr, 3)
    -- test size
    assert.equal(5, #array_of_array)
    assert.equal(3, #array_of_array[1])
    assert.equal(3, #array_of_array[2])
    assert.equal(3, #array_of_array[3])
    assert.equal(3, #array_of_array[4])
    assert.equal(1, #array_of_array[5])

    -- test items
    assert.equal(4, array_of_array[2][1])
    assert.equal(13, array_of_array[5][1])
  end)

  it("test should log request for 2xx status", function()
    assert.is_true(handler._should_log_request(201))
    assert.is_true(handler._should_log_request(200))
    assert.is_true(handler._should_log_request(204))
    assert.is_true(handler._should_log_request(299))
  end)

  it("test should not log request for status not 2xx", function()
    assert.is_false(handler._should_log_request(401))
    assert.is_false(handler._should_log_request(404))

    assert.is_false(handler._should_log_request(500))
    assert.is_false(handler._should_log_request(501))
    assert.is_false(handler._should_log_request(503))
    assert.is_false(handler._should_log_request(504))
  end)

  it("test parse to values", function()
    local headers = {}
    headers["user-agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)"
    headers["device-id"] = "djfh21391207as"
    headers["brand"] = "MacOS"
    headers["model"] = "M1"
    headers["authorization"] = "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJzdWIiOiIwMDAxMDAwMTE1IiwiYXV0aFNvdXJjZSI6ImludmVzdG9yIiwicm9sZXMiOlsiaW52ZXN0b3IiXSwiaXNzIjoiRE5TRSIsImludmVzdG9ySWQiOiIwMDAxMDAwMTE1IiwiZnVsbE5hbWUiOiJOZ3V54buFbiBWxINuIE3Dom0iLCJzZXNzaW9uSWQiOiIzNGVkZDVjNi0zYjhkLTRhYmMtYjBjOC1jMjhiZTlhNzIyMjgiLCJ1c2VySWQiOiIzYTJlNTUyOS0yOWE3LTRlNjctOGZiNS01MTQwYmUzOWYwYTciLCJhdWQiOlsiYXVkaWVuY2UiXSwiY3VzdG9tZXJFbWFpbCI6ImVudHJhZGUudGVzdGVyQGdtYWlsLmNvbSIsImN1c3RvZHlDb2RlIjoiMDY0QzAwMDExNSIsImN1c3RvbWVySWQiOiIwMDAxMDAwMTE1IiwiZXhwIjoxNjY3ODE4ODg4LCJjdXN0b21lck1vYmlsZSI6IjAxMTExMTExMTEiLCJpYXQiOjE2Njc3OTAwODgsInVzZXJuYW1lIjoiMDY0QzAwMDExNSIsInN0YXR1cyI6IkFDVElWRSJ9.HB8AQKC_-FeUfRiXunsTxN3SyAX5wyc1PGr2Zakjryc_4k4OHBYb9k-nAc1TJTJCF7dy3HCIPIwoRVv0-N8e4ceZcn5sPf9HM3Ak_xkl3DFwr7Pho4WnwpT9YmOaqGVSRKgdzIr07X00pu0JLnNsd5q5ciYyUJVbA3hbmpYxmp0"

    local request = {}
    request.headers = headers
    request.method = "GET"
    request.url = "http://127.0.0.1/"

    local message = {}
    message.client_ip = "127.0.0.1"
    message.request = request

    local sql_values = handler._parse_to_sql_values(message)
    assert.not_nil(sql_values)
  end)
end)

