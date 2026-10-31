# Instructions

This repository is based off [CUDL Solr](https://github.com/cambridge-collection/cudl-solr).

The solr core configs and schemata are contained in `docker/solr`.

## Local Build

Ensure you have a directory called `./external-vol` at the root of this repo. This directory will contain your solr config, indices and logs for each of your cores. When you launch the instance, the contents of `docker/solr` will be copied into `./external-vol`.

    docker compose up --force-recreate --build

### Solr and API together

If the `casebooks-search` repository is checked out alongside this repository, one command builds and starts both:

```bash
make dev-up              # build and start Solr, then the API (in the background)
make dev-up ARCH=arm64   # the same, running natively on Apple Silicon
make dev-down            # stop both
```

Each project runs from its own `docker-compose.yml`. The API reads its settings from its own repository, exactly as when you run it there. Both containers run in the background; use `docker logs -f casebooks-solr` or `docker logs -f casebooks-solr-api` to follow their output.

| Parameter | Default                | Description |
|-----------|------------------------|-------------|
| `ARCH`    | `DOCKER_DEFAULT_PLATFORM`, else your machine's architecture | `amd64` or `arm64`. Deployed images are `amd64`; `arm64` runs faster locally on Apple Silicon. |
| `API_ENV` | `.env`                 | Env file for the API, e.g. `make dev-up API_ENV=staging.env`. |
| `API_DIR` | `../casebooks-search`  | Path to the casebooks-search checkout. |

`API_ENV` is relative to `API_DIR`.

## Building and Pushing the Image

`make push` logs in to ECR, builds a `linux/amd64` image from `docker/` and pushes it with three tags:

| Tag               | Example          | Purpose |
|-------------------|------------------|---------|
| `<branch>`        | `main` | Latest image built from that branch (`/` becomes `-`). Moves with each push. Omitted on a detached `HEAD` unless you set `BRANCH`. |
| `git_<short sha>` | `git_1a2b3c4`    | The commit the image was built from. |
| `by_<user>`       | `by_an_other`      | Latest image pushed by that user, so teammates can see who pushed what. Moves with each push. |

Commit your changes before pushing: the `git_` tag records `HEAD`, not uncommitted changes in your working tree.

### Deployment settings

Each deployment has its own settings file, `<name>.env.make`, in the repository root. These files are gitignored; create one for each deployment you push to. For example, `production.env.make`:

```make
AWS_ACCOUNT_ID=<aws-account-id>
REGION=<aws-region>
IMAGE=<ecr-namespace>/<repository-name>
```

Then select it with `DEPLOY`:

```bash
make push DEPLOY=production
```

If no file exists for the name you give, `make` stops with an error rather than pushing to the wrong account. Without `DEPLOY`, `.env.make` is used if it exists.

### Commands

```bash
make push DEPLOY=production          # log in, build and push all three tags
make push DEPLOY=production FRESH=0  # the same, reusing Docker's build cache
make build DEPLOY=production         # build and tag locally without pushing
make login DEPLOY=production         # log Docker in to ECR only
```

### Parameters

Set these in a deployment file or on the command line (command-line values win).

| Parameter        | Default              | Description |
|------------------|----------------------|-------------|
| `DEPLOY`         | none                 | Name of the deployment settings file to load (`<DEPLOY>.env.make`). |
| `AWS_ACCOUNT_ID` | looked up with `aws sts get-caller-identity` | AWS account that owns the ECR repository. |
| `REGION`         | `eu-west-1`          | AWS region of the ECR repository. |
| `IMAGE`          | `casebooks/solr`     | ECR repository namespace and name. |
| `REGISTRY`       | `<AWS_ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com` | Full registry host. Setting this skips the account lookup. |
| `FRESH`          | `1`                  | `1` builds with `--pull --no-cache`; `0` reuses cached layers and local base images. |
| `AWS`            | `aws`                | Command used to call the AWS CLI. `make` runs commands in a non-interactive bash shell, so shell aliases and functions are not available. If you normally reach AWS through one, set this to a command that works without them. |
| `BRANCH`, `SHA`, `WHO` | current branch, short commit, `whoami` | Command line only: override the values used in the three tags. |

## AWS

1. Use the image in our private ECR
2. Set an environment variable called `SOLR_JAVA_MEM` for solr's memory usage. The local implementation was tested using `-Xms2g -Xmx2g` but can't guarantee that it's the optimal value.
3. Mount an EFS volume directory onto `/var/solr`. The contents of `docker/data/solr` will be copied onto it when the image is mounted.

**NOTE**

`/var/solr` is the default location for solr conf/schema files. It's also where solr will write all its indices and working files.

Ideally, we'd store the schema/conf settings in a separate repository - to keep the application logic simpler.
    

## Sample queries

All queries will return the first page of results (max 20 items)

To search the TEI documents, you would use the `epsilon` core:

[http://localhost:8983/solr/casebooks/select?](http://localhost:8983/solr/dcp/select?) -- retrieve all TEI docs, the default when no query terms are given
[http://localhost:8983/solr/casebooks/select?q=flowers](http://localhost:8983/solr/dcp/select?q=flowers) -- retrieve all TEI docs with 'flowers'
[http://localhost:8983/solr/dcp/select?q=%22max%20water%22](http://localhost:8983/solr/dcp/select?q=%22confessing%20a%20murder%22) -- retrieve all TEI docs with the phrase "make water".

