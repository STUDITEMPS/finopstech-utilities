defmodule Shared.Util.SchemaTest do
  @moduledoc false

  use ExUnit.Case, async: true

  defmodule DummySchema do
    use Ecto.Schema

    schema "dummy" do
      field(:name, :string)
      field(:email, :string)
      field(:lock_version, :integer)
      timestamps()
    end
  end

  describe "erlaubte_felder/1" do
    test "returns writable fields excluding internal fields" do
      assert Shared.Util.Schema.erlaubte_felder(DummySchema) == [:name, :email]
    end

    test "excludes :id, :lock_version, :inserted_at, :updated_at" do
      all_fields = DummySchema.__schema__(:fields)
      erlaubte = Shared.Util.Schema.erlaubte_felder(DummySchema)

      refute :id in erlaubte
      refute :lock_version in erlaubte
      refute :inserted_at in erlaubte
      refute :updated_at in erlaubte
      assert length(erlaubte) == length(all_fields) - 4
    end
  end
end
