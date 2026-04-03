# Contributing and Development

## Contributing

Contributions are welcome. Please fork the repository, add tests for new
functionality, and submit a pull request.

## Testing

Run the offline test suite:

```bash
julia --project -e 'using Pkg; Pkg.test()'
```

Enable live API tests (requires network access to paleobiodb.org):

```bash
PBDB_LIVE=1 julia --project -e 'using Pkg; Pkg.test()'
```

By default, only offline tests run. The live tests make real HTTP requests to
the Paleobiology Database API and verify that responses can be parsed correctly.

## External Resources

### PBDB Data Service

- [PBDB Data Service: Documentation](https://paleobiodb.org/data1.2/)
- [PBDB Data Service: Usage documentation](https://paleobiodb.org/data1.2/general_doc.html)
    - [Record identifiers and record numbers](https://paleobiodb.org/data1.2/general/identifiers_doc.html)
    - [Specifying taxonomic names](https://paleobiodb.org/data1.2/general/taxon_names_doc.html)
    - [Ecological and taphonomic vocabulary](https://paleobiodb.org/data1.2/general/ecotaph_doc.html)
    - [Specifying dates and times](https://paleobiodb.org/data1.2/general/datetime_doc.html)
    - [Bibliographic references](https://paleobiodb.org/data1.2/general/references_doc.html)
    - [Output formats and Vocabularies](https://paleobiodb.org/data1.2/formats_doc.html)
    - [Special parameters](https://paleobiodb.org/data1.2/special_doc.html)

### Processing Paleobiology Database Data

- [Managing and Processing Data From the Paleobiology Database | Analytical Paleobiology](https://psmits.github.io/paleo_book/managing-and-processing-data-from-the-paleobiology-database.html)
