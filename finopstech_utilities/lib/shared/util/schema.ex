if Code.ensure_loaded?(Ecto.Schema) do
  defmodule Shared.Util.Schema do
    @moduledoc """
    Werkzeuge zur arbeit mit Schemas
    """

    @interne_felder [:id, :lock_version, :inserted_at, :updated_at]

    @doc """
    Gibt die schreibbaren Felder eines Ecto-Schemas zurück.

    Interne Felder wie #{inspect(@interne_felder)} werden ausgeschlossen.

    Diese Funktion verwenden wir gerne um die änderbaren Felder in Factories & Repositories anzugeben, ohne das man bei
    jedem neuen Feld auch die entsprechenden Listen mit aktualisieren muss.
    """
    @spec erlaubte_felder(module()) :: list(atom())
    def erlaubte_felder(schema_module) do
      schema_module.__schema__(:fields) -- @interne_felder
    end
  end
end
