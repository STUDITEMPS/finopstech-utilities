# Used by "mix format"
locals_without_parens = [format_csv: 2, format_csv: 3]

[
  plugins: [Styler],
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  locals_without_parens: locals_without_parens,
  # Wird von abhängigen Projekten via `import_deps: [:finopstech_utilities]`
  # übernommen, damit `format_csv` auch dort ohne Klammern formatiert wird.
  export: [locals_without_parens: locals_without_parens]
]
