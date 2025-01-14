# Instructions

This repository is based off [CUDL Solr](https://github.com/cambridge-collection/cudl-solr). The default branch for the darwin release is `darwin-main`. `main` contains cudl-solr.

The solr core configs and schemata are contained in `docker/solr`.

## Local Build

Ensure you have a directory called `./external-vol` at the root of this repo. This directory will contain your solr config, indices and logs for each of your cores. When you launch the instance, the contents of `docker/solr` will be copied into `./external-vol`.

    docker compose up --force-recreate --build

## AWS

1. Use the image in our private ECR
2. Set an environment variable called `SOLR_JAVA_MEM` for solr's memory usage. The local implementation was tested using `-Xms2g -Xmx2g` but can't guarantee that it's the optimal value.
3. Mount an EFS volume directory onto `/var/solr`. The contents of `docker/data/solr` will be copied onto it when the image is mounted.

**NOTE**

`/var/solr` is the default location for solr conf/schema files. It's also where solr will write all its indices and working files.

Ideally, we'd store the schema/conf settings in a separate repository - to keep the application logic simpler.
    

## Sample queries

All queries will return the first page of results (max 20 items)

To search the TEI documents, you would use the `dcp` core:

<http://localhost:8983/solr/dcp/select?> -- retrieve all TEI docs, the default when no query terms are given
<http://localhost:8983/solr/dcp/select?q=flowers> -- retrieve all TEI docs with 'flowers'
<http://localhost:8983/solr/dcp/select?q=%22confessing%20a%20murder%22> -- retrieve all TEI docs with the phrase "confessing a murder".

To search the website pages, you would use the `site` core:

<http://localhost:8983/solr/site/select?> -- retrieve all TEI docs, the default when no query terms are given
<http://localhost:8983/solr/site/select?q=flowers> -- retrieve all TEI docs with 'flowers'
<http://localhost:8983/solr/site/select?q=%22confessing%20a%20murder%22> -- retrieve all TEI docs with the phrase "confessing a murder".

