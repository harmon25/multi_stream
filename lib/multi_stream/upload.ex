defmodule MultiStream.Upload do
  @enforce_keys [:adapter]

  @type t() :: %__MODULE__{
          filename: String.t(),
          content_type: String.t(),
          hash: reference() | String.t() | nil,
          size: non_neg_integer(),
          enc_state: any(),
          enc_key: String.t(),
          adapter: any()
        }

  defstruct filename: "",
            content_type: "",
            hash: nil,
            size: 0,
            enc_state: nil,
            enc_key: "",
            adapter: nil

  def new(adapter) do
    %__MODULE__{adapter: adapter}
  end
end
