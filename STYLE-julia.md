# STYLE--julia.md 

## 1. Core principles and their Julia expression

The paradigm is **idiomatic functional Julia**: functional principles applied
with Julia's grain, not against it. The goal is equational reasoning, local
correctness, and composability — not syntactic purity or Haskell cosplay. Where
Julia's idioms and FP principles align, follow both. Where performance requires
mutation, use the mutation contract in §4.

The principles below are ordered from most foundational to most derived. Each
one follows from the one above it. All are in force unless §4 creates an
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
mutation is required for performance (see §4).

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
- For large scientific data, the mutation contract in §4 applies — but only
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


#### Concrete struct fields and parametric type design

> In Julia, struct fields must not be left undefined in type, must not be
> abstractly typed, and must not use `Any` except in rare and explicitly
> justified cases. Every struct field must be either concretely typed or made
> concrete through type parameters at instantiation.

**Rules:**
- Every struct field must have a concrete type or a type parameter that becomes
  concrete for each instantiated object.
- Do not store `Any`, abstract types, or broad unions in struct fields unless
  there is no sound alternative and the design justification is stated
  explicitly in a comment or docstring.
- Prefer parametric structs:
  `struct Foo{T}; x::T; end`
  over abstractly typed fields:
  `struct Foo; x::AbstractThing; end`
- Do not use undefined, unknown, or placeholder field types in structs.
  Representation types must be fully specified by the struct definition and its
  type parameters.
- Distinguish function argument abstraction from struct field design:
  function arguments should usually be typed at the appropriate abstract level,
  but struct fields must usually be concrete or concretized through type
  parameters.
- Use abstract supertypes to define interfaces; use concrete field types and
  parametric structs to obtain performance.
- If a field appears to require `Any`, an abstract type, or a broad union,
  redesign the representation first. Such fields are a last resort, not a
  normal design option.

---

### 1.13 Annotations

#### 1.13.1 Argument type annotations (mandatory except when harmful to design)

> Function arguments must be annotated at the correct level of abstraction to
> express the interface contract. Overly concrete annotations are correctness
> bugs at the design level.

Argument type annotations serve a different purpose than return types. They do
not constrain what a function *produces* — they define what a function is
*willing to accept*. This is an interface boundary and must be treated as such.

This project mandates argument annotation to:

* **Document intent**: the expected shape and semantics of inputs are visible
  at the point of definition.
* **Enable dispatch**: method specialization depends on argument types.
* **Improve tooling**: static analysis, documentation generators, and code
  navigation rely on explicit types.
* **Catch errors early**: invalid inputs fail at the method boundary, not deep
  in execution.

However, annotation must not come at the cost of generality. The goal is not to
specify the most specific type, but the **most appropriate abstraction**.

**Examples:**

```julia
# Correct: expresses required interface, not implementation
function tokenize(names::AbstractVector{<:AbstractString})::Vector{Vector{SubString{String}}}
    # ...
end
```

```julia
# Incorrect: over-constrained — excludes valid inputs (e.g. SubArray, GPU arrays)
function tokenize(names::Vector{String})::Vector{Vector{SubString{String}}}
```

```julia
# Incorrect: still too narrow — disallows other string types
function tokenize(names::AbstractVector{String})::Vector{Vector{SubString{String}}}
```

**Rules:**

* Annotate all public and non-trivial function arguments unless doing so would
  reduce correctness, composability, or generality.
* Prefer **abstract types** (`AbstractVector`, `AbstractMatrix`,
  `AbstractString`, custom abstract types) over concrete types.
* Use **parametric constraints** to express relationships:

  ```julia
  function f(x::AbstractVector{T}) where {T<:Real}
  ```
* Use **custom abstract types** to encode domain interfaces:

  ```julia
  f(x::AbstractOccurrenceRecord)
  ```
* Avoid **over-constraining**:

  * Do not require `Vector{Float64}` when `AbstractVector{<:Real}` suffices.
  * Do not require `Matrix` when `AbstractMatrix` suffices.
* Avoid **under-constraining**:

  * Do not use `Any` unless the function truly accepts all values.
  * Do not omit annotation when the expected structure is non-trivial.
* Argument annotations must reflect **semantic requirements**, not incidental
  implementation details.
