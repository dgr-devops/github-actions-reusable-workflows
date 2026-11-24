# Decisiones de diseño

Registro breve de las decisiones tomadas y su motivo.

## 1. Workflows reutilizables (`workflow_call`) en lugar de acciones compuestas

Un workflow reutilizable puede definir sus propios jobs, `permissions`, `concurrency`, matrices y `timeout-minutes`, y se versiona como un fichero. Una acción compuesta solo agrupa pasos dentro del job del llamador y hereda sus permisos. Como el valor del repo está en estandarizar jobs completos, se eligió `workflow_call`.

Contrapartida: un reutilizable no puede ampliar los permisos del llamador, y los outputs hay que declararlos dos veces (job y workflow).

## 2. Mínimo privilegio en dos niveles

Todos declaran `permissions: contents: read` a nivel de workflow y repiten el permiso en el job. Solo `docker-build-scan-push` añade `packages: write` en su job. El llamador debe concederlo; si no, GitHub rechaza el job en lugar de degradarlo en silencio, lo que es preferible a publicar con permisos de más.

## 3. Versiones: etiqueta mayor ahora, SHA como endurecimiento

Las acciones se fijan a su etiqueta mayor (`actions/checkout@v4`, `docker/build-push-action@v6`...) y Trivy a una versión exacta (`0.28.0`). Es legible y recibe parches de seguridad menores, pero una etiqueta es mutable: si se compromete el repo de la acción, el cambio llega sin revisión.

Endurecimiento recomendado y **no aplicado todavía**: fijar cada `uses:` al SHA completo y mantenerlo con Dependabot (`github-actions`). No se hizo porque no se pueden verificar SHAs sin acceso a GitHub, y un SHA inventado rompería el pipeline.

Las herramientas (ruff, Terraform, TFLint) se fijan por versión exacta en inputs, con posibilidad de sobrescribirlas.

## 4. Inputs siempre vía variables de entorno

Interpolar `${{ inputs.x }}` dentro de un `run:` permite inyección de comandos. Todos los inputs que llegan a un script se pasan con `env:` y se usan entrecomillados. El único valor que se evalúa como código es `install-command` de `test-python`, que se ejecuta con `bash -c`, porque el propósito del input es que el llamador defina su comando de instalación; viene del repo llamador (de confianza), no de eventos externos.

## 5. Concurrencia con prefijo propio

En un workflow reutilizable, `github.workflow` es el nombre del workflow **llamador**. Si el reutilizable usara el mismo grupo que el llamador, la ejecución interna cancelaría o bloquearía a la externa. Por eso los grupos son `reusable-<nombre>-<workflow>-<ref>`.

`cancel-in-progress: true` en lint y tests (una ejecución nueva sustituye a la vieja). En Docker solo se cancela fuera de la rama por defecto, para no interrumpir una publicación.

## 6. Docker: construir, escanear y solo entonces publicar

Flujo: build local (`load: true`) → Trivy sobre esa imagen → login, etiquetas y push. El segundo build reutiliza la caché de capas (`type=gha`), por lo que el coste extra es pequeño y la imagen publicada nunca llega al registro sin haber pasado el escaneo.

- Trivy usa `exit-code: 1` con `HIGH,CRITICAL` por defecto.
- `ignore-unfixed: true` por defecto: no tiene sentido bloquear por vulnerabilidades sin parche. Es configurable.
- Limitación: con varias plataformas solo se escanea la imagen de la plataforma del runner (la que se carga localmente); las demás se publican sin escanear individualmente.
- Se publica solo si `inputs.push`, el evento no es `pull_request` y `github.ref` es la rama por defecto. Se calcula en un único paso para que la decisión sea explícita y visible en el log.
- El nombre de la imagen se pasa a minúsculas, porque GHCR no admite mayúsculas.

## 7. `registry-token` opcional con respaldo en `GITHUB_TOKEN`

Lo normal es no gestionar ningún secreto: el `GITHUB_TOKEN` basta para GHCR. El secreto opcional existe para publicar en otro registro o con un PAT, sin cambiar el workflow.

## 8. Python

- La matriz llega como array JSON en un input `string`, porque `workflow_call` no admite arrays; se expande con `fromJSON`.
- `pytest` y `pytest-cov` se instalan siempre; el proyecto define solo su propia instalación (`install-command`).
- La cobertura mínima (`--cov-fail-under`, 80 por defecto) es un input numérico.
- `fail-fast: false`: interesa ver en qué versiones falla, no solo la primera.
- La subida a Codecov es opcional y solo ocurre si se pasa el secreto. Un secreto no puede evaluarse en el `if:` de un paso, así que se copia a una variable de entorno del job y se comprueba esa.
- Ruff se instala con `pip` en una versión exacta en lugar de usar una acción, para no añadir una dependencia de terceros más.

## 9. Terraform

- `init -backend=false`: validar sin credenciales ni estado remoto, que es lo que se espera de un check de PR.
- Caché de plugins con `TF_PLUGIN_CACHE_DIR`, clave basada en `.terraform.lock.hcl`.
- `terraform_wrapper: false` para tener la salida cruda en los pasos siguientes.
- La fixture usa el recurso integrado `terraform_data`, de modo que `validate` no descarga ningún proveedor.
- El `GITHUB_TOKEN` se pasa a `tflint --init` solo para evitar el límite de peticiones anónimas al descargar plugins.

## 10. ShellCheck sin acción de terceros

ShellCheck viene preinstalado en los runners `ubuntu-*`, así que se invoca directamente. Se evita una dependencia y se controla qué ficheros se analizan (`find` con exclusiones y separador NUL, seguro con nombres con espacios). Si no hay scripts, avisa y termina en verde para no romper repos que aún no los tienen.

## 11. Autotest en este mismo repo

`ci.yml` consume los reutilizables con rutas locales (`./.github/workflows/...`) sobre fixtures mínimas. Así cualquier cambio rompe aquí antes que en un consumidor. La imagen de ejemplo usa `push: false`: el autotest no debe publicar nada.

Limitación asumida: una ruta local prueba el workflow del mismo commit, pero no la resolución `owner/repo/...@ref` que usarán los consumidores.

## 12. Qué se valida y cómo

`actionlint` (también ejecuta ShellCheck sobre los `run:`) se usa desde su imagen oficial de Docker, sin instalar nada. Los comandos de cada workflow (ruff, pytest, terraform, tflint, docker build, trivy) se ejecutaron además en contenedores equivalentes. Lo que no se puede comprobar sin GitHub (ejecución en runners, caché `gha`, publicación en GHCR) se declara como pendiente en el README en vez de darlo por bueno.

## 13. Pendiente y mejoras posibles

- Fijar las acciones por SHA y añadir Dependabot.
- Publicar una etiqueta `v1` y recomendar `@v1` a los consumidores.
- Subir los resultados de Trivy en formato SARIF a *Code scanning* (requiere `security-events: write`).
- Firmar imágenes con cosign y generar SBOM.
- Ejecutar el autotest en GitHub y ajustar lo que falle (primer paso tras el push).
