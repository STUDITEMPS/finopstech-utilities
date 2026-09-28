if Code.ensure_loaded?(Cldr) do
  defmodule Shared.Number.Cldr do
    @moduledoc """
    CLDR backend for `Shared.Number` (German locale only).

    The locale data is committed under `priv/cldr/locales/` so builds don't need to
    download it. After updating ex_cldr, commit the regenerated file as well.
    """
    use Cldr,
      otp_app: :finopstech_utilities,
      locales: ["de"],
      default_locale: "de",
      providers: [Cldr.Number]
  end
end
