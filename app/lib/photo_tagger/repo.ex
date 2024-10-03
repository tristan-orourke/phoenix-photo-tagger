defmodule PhotoTagger.Repo do
  use Ecto.Repo,
    otp_app: :photo_tagger,
    adapter: Ecto.Adapters.Postgres
end
