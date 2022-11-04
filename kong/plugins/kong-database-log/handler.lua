local cjson = require "cjson"
local pgmoon = require "pgmoon"
local plugin_servers = require "kong.runloop.plugin_servers"

local kong = kong
local ngx = ngx
local logger = kong.log
local traceback = debug.traceback
local tonumber = tonumber
local timer_at = ngx.timer.at

local DatabaseLogHandler = {
  PRIORITY = 30, -- set the plugin priority, which determines plugin execution order
  VERSION = "1.0.0", -- version in X.Y.Z format
}

local db = nil
local connection_name = "connection_database_log"
--local connect
-- Todo connect to postgres

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
local function log(premature, conf, message)
  if premature then
    return
  end

  local conn = get_stored_connection(connection_name)
  if conn == nil then
    conn = connect_db(conf)
  end

  if conn == nil then
    logger.info("Connection is nil. Nothing to do")
    return
  else
    logger.info("Got a connection")
    select_one(conn)
  end

  --if db == nil then
  --  local err
  --  db, err = connect_db(conf)
  --  if err ~= nil then
  --    logger.err("Error when connect to Postgres Db " .. err)
  --    return
  --  end
  --end
  --
  --logger.info("Preparing to insert log to db")
  --show_version_num()

end

--do
--  local res, err = db:query("SHOW server_version_num;")
--  local ver = tonumber(res and res[1] and res[1].server_version_num)
--  if not ver then
--    logger.info("failed to retrieve PostgreSQL server_version_num: " .. err)
--  else
--    logger.info("PostgreSQL version: " .. ver)
--  end
--
--end

-- handles more initialization, but AFTER the worker process has been forked/created.
-- It runs in the 'init_worker_by_lua_block'
--function DatabaseLogHandler:init_worker()
--  --if kong.db ~= nil then
--  --
--  --end
--  kong.log.debug("init worker start")
--
--end --]]

-- runs in the 'access_by_lua_block'
--function DatabaseLogHandler:access(conf)
--  -- Do init connection here due by cosockets not available.
--  -- See more: https://github.com/openresty/lua-nginx-module/blob/master/README.markdown#cosockets-not-available-everywhere
--
--  -- TODO: Find a better way to init connection
--
--
--end --]]

-- runs in the 'log_by_lua_block'
function DatabaseLogHandler:log(conf)

  --logger.info("Hello from log block")
  --local res, err = db:query("SELECT 1")
  --if err then
  --  logger.err("Error when select 1 " .. err)
  --end

  local message = kong.log.serialize()
  local ok, err = timer_at(0, log, conf, message)
  if not ok then
    logger.err("failed to create timer: ", err)
  end
end


-- return our plugin object
return DatabaseLogHandler
