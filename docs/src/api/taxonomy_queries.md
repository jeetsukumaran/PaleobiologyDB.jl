```@meta
CurrentModule = PaleobiologyDB.Taxonomy
```

# Taxonomy — Queries

## Taxonomy tree queries

These functions navigate the PBDB taxonomic hierarchy by name, returning
descendants or ancestors at a requested rank.  All functions are backed by the
same Scratch-managed snapshot used by the filters above and build their indices
on first use (no extra download required).

```julia
using PaleobiologyDB.Taxonomy

# Valid rank names
taxonomic_ranks()
# → ["subspecies", "species", "genus", …, "kingdom"]

# All accepted taxon names (tens of thousands)
registered_taxa()

# Names matching a pattern
registered_taxa(r"^Canis\b")
# → ["Canis", "Canis aureus", "Canis lupus", …]

# Union of patterns
registered_taxa([r"^Canis\b", r"^Vulpes\b"])

# All families within Carnivora
child_taxa("Carnivora", "family")
# → ["Ailuridae", "Amphicyonidae", "Canidae", "Felidae", …]

# All genera within Canidae
child_taxa("Canidae", "genus")
# → ["Borophagus", "Canis", "Lycaon", "Urocyon", "Vulpes", …]

# All species within a genus
child_taxa("Canis", "species")
# → ["Canis aureus", "Canis lupus", "Canis mesomelas", …]

# Every descendant at any rank (no filter)
child_taxa("Canidae")

# Full ancestor chain of a species, child → root
parent_taxa("Canis lupus")
# → ["Canis", "Canidae", "Carnivora", "Mammalia", …, "Animalia"]

# Only the family
parent_taxa("Canis lupus", "family")
# → ["Canidae"]
```

```@docs
taxonomic_ranks
registered_taxa
child_taxa
parent_taxa
```
