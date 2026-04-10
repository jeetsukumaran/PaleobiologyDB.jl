# STYLE.md — Julia Functional Design Principles

This document governs how code in this project should be *designed*, regardless
of who or what writes it. It applies to all contributors — human and AI alike.

The paradigm is **idiomatic functional Julia**: functional principles applied
with Julia's grain, not against it. The goal is equational reasoning, local
correctness, and composability — not syntactic purity or Haskell cosplay. Where
Julia's idioms and FP principles align, follow both. Where performance requires
mutation, use the mutation contract in §3.

Code style formatting is enforced by `Runic.jl` (SciML standard). This
document covers *design* decisions that no formatter can enforce.

**Upstream authority**: [SciML Style Guide](https://docs.sciml.ai/SciMLStyle/dev/)
is the normative reference. This document extends and contextualizes it with
functional design principles.

When they conflict, programmer judgement wins.

---

## 1. Core principles and their Julia expression

The principles below are ordered from most foundational to most derived. Each
one follows from the one above it. All are in force unless §3 creates an
explicit carve-out.

---

### 1.1 Pure functions

> A function's output depends only on its inputs. No hidden state, no
> interaction with the outside world.

A function is pure if — given the same arguments — it always returns the same
value and does nothing else observable. Purity is the basis for every other
property: equational reasoning, safe caching, parallelism, and testability all
depend on it.

**In Julia:**

```julia
# Pure: output determined entirely by inputs
function diversity_index(counts::AbstractVector{<:Integer})::Float64
    n = sum(counts)
    n == 0 && return 0.0
    return -sum(c/n * log(c/n) for c in counts if c > 0)
end

# Impure: reads from a module-level cache — hidden dependency
function diversity_index(counts::AbstractVector{<:Integer})::Float64
    n = sum(counts)
    return -sum(c/n * log(c/n) for c in _CACHE if c > 0)  # don't do this
end
```

**Rules:**
- All required context is passed as arguments, not read from globals or closure
  state.
- Network I/O, file I/O, logging, and random number generation are side effects
  — they make a function impure. Push them to the boundary of the computation
  (see §1.14).
- A pure function can call other pure functions freely. It cannot call impure
  functions without becoming impure itself.

---

### 1.2 No side effects (effects made explicit)

> Evaluation does not mutate external state, perform I/O, or alter shared data.
> All effects must be made explicit — via return values, the `!` convention, or
> explicit effect parameters.

Julia's convention for making effects explicit is the `!` suffix on mutating
functions. This is not decoration — it is the boundary marker between the pure
core and the effectful layer.

**In Julia:**

```julia
# Effect-free: returns a new value
function normalize_counts(v::AbstractVector{<:Real})::Vector{Float64}
    total = sum(v)
    return v ./ total
end

# Effect-explicit: mutates in place, clearly marked
function normalize_counts!(v::AbstractVector{<:Real})::AbstractVector{<:Real}
    v ./= sum(v)
    return v
end
```

**Rules:**
- The `!` suffix is mandatory on any function that mutates one of its arguments.
  No exceptions.
- Do not add `!` to functions whose name already implies mutation (e.g.
  `push!`, `append!` from Base — already marked).
- A function without `!` must not mutate its arguments. Callers rely on this
  contract; violating it silently is a correctness bug.
- I/O (logging, file writes, network calls) belongs in explicitly named
  functions at the boundary, not buried inside computation functions.

---

### 1.3 Referential transparency

> An expression can be replaced with its value without changing program behavior.
> This is the property that enables equational reasoning.

A function is referentially transparent if you can substitute any call to it
with its return value everywhere and the program behaves identically. This
follows directly from purity and no-side-effects.

**In Julia**, referential transparency allows you to:
- Safely memoize or cache any call.
- Reorder calls during refactoring without fear.
- Reason about correctness locally, one function at a time.

```julia
# Referentially transparent — result depends only on inputs
taxon_richness(occurrences)::Int = length(unique(o.taxon_id for o in occurrences))

# Not transparent — result depends on when you call it
function taxon_richness(occurrences)::Int
    return length(unique(o.taxon_id for o in occurrences)) + rand()  # don't
end
```

**Rules:**
- Random number generation breaks referential transparency. Functions that use
  an RNG must accept it as an explicit argument (e.g. `rng::AbstractRNG`).
- Timestamps, UUIDs, or any other non-deterministic value must be injected,
  not generated inside a pure function.
- Memoization (`Memoize.jl` or manual caches) is only valid on referentially
  transparent functions. Do not cache impure functions.

---

### 1.4 Immutability

> Data structures are not modified after creation. "Updates" produce new values
> instead of mutating existing ones.

**In Julia**, immutability is the default for `struct`. Prefer it unless
mutation is required for performance (see §3).

```julia
# Preferred: immutable struct — fields cannot change after construction
struct OccurrenceRecord
    taxon_id::Int
    age_ma::Float64
    locality::String
end

# Use only when mutation is a genuine requirement
mutable struct SolverCache
    jacobian::Matrix{Float64}
    residual::Vector{Float64}
end
```

**Rules:**
- Default to `struct`, not `mutable struct`. Justify every `mutable struct` in
  a comment.
- Do not mutate a `struct`'s fields from outside the module that defines it.
- Prefer returning modified copies over modifying in place:
  `with_age(r::OccurrenceRecord, age::Float64)::OccurrenceRecord = OccurrenceRecord(r.taxon_id, age, r.locality)`
- For large scientific data, the mutation contract in §3 applies — but only
  for performance-critical paths, and only via `!`-named functions.

---

### 1.5 First-class and higher-order functions

> Functions are values: they can be passed, returned, and composed. Higher-order
> functions abstract control flow.

Julia treats functions as first-class values natively. `map`, `filter`,
`reduce`, `foldl`, `mapreduce`, and broadcasting (`.`) are the primary tools
for applying functions to collections.

```julia
# Prefer higher-order over explicit loops when it aids clarity
taxon_ids  = map(o -> o.taxon_id, occurrences)
valid_occs = filter(o -> o.age_ma > 0.0, occurrences)
total_span = mapreduce(o -> o.age_ma, max, occurrences; init=0.0)

# Broadcasting: apply f elementwise without explicit loop
log_ages = log.(getfield.(occurrences, :age_ma))
```

**Rules:**
- Prefer `map`/`filter`/`reduce` over explicit `for` loops when the operation
  is a pure transformation of each element. Use `for` when sequencing or
  accumulation is genuinely imperative.
- Do not use anonymous functions `x -> ...` for non-trivial logic — extract a
  named function instead.
- Avoid capturing mutable variables in closures. Closures over mutable state
  are hard to reason about and can cause Julia compiler performance issues.
  Prefer passing state as explicit arguments.
- SciML guidance: closures should be avoided when possible due to potential
  world-age and compilation issues.

---

### 1.6 Function composition

> Build complex behavior by composing simpler functions: `h = f ∘ g` instead
> of sequencing statements.

Julia provides the `∘` operator (typed `\circ`) for function composition and
`|>` for left-to-right pipeline application.

```julia
# Composition with ∘
log_normalize = log ∘ normalize_counts

# Pipeline with |>
result = occurrences |> filter_valid |> extract_ages |> sort

# Multi-step pipeline (readable for data transformations)
diversity = occurrences   |>
            filter_valid  |>
            count_by_taxa |>
            diversity_index
```

**Rules:**
- Use `∘` when defining a reusable composed function. Use `|>` for one-off
  pipelines in call sites.
- Each composed function must itself be pure and single-purpose. Composing
  impure functions propagates their side effects — be explicit when you do this.
- Do not pipeline through `!`-functions expecting immutable semantics.
- Prefer composition over nested function calls when there are more than ~3
  layers of nesting: `h(g(f(x)))` → `(h ∘ g ∘ f)(x)` or a named intermediate.

---

### 1.7 Declarative style

> Describe *what* is computed, not *how* step-by-step execution proceeds.

Declarative code expresses intent. Imperative code expresses mechanism.
Prefer declarative when the declarative form is equally or more readable.

```julia
# Declarative: state what you want
ranges = [maximum(ages) - minimum(ages) for ages in grouped_ages]

# Imperative: state how to get it
ranges = Float64[]
for ages in grouped_ages
    push!(ranges, maximum(ages) - minimum(ages))
end
```

**Rules:**
- Prefer comprehensions over `for`+`push!` loops for building collections.
- Prefer `map`/`filter`/`reduce` over loops for pure transformations.
- Prefer broadcasting over manual element iteration.
- Exception: when the imperative form is substantially faster and that
  performance matters, use it — but document why. Declarative is the default;
  performance is the override.
- Quarto/documentation code should be maximally declarative — readers are
  learning the domain, not Julia internals.

---

### 1.8 Idempotency

> Applying a function multiple times yields the same result as once:
> `f(f(x)) == f(x)`. Required at effectful boundaries; not required for all
> pure functions.

In scientific computing, idempotency matters most at:
- **Cache population**: fetching or computing a cached result a second time
  should return the same value as the first.
- **Data normalization**: normalizing already-normalized data should be a no-op.
- **API boundaries**: registering a resource that already exists should not error.

```julia
# Idempotent cache fetch — calling twice is safe
function fetch_occurrences(taxon::String, cache::OccurrenceCache)::Vector{OccurrenceRecord}
    haskey(cache, taxon) && return cache[taxon]
    result = _fetch_from_pbdb(taxon)
    cache[taxon] = result
    return result
end
```

**Rules:**
- Explicitly design for idempotency at I/O boundaries, caches, and any
  function that registers or writes state.
- Document when a function is intentionally non-idempotent (e.g. "each call
  appends a new row").
- For pure functions, idempotency is not required but is a useful property
  worth noting when it holds (e.g. `normalize` on a normalized vector).

---

### 1.9 Statelessness

> No reliance on mutable or global state; all required context is passed
> explicitly.

Global state — module-level mutable variables, hidden caches, global
configuration — makes functions context-dependent and untestable. SciML
explicitly states: globals should be avoided whenever possible.

```julia
# Bad: depends on hidden module-level state
const _CONFIG = Dict{Symbol,Any}()
function get_api_url()::String
    return _CONFIG[:api_url]  # hidden dependency
end

# Good: context passed explicitly
function get_api_url(config::NamedTuple)::String
    return config.api_url
end
```

**Rules:**
- Module-level `const` for genuinely constant values (mathematical constants,
  fixed lookup tables) is acceptable. These are not "state" — they never change.
- Module-level mutable variables (`Ref`, `Dict`, etc.) are global state.
  Avoid them. Pass configuration, caches, and accumulators as function arguments.
- Exception for caches at module boundaries: use a `Cache` struct passed
  explicitly, not a hidden module-level `Dict`.
- Thread safety: any function that reads or writes global state is not
  re-entrant. See §1.13.

---

### 1.10 Expression orientation

> Programs are built from expressions that evaluate to values, not statements
> that perform actions.

Julia is already expression-oriented: `if`, `begin`, `let`, and `for` are all
expressions that return values. Use this.

```julia
# Expression-oriented: if is an expression
label = if age_ma > 250.0
    "Paleozoic"
elseif age_ma > 66.0
    "Mesozoic"
else
    "Cenozoic"
end

# Avoid: mutation-based style that doesn't leverage Julia's expression model
label = ""
if age_ma > 250.0
    label = "Paleozoic"
elseif age_ma > 66.0
    label = "Mesozoic"
else
    label = "Cenozoic"
end
```

**Rules:**
- Assign the result of `if`/`begin`/`let` blocks directly when they compute a
  value — don't initialize a variable and then mutate it.
- Use `let` blocks to limit scope of intermediate bindings.
- Prefer `return expr` over assigning to a final variable and then returning it.
- The last expression in a function is its return value. Use this, but also use
  explicit `return` for clarity in non-trivial functions.

---

### 1.11 Lazy evaluation

> Values are computed only when needed. Enables working with large or infinite
> structures and improves compositionality.

Julia is eager by default but provides lazy tools. Use them for large
collections and streaming data.

```julia
# Eager — materializes the entire filtered collection
valid = filter(is_valid, occurrences)

# Lazy — evaluates only as consumed
valid = Iterators.filter(is_valid, occurrences)

# Generators — lazy by default
ages = (o.age_ma for o in occurrences if o.age_ma > 0.0)
total = sum(ages)  # never materializes the intermediate collection
```

**Tools:**
- `Iterators.map`, `Iterators.filter`, `Iterators.flatten`, `Iterators.take`
- Generator expressions `(f(x) for x in xs if pred(x))`
- `Base.Generator` for one-pass computation without allocation
- `Channel` for lazy streaming of computed results

**Rules:**
- Prefer generator expressions over `map`+`filter` chains when the result is
  immediately consumed by a reducing operation (`sum`, `maximum`, `count`).
  This avoids allocating the intermediate array.
- Do not use lazy iterators when random access (`xs[i]`) or multiple passes are
  required — materialize with `collect` in that case.
- For large scientific datasets (e.g. PBDB occurrence dumps), always prefer
  lazy streaming over loading into memory.

---

### 1.12 Type-driven design

> Types encode invariants and guide program construction. In Julia: abstract
> type hierarchies, parametric types, and multiple dispatch.

Julia's type system and multiple dispatch are its most powerful tools for
type-driven design. Use them.

```julia
# Abstract type establishes an interface
abstract type AbstractOccurrenceRecord end

# Concrete types satisfy the interface
struct MarineOccurrence <: AbstractOccurrenceRecord
    taxon_id::Int
    age_ma::Float64
    paleo_lat::Float64
    paleo_lon::Float64
end

struct TerrestrialOccurrence <: AbstractOccurrenceRecord
    taxon_id::Int
    age_ma::Float64
    formation::String
end

# Dispatch on the interface, not the concrete type
habitat(::MarineOccurrence)::Symbol = :marine
habitat(::TerrestrialOccurrence)::Symbol = :terrestrial
```

**Rules (SciML-aligned):**
- Write functions against abstract types (`AbstractVector`, `AbstractMatrix`,
  your own abstract types) rather than concrete types, unless the function is
  explicitly concrete-type-specific.
- Generic code is preferred unless the code is known to be specific — this
  enables use with GPU arrays, `StaticArrays`, `OffsetArrays`, etc.
- Internal array types should match the input type: use `similar(A)` not
  `Array{Float64}(undef, size(A))` when constructing output arrays.
- Type parameters should be used instead of `Any` or overly broad unions.
- Parametric types encode constraints: `Vector{<:AbstractOccurrenceRecord}` vs
  `Vector{Any}` — the former is a contract.
- Prefer type-stable functions. A function is type-stable if the output type
  is fully determined by the input types. Type-instability forces dynamic
  dispatch and defeats the compiler.
- Use `@code_warntype` to check for type instability in hot paths.

---

### 1.12.1 Return type annotations (mandatory)

> All public and non-trivial functions must include explicit return type
> annotations. The return type is part of the function's contract and belongs
> at the point of definition.

While Julia's compiler can infer return types, this project mandates explicit
return type annotations for the following reasons:

- **Programmer clarity**: the function's contract is visible at the point of
  definition.
- **Documentation durability**: return types serve as lightweight,
  always-in-sync documentation even when docstrings are incomplete or outdated.
- **Refactoring safety**: unintended changes to return type become immediately
  visible as a compile-time or runtime error.
- **Interface stability**: callers can rely on a fixed output type without
  inspecting implementation details.

**Examples:**

```julia
function diversity_index(counts::AbstractVector{<:Integer})::Float64
    n = sum(counts)
    n == 0 && return 0.0
    return -sum(c/n * log(c/n) for c in counts if c > 0)
end
```

```julia
function normalize_counts(v::AbstractVector{<:Real})::Vector{Float64}
    total = sum(v)
    return v ./ total
end
```

**Rules:**
- All exported (public API) functions must have explicit return type
  annotations.
- Internal helper functions must also include return annotations unless they
  are trivially local and their return type is immediately obvious from a
  single-expression body.
- Return types must be:
  - Concrete where appropriate (`Float64`, `Int`, `Vector{Float64}`), or
  - Abstract but constrained when the concrete type depends on input type
    parameters (`AbstractVector{<:Real}`).
- Do not use `Any` as a return type. If a function cannot be given a more
  specific type, it must be redesigned.
- Return type annotations must agree with actual behavior; violating the
  annotation is a correctness error.

**Relationship to type stability:**

Type stability remains required independently of this rule. Return type
annotations do not replace type stability — they make it explicit and
machine-checkable. If a function cannot be given a stable, concrete return
type, it must be redesigned before it can receive a valid annotation.

**Anti-pattern:**

```julia
# Type-unstable and unannotated — violates both requirements
function f(x)
    if x > 0
        return 1
    else
        return 1.0
    end
end
```

**Correct form:**

```julia
function f(x)::Float64
    return x > 0 ? 1.0 : 1.0
end
```

---

### 1.13 Reentrancy and thread safety

> A function is reentrant if it can be interrupted and called again (from
> another thread or callback) without corruption. This requires: no global
> mutable state, no static local state, all working memory passed as arguments.

Reentrancy is a consequence of statelessness (§1.9) applied to concurrent
execution. A pure, stateless function is automatically reentrant.

```julia
# Reentrant: all state is in arguments and return values
function compute_ltt(occurrences::AbstractVector, bins::AbstractVector)::Vector{Float64}
    # ...pure computation, no globals touched...
end

# NOT reentrant: touches module-level mutable state
const _RESULT_CACHE = Dict{String, Any}()
function compute_ltt(taxon::String)::Vector{Float64}
    _RESULT_CACHE[taxon] = _expensive_compute(taxon)  # race condition
    return _RESULT_CACHE[taxon]
end
```

**Rules:**
- A function that only reads and writes its arguments and local variables is
  automatically reentrant.
- Global mutable state (module-level `Ref`, `Dict`, etc.) destroys reentrancy.
  If a cache or accumulator must exist, it should be wrapped in a lock when
  accessed from multiple threads, or use thread-local storage.
- `Threads.@spawn` tasks should only capture immutable values or explicitly
  thread-safe data structures.
- If a function is intended to be parallelized, say so in its docstring and
  ensure it is reentrant.

---

### 1.14 Separation of effects from logic (pure core / effectful shell)

> Keep pure computation in the core. Push I/O, logging, network calls, and
> mutations to the boundary. Keeps reasoning local and controlled.

This is the architectural consequence of all the principles above. The project
structure should reflect it.

```
┌─────────────────────────────────────────┐
│  Effectful shell                         │
│  - reads files / network                │
│  - writes results / logs                │
│  - calls mutating (!) functions         │
│  ┌───────────────────────────────────┐  │
│  │  Pure core                         │  │
│  │  - transforms data                │  │
│  │  - computes results               │  │
│  │  - referentially transparent      │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

**In Julia:**

```julia
# Pure core — no I/O, testable in isolation
function compute_diversity_curve(occurrences::AbstractVector,
                                 time_bins::AbstractVector)::Vector{Float64}
    # pure computation over data structures
end

# Effectful shell — I/O lives here
function run_diversity_analysis(config::NamedTuple)::Vector{Float64}
    occurrences = fetch_occurrences(config.taxon, config.cache_dir)  # I/O
    bins = load_time_bins(config.bin_file)                           # I/O
    result = compute_diversity_curve(occurrences, bins)              # pure
    save_results(result, config.output_path)                         # I/O
    return result
end
```

**Rules:**
- Pure core functions must not perform I/O, log, or call `!`-functions on
  their arguments.
- The effectful shell functions are the only place where I/O and mutation live.
- Effectful shell functions should be thin: they orchestrate calls to pure
  functions; they should not contain domain logic.
- Tests target the pure core. The shell is tested with integration tests.

---

### 1.15 Equational reasoning

> Because of referential transparency, programs can be manipulated like algebra:
> replace equals with equals, refactor safely.

This is not a rule you enforce — it's a property you earn by following §1.1–§1.14.
When all functions in the pure core are pure and referentially transparent, you
can:

- Replace any call with its body and reason about the result algebraically.
- Refactor by substituting equivalent expressions.
- Prove properties by induction over the structure of the data.
- Trust that a passing test suite covers behavior, not execution order.

The practical payoff: you can read a function in isolation, understand it
completely, and trust that understanding at every call site. You do not need to
trace the global state to know what a function does.

---

### 1.16 DRY (Don't Repeat Yourself)

> Every piece of knowledge has a single, authoritative representation. Duplication
> means two places to update, two places to get wrong.

DRY is the design consequence of abstraction and composition. If the same
computation appears in two places, it belongs in a named function. If the same
type constraint appears in ten function signatures, it belongs in an abstract
type or type alias.

```julia
# Repeated: age validation in multiple functions
function process_a(occ::OccurrenceRecord)::OccurrenceRecord
    occ.age_ma >= 0.0 || throw(DomainError(occ.age_ma, "Age must be non-negative"))
    # ...
end
function process_b(occ::OccurrenceRecord)::OccurrenceRecord
    occ.age_ma >= 0.0 || throw(DomainError(occ.age_ma, "Age must be non-negative"))
    # ...
end

# DRY: single source of truth
function validate_age(occ::OccurrenceRecord)::OccurrenceRecord
    occ.age_ma >= 0.0 || throw(DomainError(occ.age_ma, "Age must be non-negative"))
    return occ
end
process_a(occ::OccurrenceRecord)::OccurrenceRecord = occ |> validate_age |> _process_a_impl
process_b(occ::OccurrenceRecord)::OccurrenceRecord = occ |> validate_age |> _process_b_impl
```

**Rules:**
- If you write the same logic twice, extract it. If three or more call sites
  share a pattern, it needs a name.
- Type aliases reduce repetition in signatures:
  `const OccurrenceVec = AbstractVector{<:AbstractOccurrenceRecord}`
- Constants, conversion factors, and domain values must appear exactly once —
  in a named `const`, not repeated as literals.
- DRY applies to documentation: a concept defined in a docstring should not be
  re-explained in every function that uses it; cross-reference instead.

---

## 2. SciML-specific conventions

These are drawn directly from the SciML Style Guide and are normative here.

### 2.1 Formatting

- Use `Runic.jl` for code formatting. A `.JuliaFormatter.toml` with
  `style = "sciml"` and a `FormatCheck.yml` CI action are the standard setup.
- Do not mix style PRs with functional changes.

### 2.2 Function argument order

SciML convention for argument ordering (from most to least important):

1. The function being applied `f`
2. The output array / destination `du` or `out` (for `!`-functions)
3. The primary input array / problem state `u`
4. Parameters `p`
5. Time variable `t`
6. All other arguments

```julia
# SciML-style ODE function signature
function lotka_volterra!(du::AbstractVector, u::AbstractVector, p, t)::AbstractVector
    α, β, γ, δ = p
    du[1] = α*u[1] - β*u[1]*u[2]
    du[2] = -γ*u[2] + δ*u[1]*u[2]
    return du
end
```

### 2.3 Generic array support

- Never assume 1-based indexing. Use `eachindex`, `axes`, or broadcasting.
- Construct output arrays with `similar(input)`, not `Vector{Float64}(undef, n)`,
  to preserve array type (GPU, static, offset).
- Do not hardcode `Array` when `AbstractArray` or `AbstractVector` is intended.

### 2.4 Tests

- All recommended (exported) functionality must be tested.
- Tests should cover a wide gamut of input types — not just `Vector{Float64}`.
- Known type limitations should be documented with `@test_broken`, not silently
  omitted.
- One test file per source file: `test/test_<module>.jl` mirrors `src/<module>.jl`.

### 2.5 Error handling

- Catch errors as high as possible — validate inputs at the public API boundary,
  not deep in a call chain.
- Error messages must be informative for newcomers: say what was expected, what
  was received, and what the user should do.
- Use appropriate error types: `ArgumentError` for bad inputs, `DomainError` for
  values outside a function's mathematical domain, `DimensionMismatch` for
  array size issues.

### 2.6 Packages over modules

- When in doubt, a submodule should become a subpackage or a separate package.
- Prefer interface packages over `Requires.jl` conditional modules.

### 2.7 Macros

- Use macros only for syntactic sugar where the generated code is easy to
  picture (`@.`, `@view`, `@inbounds`, `@muladd`).
- Do not define macros that generate non-obvious code or change program
  semantics in opaque ways.

---

## 3. The mutation contract

This section governs the one place where functional principles yield to
performance: in-place mutation for numerical hot paths.

### The rule

**SciML position**: a function should either (a) be non-allocating and reuse
caches, or (b) treat its inputs as immutable and return new values. It should
not do both inconsistently or halfway.

**Out-of-place is the default.** Use it whenever it is sufficiently performant.
Mutation is a performance optimization, not a default.

### When mutation is permitted

- The function is on a hot path (called millions of times in a solver loop).
- Allocating a new array on each call is a confirmed performance bottleneck
  (measured, not assumed).
- A pre-allocated cache array is passed as an argument.

### The `f` / `f!` pair pattern

When a function must be both convenient (out-of-place) and fast (in-place),
provide both:

```julia
"""
    normalize_spectrum(v) -> AbstractVector{<:Real}

Return a normalized copy of `v`. Allocates.
"""
function normalize_spectrum(v::AbstractVector{<:Real})::AbstractVector{<:Real}
    out = similar(v)
    normalize_spectrum!(out, v)
    return out
end

"""
    normalize_spectrum!(out, v) -> out

Normalize `v` into pre-allocated `out`. Non-allocating.
"""
function normalize_spectrum!(out::AbstractVector{<:Real},
                              v::AbstractVector{<:Real})::AbstractVector{<:Real}
    s = sum(v)
    @. out = v / s
    return out
end
```

**Rules for `!`-functions:**
- Always return the mutated argument as the return value. Returning `nothing`
  from a `!` function is a Julia anti-pattern.
- Document which argument(s) are mutated. With multiple arguments, ambiguity
  is a bug.
- Never mutate an argument that the caller did not pass for that purpose.
- A `!`-function must not be called inside a pure function. If you need the
  mutation for performance inside an otherwise pure computation, use a
  function-local temporary that the caller never sees:
  ```julia
  function fast_diversity(occurrences, bins, cache::DiversityCache)::Float64
      fill!(cache.counts, 0)     # mutates cache, not occurrences
      _populate_counts!(cache.counts, occurrences, bins)
      return _compute_from_counts(cache.counts)
  end
  ```

---

## 4. Anti-patterns

These are explicitly prohibited. If you find yourself writing any of these,
stop and redesign.

| Anti-pattern | Problem | Preferred alternative |
|---|---|---|
| Global mutable `Dict` or `Ref` | Destroys statelessness and reentrancy | Pass cache/config as argument |
| `!`-function without `!` in name | Violates the side-effect contract | Add `!` suffix |
| Non-`!` function that mutates argument | Violates caller's immutability expectation | Return a copy |
| Closure capturing mutable variable | Hard to reason about; Julia compiler issues | Pass state as argument |
| Repeated literal constant | Violates DRY; one change → many bugs | Named `const` |
| `f(x) = global_var + x` | Hidden dependency, not testable | Pass the value as argument |
| `try; catch; end` swallowing errors | Violates "fail loudly" | Re-raise or handle specifically |
| `for` loop building array via `push!` | Imperative; slower; harder to read | Comprehension or `map` |
| `Array{Float64}(undef, n)` for generic output | Breaks GPU/StaticArray support | `similar(input)` |
| `1:length(v)` for indexing | Breaks non-1-based arrays | `eachindex(v)` |
| Hardcoded `Vector` in a generic signature | Breaks composition with other array types | `AbstractVector` |
| Type-unstable function | Prevents compiler optimization | Ensure return type depends only on input types |
| Missing return type annotation | Contract invisible at definition; refactoring errors are silent | Add `::ReturnType` to all public and non-trivial functions (§1.12.1) |
| `Any` as return type | Defeats type stability and compiler optimization | Redesign to return a specific type |
| Macro that generates opaque code | Violates readability | Prefer named functions |

---

## 5. Quick-reference decision tree

When writing a function, answer these in order:

```
Is the result fully determined by the inputs?
├── No  → Extract the effect; make it a parameter or push to the shell (§1.14)
└── Yes → Function is pure. Continue.

Does it need to mutate an argument?
├── No  → Immutable, out-of-place. Preferred.
└── Yes → Is this a genuine performance requirement?
          ├── No  → Return a copy instead
          └── Yes → Apply the mutation contract (§3):
                    name it f!, document which arg is mutated,
                    provide an f wrapper if callers need out-of-place

Does it depend on global state?
├── Yes → Refactor: pass the state as an argument (§1.9)
└── No  → Continue.

Does it repeat logic from another function?
├── Yes → Extract a named function; apply DRY (§1.16)
└── No  → Continue.

Does it have an explicit return type annotation?
├── No  → Add ::ReturnType before the function body (§1.12.1)
│         Ensure the type is concrete or constrained — not Any
└── Yes → You're done. Write the docstring.
```
