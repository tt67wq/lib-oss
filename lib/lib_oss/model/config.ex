defmodule LibOss.Model.Config do
  @moduledoc false

  @lib_oss_opts_schema [
    access_key_id: [
      type: :string,
      doc: "OSS access key id",
      required: true
    ],
    access_key_secret: [
      type: :string,
      doc: "OSS access key secret",
      required: true
    ],
    endpoint: [
      type: :string,
      doc: "OSS endpoint",
      required: true
    ]
  ]

  @type t :: [unquote(NimbleOptions.option_typespec(@lib_oss_opts_schema))]

  def validate(config), do: NimbleOptions.validate(config, @lib_oss_opts_schema)
  def validate!(config), do: NimbleOptions.validate!(config, @lib_oss_opts_schema)
end
