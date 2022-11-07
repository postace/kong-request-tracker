local typedefs = require "kong.db.schema.typedefs"


local PLUGIN_NAME = "kong-database-log"


local schema = {
  name = PLUGIN_NAME,
  fields = {
    -- the 'fields' array is the top-level entry with fields defined by Kong
    { protocols = typedefs.protocols },
    { config = {
        -- The 'config' record is the custom part of the plugin schema
        type = "record",
        fields = {
          -- a standard defined field (typedef), with some customizations
          { dbl_pg_port = typedefs.port({ default = 5432 }), },
          { dbl_pg_host = { type = "string", required = true, default = "pongo-6acbd47c-postgres.pongo-6acbd47c" }, },
          { dbl_pg_timeout = { type = "number", required = false, default = 60000 }, },
          { dbl_pg_user = { type = "string", required = true, default = "kong" }, },
          { dbl_pg_password = { type = "string", required = false }, },
          { dbl_pg_database = { type = "string", required = true, default = "kong_tests" }, },
          { dbl_pg_schema = { type = "string", required = false }, },
          { dbl_pg_ssl = { type = "boolean", required = false, default = false }, },
          { dbl_pg_ssl_verify = { type = "boolean", required = false, default = false }, },
          { dbl_pg_max_concurrent_queries = { type = "number", required = false, default = 0 }, },
          { dbl_pg_semaphore_timeout = { type = "number", required = false, default = 60000 }, },
          { dbl_retry_count = { type = "number", required = false, default = 3 }, },
          { dbl_flush_timeout = { type = "number", required = false, default = 5 }, },
          { dbl_batch_max_size = { type = "number", required = false, default = 100 }, },
        },
        entity_checks = {
          ---- add some validation rules across fields
        },
      },
    },
  },
}

return schema
