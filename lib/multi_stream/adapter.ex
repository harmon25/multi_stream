defmodule MultiStream.Adapter do
  @moduledoc """
  This module also specifies a behaviour that all the file writing adapters used with MultiStream should adopt.
  """
  @type opts :: Keyword.t()

  @callback default_opts() :: Keyword.t()
  @callback init(MultiStream.Upload.t(), opts) :: MultiStream.Upload.t()
  @callback start(MultiStream.Upload.t(), opts) :: MultiStream.Upload.t()
  @callback write_part(MultiStream.Upload.t(), chunk :: binary(), size :: non_neg_integer(), opts) ::
              MultiStream.Upload.t()
  @callback close(MultiStream.Upload.t(), opts) :: MultiStream.Upload.t()
end
