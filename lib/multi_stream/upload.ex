defmodule MultiStream.Upload do
  @type t() :: %__MODULE__{
          key: String.t(),
          bucket: String.t(),
          filename: String.t(),
          content_type: String.t(),
          hash: reference() | String.t() | nil,
          length: non_neg_integer(),
          parts: list(),
          parts_count: non_neg_integer(),
          upload_id: String.t() | nil
        }

  defstruct key: "",
            bucket: "",
            filename: "",
            content_type: "",
            hash: nil,
            length: 0,
            parts: [],
            parts_count: 0,
            upload_id: nil
end