* Higher-order arguments (functions) should generally remain unannotated unless
  a specific callable signature is required.
* When annotation harms composability or introduces artificial coupling, it is
  permitted to omit or relax it — this is the only exception to the rule.

**Anti-pattern:**

```julia
# Overly concrete — locks implementation prematurely
function compute_mean(x::Vector{Float64})::Float64
```

**Correct form:**

```julia
function compute_mean(x::AbstractVector{<:Real})::Float64
```

**Relationship to multiple dispatch:**

Argument annotations define method selection. Overly specific types reduce the
applicability of methods and fragment the API. Overly general types collapse
dispatch distinctions and defer errors. The correct annotation is the one that
captures the **minimal valid interface** for the computation.

---

#### 1.13.2 Return type annotations (mandatory)

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
│  Effectful shell                        │
│  - reads files / network                │
│  - writes results / logs                │
│  - calls mutating (!) functions         │
│  ┌───────────────────────────────────┐  │
│  │  Pure core                        │  │
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

### 1.16 Software design principles

The principles in this section apply across all code in this project alongside
the functional principles in §1.1–§1.15. They are not Julia-specific, but each
has a clear Julia expression described below.

---

#### 1.16.1 SOLID

SOLID is an acronym for five complementary design principles. In Julia's
multiple-dispatch, type-hierarchy model they translate naturally: dispatch
replaces virtual methods, abstract types define interfaces, and argument
injection replaces constructor wiring.

---

##### Single Responsibility Principle (SRP)

> A function or type should have exactly one reason to change: it solves one
> problem, not several interleaved ones.

A function that validates input, performs a computation, formats the result,
and writes it to disk has four responsibilities and four independent reasons to
change. Each modification to one concern risks silently breaking the others.

```julia
# Violation: one function carries four responsibilities
function run_analysis(path::String, taxon::String)::Nothing
    isfile(path) || throw(ArgumentError("File not found: $path"))  # validate
    data = parse_occurrences(read(path, String))                    # parse
    result = diversity_index(data[taxon])                          # compute
    println("Diversity: $(round(result; digits=3))")               # format + output
    return nothing
end

# SRP: each function has one job
function validate_input_path(path::String)::Nothing
    isfile(path) || throw(ArgumentError("File not found: $path"))
    return nothing
end

function load_occurrences(path::String)::Dict{String, Vector{OccurrenceRecord}}
    return parse_occurrences(read(path, String))
end

function run_analysis(path::String, taxon::String)::Float64
    validate_input_path(path)
    data = load_occurrences(path)
    return diversity_index(data[taxon])
end
```

**Rules:**
- A function that does more than one logically separable thing should be split.
  The `f` / `f!` pair pattern (§4) is SRP in action: one function computes and
  returns, the other mutates in place — two responsibilities, two names.
- A `struct` that carries both domain data and I/O configuration has two
  responsibilities — separate them.
- If a function's docstring requires "and" to describe what it does, it may be
  violating SRP.

---

##### Open/Closed Principle (OCP)

> Software entities should be open for extension but closed for modification.
> New behavior is added by extending, not by editing existing code.

In Julia, this is the natural expression of multiple dispatch: add a new method
to an existing generic function for a new type without touching any of the
existing methods. The existing methods are stable; the new type extends the
function's behavior.

```julia
# Existing: works for MarineOccurrence
habitat_label(::MarineOccurrence)::String = "marine"

# OCP extension: new type, new method — existing code unchanged
habitat_label(::TerrestrialOccurrence)::String = "terrestrial"

# OCP violation: modifying the original function every time a new type appears
function habitat_label(occ::AbstractOccurrenceRecord)::String
    if occ isa MarineOccurrence
        return "marine"
    elseif occ isa TerrestrialOccurrence   # requires editing existing function
        return "terrestrial"
    end
end
```

**Rules:**
- Prefer dispatch over `isa` / `typeof` branching. Dispatch is open for
  extension; branching requires modifying the function for every new type.
- Design generic functions against abstract types (§1.12) so that new concrete
  types can participate without changing the generic function's definition.
- If adding a new type requires editing existing methods, the existing methods
  are not written at the right level of abstraction.

---

##### Liskov Substitution Principle (LSP)

