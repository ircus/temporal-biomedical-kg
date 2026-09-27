# temporal-biomedical-kg

Practice project for mapping publicly available (temporal, biomedical) data
to **RDF 1.2** using [SPARQL Anything](https://sparql-anything.cc/) and
loading the result into an **Apache Jena Fuseki** triplestore running in
Docker.

## Stack

- **SPARQL Anything 1.3.0** (`~/tools/sparql-anything-1.3.0`, on `PATH` as
  `sparql-anything`) — bundles Jena ARQ/Core 6.0.0. Used to query
  heterogeneous source files (CSV, JSON, XML, ...) as RDF via the
  Facade-X model and `CONSTRUCT` them into real RDF 1.2 graphs.
- **Fuseki** via `docker-compose.yml` — image `secoresearch/fuseki:latest`
  (Jena/Fuseki 6.2.0), a dedicated container separate from any other
  project's Fuseki instance. Runs on `http://localhost:3031` by default.

## Project layout

```
data/
  samples/    small, hand-written example inputs, committed to git
  raw/        larger downloaded datasets, gitignored
mappings/     SPARQL Anything CONSTRUCT queries (source -> RDF 1.2)
output/       generated RDF (gitignored), written by scripts/run-mapping.sh
scripts/      helper shell scripts tying the pipeline together
docker-compose.yml   the Fuseki container
```

## Workflow

1. **Start Fuseki**

   ```
   docker compose up -d
   ```

   Optional env vars (export before `up`, or put in a local `.env` file —
   `.env` is gitignored): `FUSEKI_PORT` (default `3031`),
   `FUSEKI_ADMIN_PASSWORD` (default `changeme`), `FUSEKI_DATASET`
   (default `kg`). The admin UI is at `http://localhost:3031/`.

2. **Create the dataset** (one-time, idempotent)

   ```
   ./scripts/fuseki-create-dataset.sh
   ```

3. **Run a mapping** — SPARQL Anything queries a source file and
   `CONSTRUCT`s RDF 1.2 Turtle. Must be run from the repo root, since
   `SERVICE <x-sparql-anything:location=...>` paths in the mapping files
   are resolved relative to the current directory, not the query file.

   ```
   ./scripts/run-mapping.sh mappings/clinical_events.sparql output/clinical_events.ttl
   ```

4. **Load the output into Fuseki**

   ```
   ./scripts/fuseki-load.sh output/clinical_events.ttl
   ```

5. **Query it** — via the admin UI at `http://localhost:3031/#/dataset/kg/query`,
   or e.g.:

   ```
   curl -u admin:changeme -H "Accept: application/sparql-results+json" \
     --data-urlencode 'query=PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
       PREFIX : <http://example.org/kg/vocab/>
       SELECT ?patient ?diagnosis ?onset ?src WHERE {
         ?r rdf:reifies <<( ?patient :hasDiagnosis ?diagnosis )>> ;
            :onsetDate ?onset ; :recordedBy ?src .
       }' \
     http://localhost:3031/kg/query
   ```

## Example mapping: `mappings/clinical_events.sparql`

Maps `data/samples/clinical_events.csv` (patient / diagnosis code / onset
date / recording system) into RDF, using the RDF 1.2 **reification**
feature to attach temporal + provenance metadata to the specific
`:hasDiagnosis` assertion — the RDF 1.2-native replacement for classic
RDF reification (`rdf:Statement`) or singleton properties:

```turtle
[ rdf:reifies  <<( pat:P003 :hasDiagnosis dx:I10 )>> ;
  :onsetDate   "2020-05-21"^^xsd:date ;
  :recordedBy  "EHR-SystemA"
] .

pat:P003  a  :Patient ;
          :hasDiagnosis  dx:I10 .
```

### A hard-won RDF 1.2 gotcha

**Triple terms (`<<( s p o )>>`) may only appear as the OBJECT of a
triple** (typically of `rdf:reifies`) — they are **not valid as a
subject**. Both the Jena 6.0.0 (bundled in SPARQL Anything) and Jena 6.2.0
(Fuseki) Turtle readers reject a triple term used directly as a subject
with `Expected IRI for predicate: got LITERAL_DT ...`, even though
nothing stops a `CONSTRUCT` query or the Turtle *writer* from producing
that shape. If you want to say something about an asserted triple, mint
a reifier (blank node or IRI) and connect it with `rdf:reifies`, e.g.:

```sparql
CONSTRUCT {
  ?patient :hasDiagnosis ?diagnosis .
  ?reifier rdf:reifies <<( ?patient :hasDiagnosis ?diagnosis )>> ;
    :onsetDate ?onsetDate .
}
```

not:

```sparql
# invalid RDF 1.2 Turtle - triple term used as subject
CONSTRUCT {
  <<( ?patient :hasDiagnosis ?diagnosis )>> :onsetDate ?onsetDate .
}
```

The separate (older, no-parens) "reified triple" shorthand
`<<s p o>> :onsetDate ?onsetDate .` *is* accepted by both readers as
sugar for asserting the base triple plus an implicit reifier, but isn't
reachable from a SPARQL `CONSTRUCT` template — it's Turtle-only sugar, so
`rdf:reifies` + an explicit reifier is the way to produce this from a
mapping.

## Adding a new mapping

1. Drop the source file under `data/samples/` (small, committed) or
   `data/raw/` (larger, gitignored).
2. Write a new `mappings/<name>.sparql` `CONSTRUCT` query against it via
   `SERVICE <x-sparql-anything:location=data/...,...>`.
3. `./scripts/run-mapping.sh mappings/<name>.sparql output/<name>.ttl`
4. `./scripts/fuseki-load.sh output/<name>.ttl`
