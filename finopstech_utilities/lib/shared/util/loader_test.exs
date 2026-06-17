defmodule Shared.Util.LoaderTest do
  @moduledoc false

  use ExUnit.Case, async: true

  defmodule User do
    @moduledoc false
    defstruct [:id, :name]
  end

  defmodule Account do
    @moduledoc false
    defstruct [:id, :balance]
  end

  defmodule FakeRepo do
    @moduledoc false
    alias Shared.Util.LoaderTest.Account
    alias Shared.Util.LoaderTest.User

    @data %{
      {User, 1} => %User{id: 1, name: "Jörn"},
      {Account, 1} => %Account{id: 1, balance: 100},
      {Account, 2} => %Account{id: 2, balance: 5}
    }

    def get!(schema, id) do
      case Map.get(@data, {schema, id}) do
        nil -> raise %Ecto.NoResultsError{message: "no result for #{inspect(schema)} #{id}"}
        entity -> entity
      end
    end
  end

  defmodule Subject do
    @moduledoc false
    use Shared.Util.Loader, repo: FakeRepo

    alias Shared.Util.LoaderTest.Account
    alias Shared.Util.LoaderTest.FakeRepo
    alias Shared.Util.LoaderTest.User

    @load user: User
    def name_of(user), do: user.name

    @load from: Account, to: Account
    def total(from, to, factor), do: (from.balance + to.balance) * factor

    # nicht annotiert -> bleibt unverändert (ID kommt roh an)
    def echo(value), do: value

    # explizites {Repo, Schema} überschreibt das Default-Repo
    @load account: {FakeRepo, Account}
    def balance_of(account), do: account.balance

    # Guard läuft auf der rohen ID, danach ist `user` die Entity
    @load user: User
    def greet(user) when is_integer(user), do: "Hallo #{user.name}"

    # Parameter per Keyword-Pattern im Kopf gebunden
    @load user: User
    def login(user: user), do: user.name

    # Keyword-Pattern mit anderem Variablennamen + weiterem (rohen) Key
    @load user: User
    def login_as(user: u, role: role), do: "#{u.name}/#{role}"
  end

  describe "@load auf einem Parameter" do
    test "lädt die Entity und übergibt sie an den Body" do
      assert Subject.name_of(1) == "Jörn"
    end

    test "wirft Ecto.NoResultsError, wenn die Entity fehlt" do
      assert_raise Ecto.NoResultsError, fn -> Subject.name_of(999) end
    end
  end

  describe "@load auf mehreren Parametern" do
    test "lädt nur die annotierten, der Rest läuft unverändert durch" do
      # from(1)=100, to(2)=5, factor bleibt roh = 2
      assert Subject.total(1, 2, 2) == 210
    end
  end

  describe "nicht annotierte Funktionen" do
    test "bleiben unverändert" do
      assert Subject.echo(:raw) == :raw
      assert Subject.echo(123) == 123
    end
  end

  describe "{Repo, Schema}-Override" do
    test "nutzt das explizit angegebene Repo" do
      assert Subject.balance_of(1) == 100
    end
  end

  describe "Guards" do
    test "bleiben erhalten und greifen auf der rohen ID" do
      assert Subject.greet(1) == "Hallo Jörn"
    end

    test "FunctionClauseError, wenn der Guard auf der ID nicht passt" do
      assert_raise FunctionClauseError, fn -> Subject.greet("1") end
    end
  end

  describe "Parameter per Keyword-Pattern im Funktionskopf" do
    test "lädt die unter dem Key gebundene Variable" do
      assert Subject.login(user: 1) == "Jörn"
    end

    test "funktioniert mit abweichendem Variablennamen, andere Keys bleiben roh" do
      assert Subject.login_as(user: 1, role: :admin) == "Jörn/admin"
    end

    test "wirft Ecto.NoResultsError auch hier, wenn die Entity fehlt" do
      assert_raise Ecto.NoResultsError, fn -> Subject.login(user: 999) end
    end
  end
end