> A value of a subtype must be usable wherever a value of its supertype is
> expected, without breaking correctness. Subtypes must honour the full
> contract of their supertype, not merely its method signatures.

In Julia, LSP applies to the abstract type hierarchy. Any concrete type declared
as `<: AbstractFoo` must honour the contract implied by `AbstractFoo` — not just
the methods that compile, but the invariants those methods are expected to
preserve.

```julia
abstract type AbstractOccurrenceRecord end
# Implied contract:
#   - age_ma(r) returns a non-negative Float64
#   - taxon_id(r) returns a positive Int

struct ValidRecord <: AbstractOccurrenceRecord
    taxon_id::Int
    age_ma::Float64
end
age_ma(r::ValidRecord)::Float64 = r.age_ma          # honours the contract

# LSP violation: subtype silently breaks the non-negativity invariant
struct BrokenRecord <: AbstractOccurrenceRecord
    taxon_id::Int
    age_ma::Float64
end
age_ma(r::BrokenRecord)::Float64 = -abs(r.age_ma)   # returns negative — breaks all callers
```

**Rules:**
- A concrete type must implement every method that callers of its abstract
  supertype rely on. Missing methods cause `MethodError` at runtime — surface
  this in tests.
- A method on a subtype must not weaken preconditions or strengthen
  postconditions relative to the abstract type's implied contract.
- If a concrete type cannot honour the abstract type's contract, it must not
  be declared as a subtype of it.
- Document the contract of every abstract type explicitly in its docstring,
  including any invariants methods are expected to preserve.

---

##### Interface Segregation Principle (ISP)

> Prefer many narrow, focused interfaces over one fat one. A type should not
> be forced to implement methods it does not meaningfully need.

In Julia, an "interface" is an abstract type plus the set of generic functions
that dispatch on it. A fat abstract type that implies ten required methods
means every concrete subtype must implement all ten — most of which may be
irrelevant or unimplementable for many subtypes.

```julia
# Fat interface: every subtype is burdened with all five requirements
abstract type AbstractAnalysis end
# implied: run!, summarize, plot, export_csv, send_to_db

# ISP: segregated into narrow interfaces — each subtype opts in to what it needs
abstract type AbstractRunnable end       # requires: run!
abstract type AbstractSummarizable end   # requires: summarize
abstract type AbstractPlottable end      # requires: plot

struct DiversityAnalysis <: AbstractRunnable, AbstractSummarizable
    # implements only run! and summarize — plot and export are not its concern
end
```

**Rules:**
- Define abstract types at the narrowest useful level of abstraction.
- If a generic function only applies to some subtypes of an abstract type,
  define a narrower abstract type for those subtypes and dispatch on that.
- Avoid adding methods to an abstract type's implied interface unless every
  current and foreseeable concrete subtype will meaningfully implement them.
- Prefer composing multiple narrow abstract types over inheriting from one
  broad one.

---

##### Dependency Inversion Principle (DIP)

> High-level code should not depend on low-level implementation details. Both
> should depend on shared abstractions. Dependencies are injected, not fetched.

In Julia, DIP has two expressions: (1) annotate function arguments against
abstract types rather than concrete types (§1.12, §1.13.1), so the function
depends on the interface, not the implementation; and (2) inject dependencies —
data sources, caches, configuration — as function arguments rather than reading
them from globals or constructing them inside the function (§1.9).

```julia
# DIP violation: hard-coded dependency on one concrete data source
function compute_diversity(taxon::String)::Float64
    records = PBDBClient.fetch(taxon)   # coupled to a specific implementation
    return diversity_index(records)
end

# DIP-compliant: depends on the abstract type; implementation is injected by caller
function compute_diversity(records::AbstractVector{<:AbstractOccurrenceRecord})::Float64
    return diversity_index(records)
end

# Also DIP-compliant when a fetch step is unavoidable: inject the source
function compute_diversity(source::AbstractOccurrenceSource, taxon::String)::Float64
    return diversity_index(fetch(source, taxon))
end
```

**Rules:**
- Annotate arguments against abstract types, not concrete ones (§1.12 and
  §1.13.1 cover the full annotation rules and the correct level of abstraction).
