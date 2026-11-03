# rmall

> Vacía un directorio con estilo y sin sustos. Plugin para [Oh My Zsh](https://ohmyz.sh).

`rmall` borra **todo el contenido** de un directorio (incluidos los ocultos), pero antes te muestra qué hay, cuánto pesa y qué podrías perder, y se niega a hacer tonterías.

```
  rmall  ~/proyectos/demo
  ────────────────────────────────────────────
  8 elementos · 1.204 archivos y carpetas · 412.3 MB
  Modo: borrado permanente

    398.1 MB  node_modules/
     12.0 MB  dist/
      2.1 MB  .git/
       4 KB  .env
       4 KB  README.md
             … y 3 más

  ⚠ Es la raíz de un repositorio git: se perderá .git (3 cambio(s) sin commit, 2 commit(s) sin push)

  Esto es grande (repositorio git con trabajo sin respaldar, 1.204 archivos)
  Escribe demo para confirmar: _
```

## Características

- **Vista previa**: número de elementos, archivos totales, tamaño y las entradas más pesadas (con colores para carpetas, enlaces y ejecutables).
- **Rutas protegidas**: nunca vacía `/`, `$HOME`, sus ancestros, `~/Documents`, `~/Desktop`, `~/.ssh`, `/usr`, `/etc`, `/opt/homebrew`… ni con `-y`.
- **Confirmación según el riesgo**: `[y/N]` normal; si hay muchos archivos, mucho peso o un repo git con trabajo sin respaldar, tienes que **escribir el nombre del directorio**.
- **Detecta git**: avisa de cambios sin commit, commits sin push, stashes y repos sin remoto.
- **Papelera** (`-t`): usa `/usr/bin/trash` en macOS, o `trash-put`/`gio trash` en Linux.
- **Simulación** (`-n`): lista todo lo que se borraría.
- **Exclusiones** (`-e '*.pdf'`, repetible) y **conservar ocultos** (`-H`).
- Cualquier directorio como argumento (`rmall ~/Downloads`), no solo el actual.
- Reporte final con lo liberado y el tiempo; avisa si algo no se pudo borrar.
- Seguro en scripts: sin terminal no hace nada salvo que pases `-y`.
- Autocompletado de zsh incluido. Respeta `NO_COLOR`.

## Instalación

### Oh My Zsh

```sh
git clone https://github.com/victorono/rmall ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/rmall
```

Añádelo a los plugins en `~/.zshrc` y recarga:

```sh
plugins=(... rmall)
```

### Otros gestores

- **antidote**: `victorono/rmall`
- **zinit**: `zinit light victorono/rmall`
- **Manual**: `source /ruta/a/rmall/rmall.plugin.zsh`

## Uso

```
rmall [opciones] [directorio]

  -n, --dry-run          Muestra qué se borraría, sin tocar nada
  -t, --trash            Mueve a la papelera en vez de borrar
      --rm               Borrado permanente (ignora RMALL_USE_TRASH=1)
  -e, --exclude PATRÓN   Conserva lo que coincida (glob, repetible)
  -H, --no-hidden        Conserva los archivos ocultos (.git, .env…)
  -y, --yes              No pide confirmación
  -q, --quiet            Salida mínima
  -V, --version          Muestra la versión
  -h, --help             Muestra la ayuda
```

```sh
rmall                          # vacía el directorio actual
rmall -n ~/Downloads           # simula
rmall -t -e '*.pdf' -e keep    # a la papelera, salvo PDFs y keep
rmall -H build                 # vacía build/ conservando los ocultos
```

## Configuración

Define estas variables en `~/.zshrc` (antes de `source $ZSH/oh-my-zsh.sh`):

| Variable | Por defecto | Descripción |
|---|---|---|
| `RMALL_USE_TRASH` | `0` | `1` para usar la papelera por defecto |
| `RMALL_PREVIEW` | `8` | Entradas en la vista previa |
| `RMALL_STRICT_COUNT` | `500` | Desde cuántos archivos se exige escribir el nombre |
| `RMALL_STRICT_SIZE_MB` | `1024` | Desde cuántos MB se exige escribir el nombre |
| `RMALL_PROTECTED` | `()` | Rutas extra que nunca se vacían |

```sh
RMALL_USE_TRASH=1
RMALL_PROTECTED=(~/trabajo ~/fotos)
```

## Licencia

MIT
