defmodule ReleaseTaskTestApp.ReleaseTasks.Greeting do
  @moduledoc false
  @behaviour FinopstechUtilities.ReleaseTask

  @impl true
  def ausfuehren(args), do: IO.puts(["Hallo ", Enum.join(args, " ")])
end

defmodule FinopstechUtilities.ReleaseTaskTest do
  @moduledoc false

  use ExUnit.Case

  import ExUnit.CaptureIO

  alias FinopstechUtilities.ReleaseTask
  alias ReleaseTaskTestApp.ReleaseTasks

  describe "ermittle_task/2" do
    setup do
      %{tasks: %{"greeting" => ReleaseTasks.Greeting}}
    end

    test "liefert die MFA des passenden Tasks mit den restlichen Argumenten", %{tasks: tasks} do
      assert ReleaseTask.ermittle_task(tasks, ["greeting", "schöne", "Welt"]) ==
               {ReleaseTasks.Greeting, :ausfuehren, [["schöne", "Welt"]]}
    end

    test "die ermittelte MFA ruft den Task auf", %{tasks: tasks} do
      {module, function, arguments} = ReleaseTask.ermittle_task(tasks, ["greeting", "Welt"])

      assert capture_io(fn -> apply(module, function, arguments) end) == "Hallo Welt\n"
    end

    test "wirft, wenn das gefundene Modul das Verhalten nicht implementiert" do
      tasks = %{"kaputt" => FinopstechUtilities.Modules}

      assert_raise RuntimeError, ~r/implementiert nicht/, fn ->
        ReleaseTask.ermittle_task(tasks, ["kaputt"])
      end
    end

    test "wirft bei unbekanntem Task und schlägt einen ähnlichen vor", %{tasks: tasks} do
      error = assert_raise RuntimeError, fn -> ReleaseTask.ermittle_task(tasks, ["greting"]) end

      assert error.message =~ "greting"
      assert error.message =~ "greeting"
    end

    test "wirft ohne Task-Namen und listet die verfügbaren Tasks auf", %{tasks: tasks} do
      error = assert_raise RuntimeError, fn -> ReleaseTask.ermittle_task(tasks, []) end

      assert error.message =~ "kein Task angegeben"
      assert error.message =~ "greeting"
    end

    test "wirft, wenn keine Tasks definiert sind" do
      assert_raise RuntimeError, ~r/keine Release-Tasks/, fn ->
        ReleaseTask.ermittle_task(%{}, ["irgendwas"])
      end
    end

    test "nennt bei keinen Tasks den durchsuchten Namespace" do
      error =
        assert_raise RuntimeError, fn ->
          ReleaseTask.ermittle_task(%{}, ["irgendwas"], in_namespace: ReleaseTasks)
        end

      assert error.message =~ "Namespace"
      assert error.message =~ inspect(ReleaseTasks)
    end

    test "nennt bei keinen Tasks die Gruppenmarkierung" do
      error =
        assert_raise RuntimeError, fn ->
          ReleaseTask.ermittle_task(%{}, ["irgendwas"], group: :release_tasks)
        end

      assert error.message =~ "Gruppenmarkierung"
      assert error.message =~ ":release_tasks"
    end
  end

  describe "ausfuehren/2" do
    test "wirft eine Exception, wenn kein passender Task gefunden wird" do
      assert_raise RuntimeError, ~r/keine Release-Tasks/, fn ->
        ReleaseTask.ausfuehren(["migrieren"],
          app: :finopstech_utilities,
          in_namespace: __MODULE__.GibtsNicht
        )
      end
    end
  end
end
