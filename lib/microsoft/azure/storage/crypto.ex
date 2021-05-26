defmodule Microsoft.Azure.Storage.Crypto do
  if Code.ensure_loaded?(:crypto) and function_exported?(:crypto, :mac, 4) do
    def hmac(digest, key, payload), do: :crypto.mac(:hmac, digest, key, payload)
  else
    def hmac(digest, key, payload), do: :crypto.hmac(digest, key, payload)
  end
end
