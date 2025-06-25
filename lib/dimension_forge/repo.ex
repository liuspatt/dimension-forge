defmodule DimensionForge.Repo do
  use Ecto.Repo,
    otp_app: :dimension_forge,
    adapter: Ecto.Adapters.Postgres
end
