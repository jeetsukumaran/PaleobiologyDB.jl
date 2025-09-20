

#=

```bash
$ python3 -m venv .venv
$ source .venv/bin/activate
$ python3 -m ensurepip --upgrade
$ python3 -m pip install --upgrade pip
$ python3 -m pip install -r https://raw.githubusercontent.com/dsilvestro/PyRate/master/requirements.txt
```


=#

using CSV
using DataFrame

cache_path = "/home/jeetsukumaran/Downloads/00-capture/pyrate-tutorial-canis.tsv", DataFrame
if isfile(cachepath) 
    df = CSV.read("/home/jeetsukumaran/Downloads/00-capture/pyrate-tutorial-canis.tsv", DataFrame)
else 
    df = pbdb_occurrences(
            ; 
            base_name = "Canis",
            show = ["full", "ident"],
            vocab = "pbdb",
            extids = true
        )
    CSV.write(cache_path, df, delim = "\t")
end