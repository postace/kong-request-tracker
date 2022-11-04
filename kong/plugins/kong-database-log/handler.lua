local cjson = require "cjson"
local pgmoon = require "pgmoon"
local plugin_servers = require "kong.runloop.plugin_servers"

local kong = kong
--local ngx = ngx
local logger = kong.log
local traceback = debug.traceback
local tonumber = tonumber
local timer_at = ngx.timer.at

local DatabaseLogHandler = {
  PRIORITY = 30, -- set the plugin priority, which determines plugin execution order
  VERSION = "1.0.0", -- version in X.Y.Z format
}

local connection_name = "connection_database_log"

local create_table_sql = [[
  CREATE TABLE IF NOT EXISTS "request_logs" (
    "investor_id" VARCHAR(32),
    "created_at" TIMESTAMP WITH TIME ZONE,
    "user_agent" TEXT,
    "method" VARCHAR(16),
    "url" VARCHAR(2048),
    "ip" VARCHAR(255),
    "device_id" VARCHAR(255),
    "brand" VARCHAR(255),
    "model" VARCHAR(255)
);
]]

local function select_one(connection)
  local res, err = connection:query("SHOW server_version_num;")
  logger.info("Show version num res: ", logger.inspect(res), err)
end

local function connect_db(conf)
  local config = {
    host = conf.dbl_pg_host,
    port = conf.dbl_pg_port,
    timeout = conf.dbl_pg_timeout,
    user = conf.dbl_pg_user,
    password = conf.dbl_pg_password,
    database = conf.dbl_pg_database,
    schema = conf.dbl_pg_schema or "",
    ssl = conf.dbl_pg_ssl,
    ssl_verify = conf.dbl_pg_ssl_verify,
    --cafile      = conf.dbl_lua_ssl_trusted_certificate_combined,
    sem_max = conf.dbl_pg_max_concurrent_queries or 0,
    sem_timeout = (conf.dbl_pg_semaphore_timeout or 60000) / 1000,
  }

  local connection = pgmoon.new(config)
  local ok, err = connection:connect()
  if not ok then
    return nil, err
  end
  logger.info("Connected to Postgres")

  ngx.ctx[connection_name] = connection

  return ngx.ctx[connection_name]
end

local function get_stored_connection(name)
  return ngx.ctx[name]
end

-- TODO log only 2xx requests
-- TODO Resolve why always connect Postgres everytime
local function log(premature, conf, message)
  if premature then
    return
  end

  local conn = get_stored_connection(connection_name)
  if conn == nil then
    logger.info("Stored connection is nil, try to create a new one")
    conn = connect_db(conf)
    if conn == nil then
      logger.err("Error when connect to Postgres DB")
      return
    end
  end

  logger.info("Got a connection")
  select_one(conn)

  --logger.inspect(message)

  local ip = message.client_ip
  -- TODO: Parse investor_id here
  local user_agent = message.request.headers["user-agent"]
  local method = message.request.method
  local url = message.request.url
  local device_id = message.request.headers["device-id"]
  local brand = message.request.headers["brand"]
  local model = message.request.headers["model"]

  logger.info("Request detail ", ip, user_agent, method, url, device_id, brand, model)

end

-- runs in the 'log_by_lua_block'
function DatabaseLogHandler:log(conf)
  local message = kong.log.serialize()
  local ok, err = timer_at(0, log, conf, message)
  if not ok then
    logger.err("failed to create timer: ", err)
  end
end


-- return our plugin object
return DatabaseLogHandler