- Do not construct or look up dependencies (API clients, caches, file handles)
  inside a function — accept them as arguments. This is statelessness (§1.9)
  applied to dependencies.
- The pure core (§1.14) automatically satisfies DIP: it depends only on its
  argument types, which are abstractions.

---

#### 1.16.2 DRY — Don't Repeat Yourself

> Every piece of knowledge has a single, authoritative representation.
> Duplication means two places to update, two places to get wrong.

DRY is the design consequence of abstraction and composition. If the same
computation appears in two places, it belongs in a named function. If the same
type constraint appears in ten function signatures, it belongs in an abstract
type or type alias.

```julia
# Repeated: age validation duplicated across functions
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

#### 1.16.3 KISS — Keep It Simple, Stupid

> The simplest correct solution is the right solution. Complexity is a cost,
> not a feature.

Every abstraction layer, type parameter, macro, and level of indirection has a
cost: it must be understood, maintained, and debugged. Add complexity only when
simplicity provably cannot solve the problem. When two designs are equally
correct, the simpler one wins.

```julia
# Over-engineered: abstract machinery introduced for a single concrete case
abstract type AbstractAgeFilter end
struct MinAgeFilter <: AbstractAgeFilter
    threshold::Float64
end
apply_filter(f::MinAgeFilter, occ::AbstractOccurrenceRecord)::Bool = occ.age_ma >= f.threshold

# KISS: a function is sufficient for one filtering criterion
is_old_enough(occ::AbstractOccurrenceRecord, min_age::Float64)::Bool = occ.age_ma >= min_age
```

Add the more general design only when a second concrete filter variant actually
exists (see §1.16.5 YAGNI).

**Rules:**
- Do not add abstract types, type parameters, or dispatch layers speculatively.
  Introduce them only when a second concrete variant exists and requires it.
- Prefer Julia's built-in operations (`sum`, `filter`, broadcasting) over
  custom implementations that replicate them.
- Prefer a single function over a type hierarchy for a single, well-defined
  behavior.
- Metaprogramming (`@generated`, `@eval`, custom macros) carries high cognitive
  cost. Use it only when there is no readable, direct alternative.
- When two designs are equally correct, prefer the one with fewer concepts,
  fewer lines, and fewer moving parts.

---

#### 1.16.4 POLA — Principle of Least Astonishment

> Code should behave in a way that surprises no reader. A function should do
> exactly what its name and signature imply — nothing more, nothing less.

Surprise in code manifests as hidden side effects, names that do not match
behavior, functions that do more than one thing, and conventions applied
inconsistently. These create bugs at the point where a reader's mental model
diverges from what the code actually does.

```julia
# Astonishing: the name implies a pure read; the behavior includes a write
function get_diversity(taxon::String, cache::Dict)::Float64
    result = _compute(taxon)
    cache[taxon] = result    # silent side effect — caller does not expect this
    return result
end

# POLA-compliant: name and `!` suffix make the mutation explicit
function fetch_or_compute_diversity!(cache::Dict, taxon::String)::Float64
    haskey(cache, taxon) && return cache[taxon]
    cache[taxon] = _compute(taxon)
    return cache[taxon]
end
```

**Rules:**
- The `!` convention (§1.2) is POLA applied to mutation: callers can trust that
  a function without `!` does not mutate their data. Never violate this.
- A function named in getter form (`age`, `get_age`, `taxon_id`) must not
  perform I/O, trigger mutation, or produce observable side effects.
- Return type annotations (§1.13.2) serve POLA: callers should never be
  surprised by the type they receive.
- Naming must be precise: `filter_valid` must not also sort; `compute_index`
  must not also log; `load_data` must not also transform. One name, one thing.
- Avoid keyword arguments that silently change the fundamental nature of what a
  function does. Use separate named functions instead.

---

#### 1.16.5 YAGNI — You Aren't Gonna Need It

> Do not implement functionality until it is actually required. Speculative
> code is pre-paid technical debt with an uncertain payoff.

Premature generality is not a virtue. An abstraction built for a use case that
never materializes must still be read, tested, and maintained — indefinitely.
Write the simplest concrete solution for the current requirement; add generality
only when a second concrete use case forces it and the right abstraction is
visible from both examples.

```julia
# YAGNI violation: abstract machinery for a data source that does not yet exist
abstract type AbstractOccurrenceSource end
struct PBDBSource <: AbstractOccurrenceSource end
struct FossilWorksSource <: AbstractOccurrenceSource end  # does not exist yet

