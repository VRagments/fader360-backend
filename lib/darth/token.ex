defmodule Darth.Token do
  @hash_algorithm :sha256
  @rand_size 32

  def build_hashed_token() do
    token = :crypto.strong_rand_bytes(@rand_size)
    :crypto.hash(@hash_algorithm, token)
  end
end
