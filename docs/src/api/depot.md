```@meta
CurrentModule = PaleobiologyDB
```

# Depot — Local data store

The `Depot` module manages the Scratch-backed local snapshots used by the
taxonomy validation functions. Access via the full namespace:

```julia
using PaleobiologyDB.Depot

# List all registered stores and their status
PaleobiologyDB.Depot.list()

# Metadata for a specific store
PaleobiologyDB.Depot.info(:pbdb_taxa)

# Force re-download of a snapshot
PaleobiologyDB.Depot.refresh!(:pbdb_taxa)

# Delete the local snapshot (will be re-downloaded on next use)
PaleobiologyDB.Depot.delete!(:pbdb_taxa)
```

```@docs
PaleobiologyDB.Depot
```