fetch(::PBDBSource, taxon::String) = _fetch_pbdb(taxon)
fetch(::FossilWorksSource, taxon::String) = error("not implemented")  # speculative stub

# YAGNI-compliant: one concrete function for the one source that currently exists
fetch_pbdb(taxon::String)::Vector{OccurrenceRecord} = _fetch_pbdb(taxon)
```

When `FossilWorksSource` is actually needed, introduce the abstraction then.
The refactor is mechanical and the design will be better informed by two real
use cases rather than one real and one imagined.

**Rules:**
- Do not write stub or placeholder implementations for functionality not yet
  required. Stubs accrete and become permanent.
- Do not introduce abstract types or dispatch layers until at least two concrete
  variants exist in the codebase.
- Do not add keyword arguments, configuration options, or flags for behavior
  that no current caller needs.
- Do not pre-emptively generalize type signatures beyond what current callers
  require. Generalize when the need arises (§1.12 governs the correct level of
  abstraction for what is needed now).

---

#### 1.16.6 POLP — Principle of Least Privilege

> Each module, function, and binding should have access only to what it
> actually needs. Unexposed surface area cannot be misused or broken.

Least privilege applies at every scope level in Julia: which names a module
imports, which names it exports, how broadly bindings are scoped, and what a
function receives as arguments versus what it could in principle reach.

```julia
# POLP violation: entire namespace imported — uncontrolled name exposure
using DataFrames          # pulls in all exported names; collisions possible
using Statistics          # another full namespace import

# POLP-compliant: only what is used is imported
using DataFrames: DataFrame, select, transform
using Statistics: mean, std
```

```julia
# POLP violation: function receives more than it needs
function compute_index(config::GlobalConfig)::Float64
    return diversity_index(config.occurrences[config.target_taxon])
    # receives the entire config but uses only two fields out of many
end

# POLP-compliant: receives exactly what it needs
function compute_index(occurrences::AbstractVector{<:AbstractOccurrenceRecord},
                       taxon::String)::Float64
    return diversity_index(filter(o -> o.taxon_id == taxon, occurrences))
