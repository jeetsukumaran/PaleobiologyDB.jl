# STYLE-docs.language.md

## Core principles

Documentation must satisfy the following properties:

- clarity: language is direct and unambiguous
- consistency: identical constructs are expressed identically
- neutrality: tone is descriptive, not persuasive
- precision: words carry their exact intended meaning
- economy: no unnecessary words

### Example

Incorrect:

> The system kind of basically does some processing stuff.

Correct:

> The system processes input data.

---

## Sentence structure

Sentences must be:

- declarative
- grammatically complete
- structurally simple where possible

### Rules

- subject precedes verb
- avoid nested clauses unless necessary
- avoid passive voice unless required for clarity

### Examples

Incorrect:

> The computation that was performed by the system resulted in output being generated.

Correct:

> The system computed the output.

---

## Voice

Prefer active voice.

### Examples

Incorrect:

> The file was processed by the parser.

Correct:

> The parser processed the file.

Exception:

Passive voice is acceptable when the agent is unknown or irrelevant.

Correct:

> The file was corrupted during transfer.

---

## Tense

Use present tense for general statements.

### Examples

Correct:

> The function returns a value.

Incorrect:

> The function returned a value.

Exception:

Use past tense for historical events.

Correct:

> The protocol was introduced in 1998.

---

## Articles

Use articles (`a`, `an`, `the`) correctly and sparingly.

### Rules

- use `a` or `an` for general references
- use `the` for specific references
- avoid unnecessary articles

### Examples

Correct:

> A function returns a value.

Correct:

> The function returns the value.

Incorrect:

> The functions return the values. (if general)

---

## Nouns

Prefer nouns over nominalizations.

### Examples

Incorrect:

> The implementation of the system allows for the execution of tasks.

Correct:

> The system executes tasks.

---

## Verbs

Use precise verbs.

Avoid vague verbs such as:

- do
- make
- perform
- handle

### Examples

Incorrect:

> The system performs an operation.

Correct:

> The system computes the result.

---

## Adjectives and adverbs

Use only when necessary.

### Examples

Incorrect:

> The system quickly processes data efficiently.

Correct:

> The system processes data.

---


---

## Abbreviations

### Rules

- define on first use
- use consistently

### Examples

Correct:

> Central processing unit (CPU)

Incorrect:

> CPU (undefined)

## Consistency

Consistency is mandatory.

### Rules

- do not switch terminology
- do not mix styles

### Examples

Incorrect:

> input data → source data → incoming data (in same document)

Correct:

> input data (used consistently)

## Word choice

Prefer common, widely understood terms.

### Examples

Incorrect:

> utilize

Correct:

> use

## Avoid ambiguity

### Rules

- avoid pronouns without clear reference
- avoid vague terms

### Examples

Incorrect:

> It processes it.

Correct:

> The parser processes the input file.

## Parallelism

Maintain parallel grammatical structure.

### Examples

Correct:

- parsing input
- validating data
- computing results

Incorrect:

- parse input
- validating data
- computation of results

## Definitions

Define terms precisely.

### Example

Correct:

> A queue is a first-in, first-out (FIFO) data structure.

Incorrect:

> A queue is something that holds items.

## Examples

Examples must be:

- minimal
- correct
- representative

### Example

Correct:

```text
input: [1, 2, 3]
output: 6
````

## Code and text distinction

* code is literal
* prose explains

### Example

Correct:

> The function `sum` returns the total.

## Avoid redundancy

### Examples

Incorrect:

> each and every

Correct:

> each

## Avoid filler

Remove words that do not add meaning.

### Examples

Incorrect:

> It should be noted that the system processes data.

Correct:

> The system processes data.

## Avoid conversational tone

### Examples

Incorrect:

> You can see that the system works.

Correct:

> The system works.

## Avoid rhetorical questions

### Examples

Incorrect:

> What does the system do?

Correct:

> The system processes data.

## Avoid exaggeration

### Examples

Incorrect:

> This extremely powerful system...

Correct:

> This system...

## Avoid subjective language

### Examples

Incorrect:

> This is a great feature.

Correct:

> This feature enables parallel execution.

## Terminology stability

Use one term per concept.

### Examples

Incorrect:

> job / task / process (mixed)

Correct:

> task (consistent)

## Hyphenation

Use hyphens consistently.

### Examples

Correct:

> real-time system

Incorrect:

> realtime system

## Spacing

Use single spaces between words and after punctuation.

## Paragraph structure

Each paragraph expresses one idea.

### Example

Correct:

> The parser reads input.
> It validates structure.
> It produces tokens.

## Emphasis

Use italics sparingly.

### Examples

Correct:

> The system is *not* deterministic.

## Non-English terms

Italicize non-English words.

### Examples

Correct:

> The term *raison d'être* describes purpose.

## Scientific names

Italicize genus and species.

### Examples

Correct:

> *Homo sapiens*

## Final consistency rule

If multiple valid forms exist:

* choose one
* apply it everywhere

## Summary

Documentation must be:

* clear
* consistent
* precise
* neutral
* economical