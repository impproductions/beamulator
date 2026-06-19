import Config

config :ingest_backend,
  http_port: String.to_integer(System.get_env("PORT") || "4100"),
  questdb_host: System.get_env("QUESTDB_HOST") || "localhost",
  questdb_ilp_port: String.to_integer(System.get_env("QUESTDB_ILP_PORT") || "9009"),
  table_name: System.get_env("INGEST_TABLE") || "sensor_reading"