end
```

**Rules:**
- Always use `using Package: foo, bar` or `import Package: foo` rather than
  bare `using Package` in library and module code (see §5 anti-patterns).
- `export` only the names that form the public API. Internal helpers remain
  unexported.
- Use `let` blocks to limit the scope of intermediate bindings that need not
  be visible beyond a single expression:
  ```julia
  result = let tmp = expensive_intermediate(x)
      postprocess(tmp)
  end
  # tmp is not in scope here
  ```
- Pass only the data a function needs as arguments, not a large struct that
  happens to contain it. This also satisfies DIP (§1.16.1) and statelessness
  (§1.9).
- Module-level mutable state (§1.9) is a POLP violation: it gives every
  function in the module implicit, uncontrolled read/write access to shared
  state.

---

## 2. Naming conventions

### 2.1 Types, modules, and functions

- **Types**: `PascalCase` — first letter of each word capitalized.
  E.g. `OccurrenceRecord`, `MarineHabitat`.
- **Modules**: `PascalCase`. E.g. `PaleobioDatabase`, `DiversityMetrics`.
- **Functions**:
    - **Non-constructor functions**: all lowercase; underscores between words when the name would
      otherwise be hard to read. E.g. `compute_diversity`, `filter_valid`, `taxon_richness`.
    - **Constructor functions**: follow their type name. E.g. `Foo()::Foo`


### 2.2 Module file naming

A file that declares a module has the same name as the module.
E.g. the module `DiversityMetrics` is declared in `DiversityMetrics.jl`.

### 2.3 Getters and setters

Functions that access or update a field on a struct are not prefixed with
`get` or `set`. The getter is named for the field; the setter takes the same
name with a `!` suffix (consistent with §1.2):

```julia
age(record)              # get age field
age!(record, 65.0)       # set age field
```

---

## 3. General coding conventions

### 3.1 Formatting

- Use `Runic.jl` for code formatting.
- Enforce formatting in CI with a Runic-based formatting check.
- Do not mix style PRs with functional changes.

### 3.2 Function argument order

Argument ordering goes from most to least important:

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

### 3.3 Generic array support

- Never assume 1-based indexing. Use `eachindex`, `axes`, or broadcasting.
- Construct output arrays with `similar(input)`, not `Vector{Float64}(undef, n)`,
  to preserve array type (GPU, static, offset).
- Do not hardcode `Array` when `AbstractArray` or `AbstractVector` is intended.

### 3.4 Tests

- All recommended (exported) functionality must be tested.
- Tests should cover a wide gamut of input types — not just `Vector{Float64}`.
- Known type limitations should be documented with `@test_broken`, not silently
  omitted.
- At *least* one test file per source file: `test/test_<module>.jl` mirrors `src/<module>.jl`. If test files exceed LOC thresholds (500-600 non-commented LOC), then break into subfiles to be `include`d.
- Test directory gets its own `Project.toml` (see below).
- Tests must verify externally meaningful behavior, not just internal geometry
  or implementation-adjacent proxies. For stronger guidance, also follow
  `STYLE-verification.md`.

### 3.5 Error handling

- Catch errors as high as possible — validate inputs at the public API boundary,
  not deep in a call chain.
- Error messages must be informative for newcomers: say what was expected, what
  was received, and what the user should do.
- Use appropriate error types: `ArgumentError` for bad inputs, `DomainError` for
  values outside a function's mathematical domain, `DimensionMismatch` for
  array size issues.

### 3.6 Packages over modules

- When in doubt, a submodule should become a subpackage or a separate package.
- Prefer interface packages over `Requires.jl` conditional modules.

### 3.7 Macros

- Use macros only for syntactic sugar where the generated code is easy to
  picture (`@.`, `@view`, `@inbounds`, `@muladd`).
- Do not define macros that generate non-obvious code or change program
  semantics in opaque ways.

### 3.8 Documentation

- Use a dedicated Documenter.jl subproject in `docs/`, with its own `Project.toml` to manage documentation.
- The root `README.md` should include synopsis of package, motivation/purpose, installation (from General as well as cloning from GitHub, links to served documentation, quick start, general tour of features through MWE's and snippets.
- The Documenter project should provide all the deeper and foundational details, include example-rich tours and walkthroughs of all public functions and types, as well as supporting concepts, functions, types, and so on.
- Documenter pages should be broken up to stay within Documenter's warning limits.

### 3.9 Ownership, invariants, and anti-fixes

- Repair shared invariants at the owning layer. Do not distribute one invariant
  across many call sites through repeated defensive patches.
- If multiple modules are applying the same corrective logic, stop and identify
  the real owner before adding another patch.
- Prefer a single well-owned repair over many local compensations.
- Do not clamp, mask, or cosmetically suppress invalid state merely to make
  tests pass or output look plausible. That is an anti-fix unless the masking
  policy is itself the explicit owner-level contract.
- When wrapping or extending a host framework, preserve the host-framework
  contract unless an explicit, documented divergence has been approved.
- When a local fix appears to require changes in several sibling layers, treat
  that as an architectural smell and consult `STYLE-architecture.md` and
  `STYLE-upstream-contracts.md`.

---

## 4. The mutation contract

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

## 5. Anti-patterns

These are explicitly prohibited. If you find yourself writing any of these,
stop and redesign.

| Anti-pattern                                  | Problem                                                                     | Preferred alternative                                                     |
| --------------------------------------------- | --------------------------------------------------------------------------- | ------------------------------------------------------------------------- |
| Global mutable `Dict` or `Ref`                | Destroys statelessness and reentrancy                                       | Pass cache/config as argument                                             |
| `!`-function without `!` in name              | Violates the side-effect contract                                           | Add `!` suffix                                                            |
| Non-`!` function that mutates argument        | Violates caller's immutability expectation                                  | Return a copy                                                             |
| Closure capturing mutable variable            | Hard to reason about; Julia compiler issues                                 | Pass state as argument                                                    |
| Repeated literal constant                     | Violates DRY; one change → many bugs                                        | Named `const`                                                             |
| `f(x) = global_var + x`                       | Hidden dependency, not testable                                             | Pass the value as argument                                                |
| `try; catch; end` swallowing errors           | Violates "fail loudly"                                                      | Re-raise or handle specifically                                           |
| `for` loop building array via `push!`         | Imperative; slower; harder to read                                          | Comprehension or `map`                                                    |
| `Array{Float64}(undef, n)` for generic output | Breaks GPU/StaticArray support                                              | `similar(input)`                                                          |
| `1:length(v)` for indexing                    | Breaks non-1-based arrays                                                   | `eachindex(v)`                                                            |
| Hardcoded `Vector` in a generic signature     | Breaks composition with other array types                                   | `AbstractVector`                                                          |
| Type-unstable function                        | Prevents compiler optimization                                              | Ensure return type depends only on input types                            |
| Missing return type annotation                | Contract invisible at definition; refactoring errors are silent             | Add `::ReturnType` to all public and non-trivial functions (§1.13)      |
| `Any` as return type                          | Defeats type stability and compiler optimization                            | Redesign to return a specific type                                        |
| Macro that generates opaque code              | Violates readability                                                        | Prefer named functions                                                    |
| `using Package` in library/module code        | Imports all exported names; obscures dependencies; increases collision risk (POLP, §1.16.6) | `using Package: foo, bar` or `import Package: foo` when extending methods |
| Speculative type hierarchy or stub method     | Adds maintenance burden for code that may never be used (YAGNI, §1.16.5)   | Implement when the second concrete use case actually exists               |


---

## 6. Quick-reference decision tree

When writing a function, answer these in order:

```
Is the result fully determined by the inputs?
├── No  → Extract the effect; make it a parameter or push to the shell (§1.14)
└── Yes → Function is pure. Continue.

