if Code.ensure_loaded?(Gherkin) do
  defmodule Mix.Tasks.Test.GeneriereSpezifikation do
    @shortdoc "Generiere die Spezifikationsschritte anhand einer .feature Datei"

    @moduledoc """
    Generiert das test script mit den notwendigen Step-Definitionen anhand einer Gherkin-`.feature`-Datei.

    ## Verwendung

        mix test.generiere_spezifikation [Optionen] pfad/zur/datei.feature

    Existiert die Zieldatei bereits, werden nur die noch fehlenden Schritte
    ergänzt. Mit `--force` wird die Datei komplett neu geschrieben.

    ## Optionen

      * `--template` / `-t` — das Feature-Template-Modul, das im generierten Test
        per `use` eingebunden wird. Ohne Angabe wird das Template ermittelt
        (siehe Konfiguration).
      * `--async` / `-a` — Gibt an ob die Spezifikation als async generiert werden
        soll. Ohne Angabe greift die Konfiguration (siehe Konfiguration).
      * `--output` / `-o` — Datei in den das test modul geschrieben wird
      * `--force` / `-f` — schreibt die Zieldatei komplett neu, statt eine
        vorhandene zu aktualisieren, und überspringt die Template-Prüfung.

    ## Konfiguration

    Die Generierung lässt unter `:feature_generation` konfigurieren:

    ### Konfigurationsoptionen

      * `:template` — Das module, das als feature Template in das test file generiert wird.
      * `:async` — Wenn angegeben wird die async: option emtsprechend dem Test Template mit übergeben.

    ### Beispiel

        config :finopstech_utilities, :feature_generation,
          template: MeineApp.Feature,
          async: true

    generiert

        use MeineApp.Feature, async: true, file: "output/path.exs"

    Ist `:template` nicht gesetzt, wird das aus dem Projekt-Modul abgeleitete
    `<Projekt>.Feature` verwendet (z. B. `MeinApp.Feature` für die App
    `:mein_app`), sofern dieses Modul existiert; andernfalls `Cabbage.Feature`,
    begleitet von einer Warnung.
    """

    use Mix.Task

    alias __MODULE__.MissingStep

    @requirements ["app.config"]

    @fallback_template Cabbage.Feature

    # Per compile_env konfigurierbare Generierungs-Optionen, gebündelt unter einem
    # Schlüssel: config :finopstech_utilities, :feature_generation, template: MeinModul, async: true
    @feature_generation Application.compile_env(:finopstech_utilities, :feature_generation, [])
    @configured_template @feature_generation[:template]
    @configured_async @feature_generation[:async]

    @options [force: :boolean, template: :string, async: :boolean, output: :string]
    @aliases [f: :force, t: :template, a: :async, o: :output]

    @step_macros [:defgiven, :defwhen, :defthen]
    @locals_without_parens Enum.map(@step_macros, &{&1, 4})

    @impl Mix.Task
    def run(args) do
      {opts, args} = OptionParser.parse!(args, strict: @options, aliases: @aliases)

      dateipfad = dateipfad(args)
      template = template_module(opts[:template])
      use_opts = use_options(dateipfad, Keyword.get(opts, :async, @configured_async))
      module_name = test_module_name(dateipfad)
      zielpfad = opts[:output] || test_file_path(module_name)

      %{scenarios: szenarios} = dateipfad |> File.read!() |> Gherkin.parse()

      steps =
        for szenario <- szenarios,
            step <- extract_scenario_steps(szenario),
            uniq: true,
            do: step

      if File.exists?(zielpfad) and !opts[:force] do
        aktualisiere(zielpfad, steps)
      else
        schreibe_neu(zielpfad, module_name, template, use_opts, steps)
      end

      :ok
    end

    # Schreibt eine vollständige neue Testdatei (auch bei --force).
    defp schreibe_neu(zielpfad, module_name, template, use_opts, steps) do
      module =
        quote do
          defmodule unquote(module_name) do
            use unquote(template), unquote(use_opts)

            unquote_splicing(Enum.map(steps, & &1.definition))
          end
        end

      File.write!(zielpfad, module |> quoted_to_string() |> mix_format(zielpfad))
      Mix.shell().info("Spezifikation geschrieben nach #{zielpfad}")
    end

    # Aktualisiert eine vorhandene Testdatei: bestehende Schritte werden aus dem
    # AST gelesen und nur die noch fehlenden vor dem Modul-`end` ergänzt.
    defp aktualisiere(zielpfad, steps) do
      content = File.read!(zielpfad)
      ast = Code.string_to_quoted!(content, token_metadata: true, columns: true)
      vorhandene = existing_step_patterns(ast)

      case Enum.reject(steps, &MapSet.member?(vorhandene, normalize_pattern(&1.pattern))) do
        [] ->
          Mix.shell().info("#{zielpfad}: keine fehlenden Schritte — nichts zu tun.")

        fehlende ->
          File.write!(zielpfad, insert_steps(content, ast, fehlende, zielpfad))
          Mix.shell().info("#{zielpfad}: #{length(fehlende)} fehlende(n) Schritt(e) ergänzt.")
      end
    end

    defp dateipfad([dateipfad]), do: dateipfad

    defp dateipfad(_args) do
      Mix.raise("""
      Ungültige Argumente. Aufruf:

        mix test.generiere_spezifikation [--force] [--async] [--output Pfad] [--template Modul] <pfad/zur/datei.feature>
      """)
    end

    defp template_module(nil), do: @configured_template || abgeleitetes_template()
    defp template_module(name) when is_binary(name), do: Module.concat([name])

    # Leitet das Feature-Template aus dem Projekt-Modul ab (z. B. MeinApp.Feature
    # für die App :mein_app). Existiert dieses Modul nicht, wird mit einer Warnung
    # auf Cabbage.Feature zurückgefallen.
    defp abgeleitetes_template do
      kandidat = Module.concat([Macro.camelize("#{Mix.Project.config()[:app]}"), "Feature"])

      if Code.ensure_loaded?(kandidat), do: kandidat, else: fallback_template(kandidat)
    end

    defp fallback_template(kandidat) do
      Mix.shell().info("""
      Feature-Template #{inspect(kandidat)} nicht gefunden. #{inspect(@fallback_template)} wird verwendet.

      Erstelle #{inspect(kandidat)}, oder konfiguriere ein anderes Feature-Template,

          config :finopstech_utilities, :feature_generation, template: MeinApp.Feature

      oder gib es über --template (oder -t) an (z.B. `-t MeinApp.Feature`).
      """)

      @fallback_template
    end

    # `async:` wird nur ergänzt, wenn es per --async/--no-async oder per Konfiguration
    # gesetzt ist; ohne beides (nil) bleibt es weg.
    defp use_options(file, nil), do: [file: file]
    defp use_options(file, async), do: [file: file, async: async]

    defp test_module_name(dateipfad), do: Module.concat([Macro.camelize(Path.rootname(dateipfad) <> "_test")])
    defp test_file_path(modulename), do: Macro.underscore(modulename) <> ".ex"

    # Rendert ein Quoted-AST klammerlos zu Quelltext. quoted_to_algebra ist nötig,
    # weil der Formatter vorhandene Klammern nicht entfernt; locals_without_parens
    # steuert die klammerlose Ausgabe der Step-Makros.
    defp quoted_to_string(quoted) do
      quoted
      |> Code.quoted_to_algebra(locals_without_parens: @locals_without_parens)
      |> Inspect.Algebra.format(:infinity)
      |> IO.iodata_to_binary()
    end

    # Wendet exakt die mix-format-Regeln der Zieldatei an (inkl. .formatter.exs-
    # Optionen und Plugins wie Styler), sodass ein anschließendes `mix format`
    # die Datei nicht mehr verändert.
    defp mix_format(source, file) do
      {formatter, _opts} = Mix.Tasks.Format.formatter_for_file(file)
      formatter.(source)
    end

    # Sammelt die Regex-Muster aller bereits im AST definierten Schritte.
    defp existing_step_patterns(ast) do
      {_ast, patterns} =
        Macro.prewalk(ast, [], fn
          {macro, _meta, [pattern | _]} = node, acc when macro in @step_macros ->
            {node, prepend_pattern(pattern, acc)}

          node, acc ->
            {node, acc}
        end)

      MapSet.new(patterns)
    end

    defp prepend_pattern({:sigil_r, _, [{:<<>>, _, [source]}, _modifiers]}, acc) when is_binary(source) do
      [normalize_pattern(source) | acc]
    end

    defp prepend_pattern(_other, acc), do: acc

    # Vereinheitlicht ein Regex-Muster für den Dedup-Vergleich, indem die Namen
    # der benannten Captures entfernt werden: `(?<number_1>\d+)` -> `(?<>\d+)`.
    defp normalize_pattern(pattern), do: String.replace(pattern, ~r/\(\?<[^>]+>/, "(?<>")

    # Fügt die gerenderten Schritt-Definitionen direkt vor dem schließenden `end`
    # des Moduls ein; der restliche Dateiinhalt bleibt unverändert.
    defp insert_steps(content, {:defmodule, meta, _}, steps, file) do
      end_line = meta |> Keyword.fetch!(:end) |> Keyword.fetch!(:line)

      content
      |> String.split("\n")
      |> List.insert_at(end_line - 1, render_steps(steps))
      |> Enum.join("\n")
      |> mix_format(file)
    end

    defp render_steps(steps), do: Enum.map_join(steps, "\n", &quoted_to_string(&1.definition))

    defp extract_scenario_steps(%{steps: steps}) do
      steps
      |> Enum.map_reduce(nil, fn step, last_step_type ->
        step_type = step_type(step, last_step_type)
        extra_vars = %{table: step.table_data, doc_string: step.doc_string}

        {MissingStep.new(step_text: step.text, step_type: step_type, extra_vars: extra_vars), step_type}
      end)
      |> elem(0)
    end

    defp step_type(%Gherkin.Elements.Step{keyword: type}, last_step_type), do: step_type(type, last_step_type)
    defp step_type("Angenommen", _), do: :given
    defp step_type("Given", _), do: :given
    defp step_type("Wenn", _), do: :when
    defp step_type("When", _), do: :when
    defp step_type("Dann", _), do: :then
    defp step_type("Then", _), do: :then
    defp step_type("Und", nil), do: raise("Und darf erst nach Angenommen, Wenn oder Dann kommen")
    defp step_type("And", nil), do: raise("And must follow after Given, When or Then")
    defp step_type("Und", last_step_type), do: last_step_type
    defp step_type("And", last_step_type), do: last_step_type
  end

  defmodule Mix.Tasks.Test.GeneriereSpezifikation.MissingStep do
    @moduledoc false
    @number_regex ~r/(^|\s)\d+(\s|$)/
    @single_quote_regex ~r/'[^']+'/
    @double_quote_regex ~r/"[^"]+"/

    defstruct [:definition, :pattern]

    def new(step_text: step_text, step_type: step_type, extra_vars: extra_vars) do
      {converted_step_text, list_of_vars} =
        {step_text, []}
        |> convert_nums()
        |> convert_double_quote_strings()
        |> convert_single_quote_strings()
        |> convert_extra_vars(extra_vars)

      map_of_vars = vars_to_correct_format(list_of_vars)
      pattern = "^#{converted_step_text}$"

      definition =
        quote do
          unquote(:"def#{step_type}")(unquote(regex(pattern)), unquote(map_of_vars), _state) do
            :ok
          end
        end

      %__MODULE__{definition: definition, pattern: pattern}
    end

    defp regex(pattern), do: {:sigil_r, [delimiter: "/"], [{:<<>>, [], [pattern]}, []]}

    defp convert_nums({step_text, vars}) do
      @number_regex
      |> Regex.split(step_text)
      |> join_regex_split(1, :number, {"", vars})
    end

    defp convert_double_quote_strings({step_text, vars}) do
      @double_quote_regex
      |> Regex.split(step_text)
      |> join_regex_split(1, :double_quote_string, {"", vars})
    end

    defp convert_single_quote_strings({step_text, vars}) do
      @single_quote_regex
      |> Regex.split(step_text)
      |> join_regex_split(1, :single_quote_string, {"", vars})
    end

    defp convert_extra_vars({step_text, vars}, %{doc_string: doc_string, table: table}) do
      vars = if doc_string == "", do: vars, else: vars ++ ["doc_string"]
      vars = if table == [], do: vars, else: vars ++ ["table"]

      {step_text, vars}
    end

    defp join_regex_split([], _count, _type, {acc, vars}) do
      {String.trim(acc), vars}
    end

    defp join_regex_split([head | []], _count, _type, {acc, vars}) do
      {String.trim(acc <> head), vars}
    end

    defp join_regex_split([head | tail], count, type, {acc, vars}) do
      step_text = acc <> head <> get_regex_capture_string(type, count)
      vars = vars ++ [get_var_string(type, count)]

      join_regex_split(tail, count + 1, type, {step_text, vars})
    end

    defp get_regex_capture_string(:number, count), do: ~s/(?<number_#{count}>\\d+) /

    defp get_regex_capture_string(:single_quote_string, count), do: ~s/'(?<string_#{count}>[^']+)'/

    defp get_regex_capture_string(:double_quote_string, count), do: ~s/"(?<string_#{count}>[^"]+)"/

    defp get_var_string(:number, count), do: "number_#{count}"
    defp get_var_string(:single_quote_string, count), do: "string_#{count}"
    defp get_var_string(:double_quote_string, count), do: "string_#{count}"

    defp vars_to_correct_format([]), do: quote(do: _vars)

    defp vars_to_correct_format(vars) do
      mapping =
        vars
        |> Enum.map(&String.to_atom/1)
        |> Enum.map(&{&1, Macro.var(&1, nil)})

      {:%{}, [], mapping}
    end
  end
end
