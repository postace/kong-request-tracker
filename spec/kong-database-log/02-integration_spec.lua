local pgmoon = require "pgmoon"
local helpers = require "spec.helpers"
local json = require("cjson")
local kong = kong


local PLUGIN_NAME = "kong-database-log"

local function connect_db()
  local config = {
    host = "pongo-f586ca67-postgres.pongo-f586ca67",
    timeout = 60000,
    user = "kong",
    password = nil,
    database = "kong_tests",
    schema = "",
    ssl = false,
    ssl_verify = false,
    --cafile      = conf.dbl_lua_ssl_trusted_certificate_combined,
    sem_max = 0,
    sem_timeout = 60,
  }

  local connection = pgmoon.new(config)
  local ok, err = connection:connect()
  if not ok then
    kong.log.info("Connected to Postgres err " .. err)
    return nil, err
  end

  return connection, nil
end

for _, strategy in helpers.all_strategies() do if strategy == "postgres" then
  describe(PLUGIN_NAME .. ": (log) [#" .. strategy .. "]", function()
    local client

    lazy_setup(function()

      local bp = helpers.get_db_utils("postgres", nil, { PLUGIN_NAME })

      -- Inject a test route. No need to create a service, there is a default
      -- service which will echo the request.
      local route1 = bp.routes:insert({
        hosts = { "test1.com" },
      })
      -- add the plugin to test to the route we created
      bp.plugins:insert {
        name = PLUGIN_NAME,
        route = { id = route1.id },
        config = {
          dbl_retry_count = 1,
          dbl_flush_timeout = 0.1,
          dbl_batch_max_size = 1
        },
      }

      helpers.clean_logfile()

      -- start kong
      assert(helpers.start_kong({
        -- set the strategy
        database   = strategy,
        -- use the custom test template to create a local mock server
        nginx_conf = "spec/fixtures/custom_nginx.template",
        -- make sure our plugin gets loaded
        plugins = "bundled," .. PLUGIN_NAME,
        -- write & load declarative config, only if 'strategy=off'
        declarative_config = strategy == "off" and helpers.make_yaml_file() or nil,
      }))
    end)

    lazy_teardown(function()
      helpers.stop_kong(nil, true)
    end)

    before_each(function()
      client = helpers.proxy_client()
    end)

    after_each(function()
      if client then client:close() end
    end)

    -- Test scenario

    describe("http request", function()
      it("should log device's info", function()
        local jwt_token = "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJzdWIiOiIwMDAxMDAwMTE1IiwiYXV0aFNvdXJjZSI6ImludmVzdG9yIiwicm9sZXMiOlsiaW52ZXN0b3IiXSwiaXNzIjoiRE5TRSIsImludmVzdG9ySWQiOiIwMDAxMDAwMTE1IiwiZnVsbE5hbWUiOiJOZ3V54buFbiBWxINuIE3Dom0iLCJzZXNzaW9uSWQiOiJjYTQwM2ZkMS0zNTA3LTRhZTgtYTZlNy1iMmFmMTg0MzMxYmQiLCJ1c2VySWQiOiIzYTJlNTUyOS0yOWE3LTRlNjctOGZiNS01MTQwYmUzOWYwYTciLCJhdWQiOlsiYXVkaWVuY2UiXSwiY3VzdG9tZXJFbWFpbCI6ImVudHJhZGUudGVzdGVyQGdtYWlsLmNvbSIsImN1c3RvZHlDb2RlIjoiMDY0QzAwMDExNSIsImN1c3RvbWVySWQiOiIwMDAxMDAwMTE1IiwiZXhwIjoxNjY3ODY4MDY1LCJjdXN0b21lck1vYmlsZSI6IjAxMTExMTExMTEiLCJpYXQiOjE2Njc4MzkyNjUsInVzZXJuYW1lIjoiMDY0QzAwMDExNSIsInN0YXR1cyI6IkFDVElWRSJ9.mICQoI1iUtw_nMNlgejJEKKXaKGcC0PeS9fHaqhGFA_Zjd4Lmpt6q8D5RHRS7Zp8W8nhF2QG1Ksd0z9v-fCbFZ5voSKwF96H9HwnB6aTAztdyhOh9LBytfPCxPJdxt1daHonuUAexpfTTCMWgRnmpnjC2dMy7GDHyxvrh58GHpI"
        -- when
        local r = client:get("/request", {
          headers = {
            host = "test1.com",
            ["Authorization"] = "Bearer " .. jwt_token,
            ["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)",
            ["Device-Id"] = "11011abcdef",
            ["Brand"] = "MacOS",
            ["Model"] = "M1"
          }
        })

        -- then
        assert.response(r).has.status(200)

        helpers.wait_until(function()
          local conn = connect_db()
          local res = conn:query("select * from request_logs")

          if next(res) ~= nil then
            assert.same("MacOS", res[1]["brand"])
            assert.same("M1", res[1]["model"])
            assert.same("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", res[1]["user_agent"])
            assert.same("11011abcdef", res[1]["device_id"])
            assert.same("0001000115", res[1]["investor_id"])
            return true
          end

          conn:keepalive()
        end, 10)

        -- now check the request (as echoed by mockbin) to have the header
      end)
    end)

  end)

end end
