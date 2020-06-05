import Config

config :ex_aws,
  access_key_id: [{:awscli, "personal", 5000}],
  secret_access_key: [{:awscli, "personal", 5000}],
  region: "ca-central-1"

config :multi_stream, bucket: "multi-upload-demo-25", upload_prefix: "upload", hash_algo: :blake2s
