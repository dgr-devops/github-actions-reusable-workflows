# github-actions-reusable-workflows

Catálogo de **workflows reutilizables de GitHub Actions** (`on: workflow_call`) para lint, tests, imágenes Docker y Terraform. Pensados para consumirse desde otros repositorios con una sola línea `uses:`, en lugar de copiar y pegar pipelines.

> **Estado de validación:** Validado localmente con actionlint; ejecución real en GitHub pendiente hasta el push.
> Los workflows se han analizado con `actionlint` y los comandos que ejecutan se han probado en contenedores locales (ver [Validación](#validación)), pero **todavía no se han ejecutado en runners de GitHub**.

## Catálogo

| Workflow | Qué hace | Inputs principales | Secretos | Outputs | Permisos |
| --- | --- | --- | --- | --- | --- |
| [`lint-shell.yml`](.github/workflows/lint-shell.yml) | ShellCheck sobre todos los `.sh` de una ruta | `path`, `severity`, `exclude-dirs` | — | `files-checked` | `contents: read` |
| [`lint-python.yml`](.github/workflows/lint-python.yml) | `ruff check` y `ruff format --check` | `path`, `python-version`, `ruff-version`, `check-format` | — | — | `contents: read` |
| [`test-python.yml`](.github/workflows/test-python.yml) | pytest + cobertura en matriz de versiones de Python | `python-versions`, `working-directory`, `install-command`, `coverage-target`, `coverage-threshold`, `test-path` | `codecov-token` (opcional) | — (sube `coverage.xml` como artefacto) | `contents: read` |
| [`docker-build-scan-push.yml`](.github/workflows/docker-build-scan-push.yml) | Build con buildx, escaneo Trivy (falla en HIGH/CRITICAL) y push a GHCR solo en la rama por defecto | `image-name`, `registry`, `context`, `dockerfile`, `platforms`, `build-args`, `severity`, `trivy-version`, `ignore-unfixed`, `push` | `registry-token` (opcional) | `image`, `pushed`, `digest` | `contents: read`, `packages: write` |
| [`terraform-check.yml`](.github/workflows/terraform-check.yml) | `terraform fmt -check`, `init -backend=false`, `validate` y `tflint` | `working-directory`, `terraform-version`, `tflint-version`, `tflint-config` | — | — | `contents: read` |
| [`lint-markdown.yml`](.github/workflows/lint-markdown.yml) | markdownlint-cli2 | `globs`, `config` | — | — | `contents: read` |

Todos aceptan además `runs-on` (por defecto `ubuntu-latest`).

### Detalle de inputs

<details>
<summary><code>lint-shell.yml</code></summary>

| Input | Tipo | Por defecto | Descripción |
| --- | --- | --- | --- |
| `path` | string | `.` | Directorio donde buscar scripts `.sh` |
| `severity` | string | `warning` | Severidad mínima que hace fallar (`error`, `warning`, `info`, `style`) |
| `exclude-dirs` | string | `.git node_modules .terraform` | Directorios a ignorar, separados por espacios |

Output `files-checked`: número de scripts analizados. Si no hay ninguno, emite un aviso y termina en verde.

</details>

<details>
<summary><code>lint-python.yml</code></summary>

| Input | Tipo | Por defecto | Descripción |
| --- | --- | --- | --- |
| `path` | string | `.` | Ruta a analizar |
| `python-version` | string | `3.12` | Python con el que se instala ruff |
| `ruff-version` | string | `0.8.6` | Versión de ruff (fijada) |
| `check-format` | boolean | `true` | Ejecuta también `ruff format --check` |

</details>

<details>
<summary><code>test-python.yml</code></summary>

| Input | Tipo | Por defecto | Descripción |
| --- | --- | --- | --- |
| `python-versions` | string (array JSON) | `["3.11", "3.12"]` | Matriz de versiones; `workflow_call` no admite arrays, de ahí el JSON |
| `working-directory` | string | `.` | Directorio del proyecto |
| `install-command` | string | `python -m pip install -e .` | Cómo instalar el proyecto (`pytest` y `pytest-cov` se instalan siempre) |
| `coverage-target` | string | `.` | Valor de `--cov` |
| `coverage-threshold` | number | `80` | `--cov-fail-under` |
| `test-path` | string | `""` | Ruta de tests (vacío = autodescubrimiento) |

Secreto opcional `codecov-token`: si se pasa, se sube la cobertura a Codecov.
El informe `coverage.xml` se guarda siempre como artefacto (`coverage-py<versión>`, 7 días).

</details>

<details>
<summary><code>docker-build-scan-push.yml</code></summary>

| Input | Tipo | Por defecto | Descripción |
| --- | --- | --- | --- |
| `image-name` | string | `""` | Nombre sin registro ni etiqueta; vacío = `owner/repo` en minúsculas |
| `registry` | string | `ghcr.io` | Registro de contenedores |
| `context` | string | `.` | Contexto de build |
| `dockerfile` | string | `Dockerfile` | Ruta al Dockerfile |
| `platforms` | string | `linux/amd64` | Plataformas del push final (con varias se activa QEMU) |
| `build-args` | string | `""` | Build args, uno por línea. **No pongas secretos aquí** |
| `severity` | string | `HIGH,CRITICAL` | Severidades de Trivy que fallan el job |
| `trivy-version` | string | `0.57.1` | Etiqueta de la imagen `aquasec/trivy` con la que se escanea |
| `ignore-unfixed` | boolean | `true` | Ignora vulnerabilidades sin parche disponible |
| `push` | boolean | `true` | Permite publicar; además exige rama por defecto y evento distinto de `pull_request` |

Secreto opcional `registry-token`: si no se pasa se usa el `GITHUB_TOKEN`.
Outputs: `image` (registro/nombre), `pushed` (`true`/`false`) y `digest` (vacío si no se publicó).

Etiquetas publicadas: `latest`, `sha-<corto>` y, en tags Git, la propia etiqueta.

</details>

<details>
<summary><code>terraform-check.yml</code></summary>

| Input | Tipo | Por defecto | Descripción |
| --- | --- | --- | --- |
| `working-directory` | string | `.` | Directorio con el código Terraform |
| `terraform-version` | string | `1.9.8` | Versión de Terraform |
| `tflint-version` | string | `v0.53.0` | Versión de TFLint |
| `tflint-config` | string | `""` | Ruta a un `.tflint.hcl` (vacío = configuración por defecto) |

</details>

<details>
<summary><code>lint-markdown.yml</code></summary>

| Input | Tipo | Por defecto | Descripción |
| --- | --- | --- | --- |
| `globs` | string | `**/*.md` y `#node_modules` | Patrones, uno por línea; el prefijo `#` excluye |
| `config` | string | `""` | Ruta a la configuración de markdownlint |

</details>

## Cómo usarlos

Desde cualquier repositorio, en `.github/workflows/`:

```yaml
name: CI
on:
  push:
    branches: [main]
  pull_request:

permissions:
  contents: read

jobs:
  shell:
    uses: dgr-devops/github-actions-reusable-workflows/.github/workflows/lint-shell.yml@main
    with:
      path: scripts

  tests:
    uses: dgr-devops/github-actions-reusable-workflows/.github/workflows/test-python.yml@main
    with:
      python-versions: '["3.11", "3.12", "3.13"]'
      coverage-target: mi_paquete

  image:
    needs: [shell, tests]
    # Obligatorio: el workflow reutilizable necesita packages:write.
    permissions:
      contents: read
      packages: write
    uses: dgr-devops/github-actions-reusable-workflows/.github/workflows/docker-build-scan-push.yml@main
```

En [`examples/callers/`](examples/callers/) hay un llamador completo por cada workflow, más [`full-pipeline.yml`](examples/callers/full-pipeline.yml) que los encadena.

Para que un repositorio **privado** consuma estos workflows, este repo debe permitirlo en *Settings → Actions → General → Access*. Siendo público no hace falta.

### Usar el resultado de otro job

```yaml
  report:
    needs: image
    runs-on: ubuntu-latest
    steps:
      - run: echo "Publicada ${{ needs.image.outputs.image }} (${{ needs.image.outputs.pushed }})"
```

## Seguridad

- **Mínimo privilegio.** Cada workflow declara `permissions: contents: read` a nivel de workflow y de job. Solo `docker-build-scan-push` añade `packages: write`, y el llamador tiene que concederlo explícitamente (un reutilizable nunca puede ampliar los permisos del llamador).
- **Sin inyección por inputs.** Ningún input se interpola directamente en un `run:`; todos pasan por variables de entorno y se usan entrecomillados (`"$VAR"`), para que un valor como `$(...)` no ejecute código.
- **Checkout sin credenciales persistentes** (`persist-credentials: false`): el token no queda en `.git/config` para los pasos siguientes.
- **Publicación acotada.** La imagen solo se publica si el escaneo de Trivy pasa, la rama es la rama por defecto y el evento no es `pull_request`. Los PR (incluidos los de forks) construyen y escanean, pero nunca publican.
- **Secretos.** Solo hay dos secretos opcionales (`registry-token`, `codecov-token`). Sin `registry-token` se usa el `GITHUB_TOKEN` efímero de la ejecución. Evita `secrets: inherit` salvo en repos de confianza; pasa los secretos de forma explícita.
- **Versiones fijadas.** Las acciones de terceros se fijan por etiqueta mayor (`@v4`, `@v3`...) y las herramientas (ruff, Terraform, TFLint, Trivy) por versión exacta en los inputs por defecto. Trivy se ejecuta desde su imagen oficial de Docker en lugar de una acción de terceros.
- **Endurecimiento pendiente: fijar por SHA.** Una etiqueta puede reescribirse; fijar cada `uses:` al SHA completo del commit (con un comentario con la versión) es la práctica más segura. Se recomienda hacerlo; [`.github/dependabot.yml`](.github/dependabot.yml) ya propone cada semana las actualizaciones de acciones y de la imagen base de la fixture. Ver [`docs/decisiones.md`](docs/decisiones.md).
- **Consumir con cuidado `@main`.** Es cómodo, pero un cambio en este repo afecta de inmediato a todos los consumidores. Para producción, usa una etiqueta (`@v1`) o un SHA.

## Concurrencia y caché

- Cada workflow define un grupo de concurrencia `reusable-<nombre>-<workflow>-<ref>` con `cancel-in-progress: true`, de modo que una ejecución nueva cancela la anterior de la misma rama. El prefijo `reusable-` evita colisionar con el grupo del llamador (un grupo idéntico cancelaría al propio llamador).
- En Docker no se cancela una ejecución en la rama por defecto, para no dejar una publicación a medias.
- Caché: pip (`setup-python`), `.ruff_cache`, plugins de Terraform y capas de Docker (`type=gha`).

## Validación

Entorno: Docker en local, sin acceso a runners de GitHub.

| Comprobación | Comando | Resultado |
| --- | --- | --- |
| Sintaxis y tipos de los workflows | `docker run --rm -v "$PWD":/repo -w /repo rhysd/actionlint:1.7.12` | 0 errores en los 7 workflows |
| Sintaxis de los llamadores | `actionlint` sobre `examples/callers/*.yml` | 0 errores |
| ShellCheck sobre la fixture | `koalaman/shellcheck:stable --severity=warning` | OK |
| ruff + pytest (Python 3.12) | `ruff check`, `ruff format --check`, `pytest --cov-fail-under=90` | OK, 3 tests, 100 % de cobertura |
| pytest en Python 3.11 y 3.13 | mismo comando en `python:3.11-slim` y `python:3.13-slim` | OK, 3 tests, 100 % de cobertura |
| Existencia de las etiquetas de las acciones | `git ls-remote --tags` sobre cada repositorio de acción | Las 13 etiquetas usadas existen |
| Terraform | `terraform fmt -check`, `init -backend=false`, `validate` (1.9.8) | OK |
| TFLint | `ghcr.io/terraform-linters/tflint:v0.53.0` | Sin hallazgos |
| Docker + Trivy | `docker build` y `trivy image --severity HIGH,CRITICAL --ignore-unfixed` | 0 vulnerabilidades; una imagen vulnerable (`alpine:3.10`) hace fallar el escaneo (exit 1) |
| markdownlint | `davidanson/markdownlint-cli2` con `.markdownlint.yaml` | 0 incidencias en 2 ficheros (v0.24.2) |

### Lo que NO está validado

- La **ejecución real en GitHub Actions** (runners, resolución de `uses:` entre repos, caché `gha`, permisos de `GITHUB_TOKEN`).
- El **push real a GHCR** y la rama por defecto en un repo remoto.
- El **comportamiento** de las acciones de terceros (`setup-terraform`, `setup-tflint`, `markdownlint-cli2-action`, `codecov-action`, `docker/*`...): se comprobó que sus etiquetas existen, no que funcionen como se espera en un runner.
- El paso de Trivy dentro del runner (se probó el mismo `docker run` en local, no con el daemon de buildx de GitHub ni la caché de la base de datos).

Reproducir `actionlint`:

```bash
docker run --rm -v "$PWD":/repo -w /repo rhysd/actionlint:1.7.12
docker run --rm -v "$PWD":/repo -w /repo rhysd/actionlint:1.7.12 examples/callers/*.yml
```

## Autotest (`ci.yml`)

[`ci.yml`](.github/workflows/ci.yml) llama a cada workflow reutilizable contra pequeñas fixtures de [`examples/`](examples/) (script Bash, paquete Python con tests, Dockerfile, módulo Terraform) y ejecuta `actionlint`. La imagen de ejemplo se construye y escanea con `push: false`, así que nunca se publica.

## Estructura

```text
.github/workflows/   workflows reutilizables + ci.yml
examples/callers/    cómo los consume otro repo
examples/{shell,python,docker,terraform}/   fixtures del autotest
docs/decisiones.md   decisiones de diseño
```

## Licencia

[MIT](LICENSE) © 2026 Daniel García Rodríguez
