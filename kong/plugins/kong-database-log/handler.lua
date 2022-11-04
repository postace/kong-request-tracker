local BatchQueue = require "kong.tools.batch_queue"
local cjson = require "cjson"
local pgmoon = require "pgmoon"

local kong = kong
local logger = kong.log
local concat = table.concat
local traceback = debug.traceback
local tonumber = tonumber
local fmt = string.format
local encode_array = require("pgmoon.arrays").encode_array
local timer_at = ngx.timer.at

local connection_name = "connection_database_log"
local max_batch_rows = 1000 -- see https://databasefaqs.com/postgresql-insert-multiple-rows
local dbl_table_created = false

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
)
]]

local queues = nil -- one singleton queue

local DatabaseLogHandler = {
  PRIORITY = 30, -- set the plugin priority, which determines plugin execution order
  VERSION = "1.0.0", -- version in X.Y.Z format
}

local function select_one(connection)
  local res, err = connection:query("SHOW server_version_num;")
  logger.info("Show version num res: ", logger.inspect(res), err)
end

-- conn is the connection from pgmoon
local function keepalive_for_perf(conn)
  -- See detail https://leafo.net/guides/using-postgres-with-openresty.html#pgmoon/connection-pooling
  conn:keepalive(60000, 5)
  conn = nil
end

local function connect_db(plugin_conf)
  local config = {
    host = plugin_conf.dbl_pg_host,
    port = plugin_conf.dbl_pg_port,
    timeout = plugin_conf.dbl_pg_timeout,
    user = plugin_conf.dbl_pg_user,
    password = plugin_conf.dbl_pg_password,
    database = plugin_conf.dbl_pg_database,
    schema = plugin_conf.dbl_pg_schema or "",
    ssl = plugin_conf.dbl_pg_ssl,
    ssl_verify = plugin_conf.dbl_pg_ssl_verify,
    --cafile      = conf.dbl_lua_ssl_trusted_certificate_combined,
    sem_max = plugin_conf.dbl_pg_max_concurrent_queries or 0,
    sem_timeout = (plugin_conf.dbl_pg_semaphore_timeout or 60000) / 1000,
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

local function create_table_if_not_exists(conf)
  local conn = connect_db(conf)
  if dbl_table_created ~= true then
    conn:query(create_table_sql)
    logger.info("Create log table if not exists")
    dbl_table_created = true
  end

  keepalive_for_perf(conn)
end

-- message = kong.log.serialize()
local function parse_to_sql(message)
  local ip = message.client_ip
  -- TODO: Parse investor_id here
  local investor_id = ""
  local user_agent = message.request.headers["user-agent"]
  local method = message.request.method
  local url = message.request.url
  local device_id = message.request.headers["device-id"]
  local brand = message.request.headers["brand"]
  local model = message.request.headers["model"]

  local insert_sql = "INSERT INTO request_logs(investor_id, created_at, user_agent, method, url, ip, device_id, brand, model)" ..
    " VALUES (%s)"

  local arr_val = encode_array({ '', os.date(), user_agent, method, url, ip, device_id, brand, model })

  arr_val = arr_val:gsub('ARRAY%[', "")
  arr_val = arr_val:gsub('%]', "")

  return fmt(insert_sql, arr_val)
end

-- message = kong.log.serialize()
local function parse_to_values(message)
  local ip = message.client_ip
  -- TODO: Parse investor_id here
  local investor_id = ""
  local user_agent = message.request.headers["user-agent"]
  local method = message.request.method
  local url = message.request.url
  local device_id = message.request.headers["device-id"]
  local brand = message.request.headers["brand"]
  local model = message.request.headers["model"]

  local arr_val = encode_array({ investor_id, os.date(), user_agent, method, url, ip, device_id, brand, model })

  arr_val = arr_val:gsub('ARRAY%[', "(")
  arr_val = arr_val:gsub('%]', ")")

  return arr_val
end

local function persist_request(self, conf, sql_values)
  local conn = get_stored_connection(connection_name)
  if conn == nil then
    conn = connect_db(conf)
    if conn == nil then
      logger.err("Error when connect to Postgres DB")
      return
    end
  end

  -- TODO: Split by rows, each size is 1000
  local values = table.concat(sql_values, ",")
  local sql = "INSERT INTO request_logs(investor_id, created_at, user_agent, method, url, ip, device_id, brand, model) VALUES " ..
    " " .. values

  logger.info("Values was = ", sql)

  conn:query(sql)

  logger.info("Reused times = ", conn.sock:getreusedtimes())
  keepalive_for_perf(conn)

  return true
end

-- TODO log only 2xx requests
local function log(premature, conf, message)
  if premature then
    return
  end

  create_table_if_not_exists(conf)

  -- create queue here
  local process = function(entries)
    return persist_request(self, conf, entries)
  end
  local opts = {
    retry_count    = conf.dbl_retry_count,
    flush_timeout  = conf.dbl_flush_timeout,
    batch_max_size = conf.dbl_batch_max_size,
    process_delay  = 0,
  }
  if not queues then
    local err
    queues, err = BatchQueue.new(process, opts)
    if not queues then
      kong.log.err("could not create queue: ", err)
      return
    end
  end

  queues:add(parse_to_values(message))

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
