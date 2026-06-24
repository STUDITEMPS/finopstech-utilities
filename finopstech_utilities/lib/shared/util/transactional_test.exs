defmodule Shared.Util.TransactionalTest do
  @moduledoc false

  use ExUnit.Case, async: true

  defmodule FakeRepo do
    @moduledoc false

    # Protokolliert jeden transact/1-Aufruf, damit der Test belegen kann, dass
    # der Rumpf tatsächlich innerhalb der Transaktion lief. Die Funktion wird
    # einfach ausgeführt und ihr Ergebnis durchgereicht.
    def transact(fun) when is_function(fun, 0) do
      send(self(), :transact_aufgerufen)
      fun.()
    end
  end

  defmodule Subject do
    @moduledoc false
    use Shared.Util.Transactional, repo: Shared.Util.TransactionalTest.FakeRepo

    @transactional true
    def transfer(from, to, betrag) do
      {:ok, {from, to, betrag}}
    end

    # nicht annotiert -> läuft ohne Transaktion
    def echo(value), do: value

    # gemischt: nur die annotierten Klauseln werden gewrappt, die dazwischen
    # liegende, nicht annotierte Klausel bleibt unverändert.
    @transactional true
    def klassifiziere(n) when n > 0, do: {:ok, :positiv}
    def klassifiziere(0), do: {:ok, :null}
    @transactional true
    def klassifiziere(_n), do: {:ok, :negativ}
  end

  describe "@transactional true" do
    test "wickelt den Rumpf in Repo.transact/1 und reicht das Ergebnis durch" do
      assert Subject.transfer(1, 2, 100) == {:ok, {1, 2, 100}}
      assert_received :transact_aufgerufen
    end
  end

  describe "nicht annotierte Funktionen" do
    test "laufen ohne Transaktion" do
      assert Subject.echo(:raw) == :raw
      refute_received :transact_aufgerufen
    end
  end

  describe "mehrere Klauseln & Guards" do
    test "nur annotierte Klauseln laufen in einer Transaktion" do
      # erste Klausel: annotiert + Guard -> gewrappt
      assert Subject.klassifiziere(5) == {:ok, :positiv}
      assert_received :transact_aufgerufen

      # mittlere Klausel: nicht annotiert -> bleibt unverändert
      assert Subject.klassifiziere(0) == {:ok, :null}
      refute_received :transact_aufgerufen

      # letzte Klausel: wieder annotiert -> gewrappt
      assert Subject.klassifiziere(-3) == {:ok, :negativ}
      assert_received :transact_aufgerufen
    end
  end
end
