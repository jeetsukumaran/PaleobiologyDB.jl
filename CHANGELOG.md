## PaleobiologyDB.jl v1.1.2

### Added

- Incorporated [Aqua.jl](https://github.com/JuliaTesting/Aqua.jl) for automated quality assurance.

## PaleobiologyDB.jl v1.1.1

### Changed

- Updated install instructions and DOI in README.

## PaleobiologyDB.jl v1.1.0

### Highlights

- New `ApiHelp` in-package API reference with interactive helpers.
- New `pbdb_config` endpoint wrapper.
- Better ergonomics for geographic collection summaries via `pbdb_collections_geo`.
- Support and documentation for PBDB “extended” identifiers (e.g., `occ:1001`, `col:1003`) via `extids=true`.
- Substantial README overhaul plus a runnable `examples/readme.jl`.
- More robust HTTP behavior (longer default read timeout, surfaced retry controls).

### Added

- `PaleobiologyDB.ApiHelp` module providing:

  - `pbdb_help`, `pbdb_endpoints`, `pbdb_parameters`, `pbdb_fields`, `pbdb_api_search`.
- New wrapper:

  - `pbdb_config` for PBDB configuration tables (e.g., clusters, ranks, continents).
- `pbdb_collections_geo` now available in two forms:

  - Positional `pbdb_collections_geo(level; ...)` (Julia-style).
  - Keyword `pbdb_collections_geo(; level, ...)` maintained for compatibility.
- Explicit JSON handling for autocomplete endpoints:

  - `pbdb_taxa_auto`, `pbdb_strata_auto` request JSON and return `DataFrame`s.
- `examples/readme.jl` with labeled, runnable versions of README examples and success notices.
- `JuliaFormatter.toml` (SciML style) to standardize code formatting.

### Changed

- README expanded and reorganized:

  - Clear mapping from PBDB endpoints to package functions.
  - Consistent use of `vocab="pbdb"` and `extids=true` in examples.
  - Demonstrations of both numeric ids and extended ids (e.g., `occ:…`, `col:…`, `spm:…`).
  - Added sections on the built-in API help, and curated external references.
- Module layout refactor:

  - Core client moved into `src/dbapi.jl`.
  - Documentation helpers in `src/pbdbdocs.jl`.
  - Top-level `src/PaleobiologyDB.jl` simplified to `include(...)` and updated docstrings.
- HTTP defaults:

  - Default read timeout increased to `300` seconds.
  - Retry parameters surfaced and propagated through the request path.

### Fixed

- README code fence typo (extraneous backtick).
- Multiple documentation and example inconsistencies around ids, `show` blocks, and vocabularies.

### Notes on compatibility

- No breaking API removals.
- The new positional `pbdb_collections_geo(level; ...)` does not affect existing code; the keyword form remains.
- Text formats still default to `vocab="pbdb"` when not provided.
- Extended identifiers are opt-in via `extids=true`; numeric ids continue to work.

### Acknowledgments and housekeeping

- Acknowledgments updated to credit PBDB and align endpoint naming with the paleobioDB R package.
- Formatting consistently enforced via the new `JuliaFormatter.toml`.
