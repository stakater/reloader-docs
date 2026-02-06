# Reloader Documentation

This repository contains the source code for **Reloader documentation**, built with **MkDocs** and versioned using **mike**.

The goal of this README is to help you:

* Make documentation changes safely
* Preview docs locally with minimal friction
* Understand how CI/CD publishes the docs

---

## Repository Structure (What to Touch)

You will mostly work in **two directories only**:

* `content/` – documentation pages (Markdown)
* `theme_override/` – local theme customizations

> ⚠️ **Important**
>
> * Do **not** edit files in `dist/` – it is generated
> * Do **not** edit `theme_common/` directly unless you know what you are doing
> * Only edit `theme_override/mkdocs.yml` (there are multiple mkdocs files)

---

## GitHub Actions & Publishing Flow

This repository is fully automated via GitHub Actions:

* **Pull Requests**

  * Runs documentation QA checks
  * Builds Docker image
  * Publishes preview docs at:

    ```
    https://stakater.github.io/reloader-docs/<branch-name>/
    ```

* **Merge to `main`**

  * Creates a GitHub release
  * Builds & pushes documentation image
  * Update the gitops repository
  * Publishes docs to:

    ```
    https://docs.stakater.com
    ```

---

## Git Submodule (Very Important)

This repository depends on a shared MkDocs theme via a **git submodule**:

```bash
git submodule update --init --recursive
```

If you forget this step, **local builds and Docker builds will fail**.

To update the submodule to the latest version:

```bash
git submodule update --init --recursive --remote
```

You can inspect linked submodules in `.gitmodules`.

---

## Local Development (Choose One)

You have **two supported ways** to preview docs locally.

---

## Option 1: Docker (Recommended, Zero Setup)

This is the **most reliable** method and matches CI behavior.

### Build the docs image

```bash
docker build -f DockerfileLocal.fixed -t reloader-docs-local .
```

### Run the container

```bash
docker run --rm -p 8080:8080 reloader-docs-local
```

Open your browser:

```
http://localhost:8080
```

---

## Option 2: Run Locally (Python)

### Prerequisites

* Python 3.x
* `virtualenv` or `virtualenvwrapper`

### Setup virtual environment

```bash
python3 -m venv .venv
source .venv/bin/activate
```

### Prepare theme & install dependencies

This script:

* Installs Python dependencies from `theme_common`
* Merges shared + local theme overrides
* Generates `mkdocs.yml`

```bash
./prepare_theme.sh
```

### Serve docs locally

```bash
mike serve
```

or

```bash
python3 -m mike serve
```

Docs will be available at:

```
http://localhost:8000
```

> 💡 Any changes to `dist/_theme` will be lost. Always move permanent changes to:
>
> * `theme_override/`
> * or `content/`

---

## Making Documentation Changes

1. Fork the repository
2. Create a feature branch
3. Make changes in `content/` or `theme_override/`
4. Open a Pull Request
5. Ensure all CI checks pass
6. Request review

Once merged, the docs are automatically published.

---

## QA Checks (Optional, but Recommended)

### Markdown linting

```bash
brew install markdownlint-cli
markdownlint -c .markdownlint.yaml content
```

### Spell checking

```bash
brew install vale
vale sync
vale content
```

These checks also run automatically in CI.

---

## Need Help?

If local builds fail:

1. Verify `theme_common/requirements.txt` exists
2. Ensure submodules are initialized
3. Try the Docker-based build

This will catch 99% of issues.
