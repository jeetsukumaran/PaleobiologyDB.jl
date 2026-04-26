# STYLE-docs.md

## Sentence case

All titles and headings use sentence case.

- Capitalize the first word.
- Capitalize proper nouns.
- Do not capitalize other words.

### Examples

Correct:

- `Data processing pipeline`
- `Error handling in distributed systems`

Incorrect:

- `Data Processing Pipeline`
- `Error Handling In Distributed Systems`

## Headings

Headings must satisfy the following constraints:

- Sentence case.
- No punctuation at the end.
- No questions.
- No formatting (bold, italic).
- No redundancy.

### Examples

Correct:

- `Input validation`
- `Memory management`

Incorrect:

- `Input validation?`
- `Input Validation`
- `System input validation`
- `**Input validation**`


## No separators between section

Section headings are sufficient to denote sections; do not introduce visual clutter of `---` to end or separate sections within the document body.

### Examples

Correct:

```markdown

## A section of the document

### A subsection

### A subsection

## Another section of the document

### A subsection

### A subsection

```

Incorrect

```markdown

---

## A section of the document

### A subsection

### A subsection

---

## Another section of the document

### A subsection

### A subsection

```


## Punctuation

### General rules

- Use standard punctuation
- Avoid excessive punctuation
- Maintain consistency
- Use `--` and `---` for en and em dash ;

## Periods

Use periods to terminate sentences.

### Examples

Correct:

> The system processes input.

Incorrect:

> The system processes input

## Commas

Use commas to separate clauses and list items.

### Examples

Correct:

> The system reads input, processes data, and writes output.

Incorrect:

> The system reads input processes data and writes output.

## Colons

Use colons to introduce lists or explanations.

### Examples

Correct:

> The system performs three steps: parse, validate, compute.

Incorrect:

> The system performs three steps, parse, validate, compute.

## Semicolons

Use semicolons to separate closely related clauses.

### Examples

Correct:

> The system parses input; the validator checks consistency.

## Quotation marks

Use straight double quotation marks.

### Rules

- use double quotes for quotations
- use single quotes for nested quotations

### Examples

Correct:

> The message states, "Processing complete."

Correct:

> The message states, "The status is 'complete'."

## Apostrophes

Use straight apostrophes.

### Rules

- use for possession
- do not use for plurals

### Examples

Correct:

> the system's output

Incorrect:

> the system's outputs's

## Capitalization

Capitalize only when required.

### Rules

- capitalize proper nouns
- do not capitalize common nouns

### Examples

Correct:

> The system runs on Linux.

Incorrect:

> The System runs on Linux.

## Numbers

### Rules

- write numbers in digits for technical content
- use consistent formatting
- use scientific notation for large numbers, not engineering.

### Examples

Correct:

> The system processes 10 files.

Incorrect:

> The system processes ten files.


## Lists

Lists must be consistent in structure.

### Rules

- All items use the same grammatical form.
- Avoid mixing sentence fragments and full sentences.

### Examples

Correct:

- parse input
- validate data
- compute output

Incorrect:

- parsing input
- validation of data
- compute output