Does it need to mutate an argument?
├── No  → Immutable, out-of-place. Preferred.
└── Yes → Is this a genuine performance requirement?
          ├── No  → Return a copy instead
          └── Yes → Apply the mutation contract (§4):
                    name it f!, document which arg is mutated,
                    provide an f wrapper if callers need out-of-place

Does it depend on global state?
├── Yes → Refactor: pass the state as an argument (§1.9)
└── No  → Continue.

Does it repeat logic from another function?
├── Yes → Extract a named function; apply DRY (§1.16)
└── No  → Continue.

Does this function or type exist to serve a current, concrete requirement?
├── No  → Remove it (YAGNI, §1.16.5). Speculative code is maintenance debt.
└── Yes → Is it as simple as it can be while still being correct?
          ├── No  → Simplify (KISS, §1.16.3): fewer layers, fewer concepts
          └── Yes → Continue.

Does it have explicit argument annotations at the correct level of abstraction?
├── No  → Add ::TypeAnnotation before the function body (§1.13)
│         Ensure the type is at the correct level of abstraction; if not possible or advisable, discuss
└── Yes → Continue.

Does it have an explicit return type annotation?
├── No  → Add ::ReturnType after the argument list (§1.13)
│         Ensure the type is concrete or constrained — not Any; if not possible or advisable, discuss
└── Yes → You're done. Write the docstring.
```


## 7. Project management

- Documentation (`docs/`) and tests (`test/`) maintain their own project environments, using `[sources] ... = {path = "../"}` for the main package.
- Use documented public Pkg.add, Pkg.develop, Pkg.rm etc. methods to curate the project environment rather than editing Project.toml file directly UNLESS there is no other way (e.g., adding a "`[sources]`" section to `Project.toml`), in which case bring to my attention for discussion.
- Do not add dependencies by assuming you know the UUID. Always prefer to use Pkg.add unless there is no other way, in which case bring to my attention for discussion.

## 8. Codebase curation

- Files that declare modules should only declare the module and import any
  modules it requires. Any subsequent significant code should be included from
  separate files via `include`. E.g.:
  ```julia
  module DiversityMetrics

  using IntervalTrees, JSON

  include("metrics.jl")
  include("io.jl")

  end
  ```
- Break large sources up into smaller files: 400-600 LOC's (lines of code, i.e. not including commented-out lines) is ideal.
- Never break existing functionality without approval/discussion, but if better approaches are available that would be enabled by a ground-up refactoring or breaking changes or an entirely different implementation, definitely bring it up for my consideration.
