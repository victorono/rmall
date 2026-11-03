# rmall — vacía un directorio con estilo y sin sustos.
# https://github.com/victorono/rmall
#
# Uso: rmall [opciones] [directorio]      (rmall -h para la ayuda)

# Hace que el completado (_rmall) funcione también fuera de oh-my-zsh
# (antidote, zinit, sourcing manual…).
0="${ZERO:-${${0:#$ZSH_ARGZERO}:-${(%):-%N}}}"
0="${${(M)0:#/*}:-$PWD/$0}"
(( ${fpath[(Ie)${0:h}]} )) || fpath=("${0:h}" $fpath)

typeset -g RMALL_VERSION=1.0.0

# ── Configuración (definir en ~/.zshrc antes de cargar oh-my-zsh) ─────────────
: ${RMALL_USE_TRASH:=0}          # 1 = usar la papelera por defecto
: ${RMALL_PREVIEW:=8}            # cuántas entradas mostrar en la vista previa
: ${RMALL_STRICT_COUNT:=500}     # ≥ N archivos → confirmar escribiendo el nombre
: ${RMALL_STRICT_SIZE_MB:=1024}  # ≥ N MB      → confirmar escribiendo el nombre
(( ${+RMALL_PROTECTED} )) || typeset -ga RMALL_PROTECTED=()   # rutas extra intocables

zmodload -F zsh/datetime p:EPOCHREALTIME 2>/dev/null

# ── Helpers ───────────────────────────────────────────────────────────────────
_rmall_human() {  # KiB → texto legible
  local -F k=$1
  local -a u=(KB MB GB TB)
  local -i i=1
  while (( k >= 1024 && i < $#u )); do (( k /= 1024, i++ )); done
  if (( i == 1 )); then printf '%d %s' $k $u[i]; else printf '%.1f %s' $k $u[i]; fi
}

_rmall_num() {  # 12345 → 12.345
  local n=$1 out=
  while (( ${#n} > 3 )); do out=".${n[-3,-1]}$out"; n=${n[1,-4]}; done
  print -rn -- "$n$out"
}

_rmall_trash() {
  if [[ $OSTYPE == darwin* && -x /usr/bin/trash ]]; then
    /usr/bin/trash "$@"
  elif (( $+commands[trash-put] )); then
    command trash-put -- "$@"
  elif (( $+commands[gio] )); then
    command gio trash -- "$@"
  elif (( $+commands[trash] )); then
    command trash "$@"
  elif [[ $OSTYPE == darwin* ]] && (( $+commands[osascript] )); then
    local f; local -a list
    for f in "$@"; do list+=("POSIX file \"${${f//\\/\\\\}//\"/\\\"}\""); done
    command osascript -e "tell application \"Finder\" to delete {${(j:, :)list}}" >/dev/null
  else
    print -u2 "rmall: no encontré un comando de papelera (instala trash-cli o usa --rm)"
    return 127
  fi
}

_rmall_die() { print -u2 -r -- "$1 $2"; }

_rmall_help() {
  local b=$1 d=$2 c=$3 r=$4
  print -r -- "${b}rmall${r} ${d}v$RMALL_VERSION${r} — vacía un directorio con estilo y sin sustos

${b}USO${r}
  rmall [opciones] [directorio]        ${d}(por defecto: el directorio actual)${r}

${b}OPCIONES${r}
  ${c}-n, --dry-run${r}          Muestra qué se borraría, sin tocar nada
  ${c}-t, --trash${r}            Mueve a la papelera en vez de borrar
      ${c}--rm${r}               Borrado permanente (ignora RMALL_USE_TRASH=1)
  ${c}-e, --exclude PATRÓN${r}   Conserva lo que coincida (glob, repetible)
  ${c}-H, --no-hidden${r}        Conserva los archivos ocultos (.git, .env…)
  ${c}-y, --yes${r}              No pide confirmación (¡cuidado!)
  ${c}-q, --quiet${r}            Salida mínima
  ${c}-V, --version${r}          Muestra la versión
  ${c}-h, --help${r}             Muestra esta ayuda

${b}EJEMPLOS${r}
  rmall                          ${d}# vacía el directorio actual${r}
  rmall -n ~/Downloads           ${d}# simula${r}
  rmall -t -e '*.pdf' -e 'keep'  ${d}# a la papelera, salvo PDFs y keep${r}
  rmall -H build                 ${d}# vacía build/ conservando ocultos${r}

${b}SEGURIDAD${r}
  · Se niega a vaciar /, \$HOME, sus ancestros y rutas del sistema
    (amplíalas con RMALL_PROTECTED=(…)).
  · Pide escribir el nombre del directorio si hay ≥ $RMALL_STRICT_COUNT archivos,
    ≥ $RMALL_STRICT_SIZE_MB MB o un repositorio git con trabajo sin respaldar."
}

# ── Comando principal ─────────────────────────────────────────────────────────
rmall() {
  emulate -L zsh
  setopt extended_glob no_aliases

  # Colores (respetan NO_COLOR y salidas no-tty)
  local R= B= D= RED= GRN= YEL= BLU= CYN= MAG=
  if [[ -t 1 && -z ${NO_COLOR-} ]]; then
    R=$'\e[0m' B=$'\e[1m' D=$'\e[2m'
    RED=$'\e[31m' GRN=$'\e[32m' YEL=$'\e[33m' BLU=$'\e[34m' MAG=$'\e[35m' CYN=$'\e[36m'
  fi
  local ERR_PFX="${RED}✖${R} ${B}rmall:${R}"
  local OK="${GRN}✔${R}" WARN="${YEL}⚠${R}" ERR="${RED}✖${R}"

  # ── Opciones ──
  local -a o_help o_dry o_yes o_trash o_rm o_nohidden o_quiet o_version o_exclude
  zparseopts -D -E -F -- \
      h=o_help    -help=o_help \
      n=o_dry     -dry-run=o_dry \
      y=o_yes     -yes=o_yes \
      t=o_trash   -trash=o_trash \
                  -rm=o_rm \
      H=o_nohidden -no-hidden=o_nohidden \
      q=o_quiet   -quiet=o_quiet \
      V=o_version -version=o_version \
      e+:=o_exclude -exclude+:=o_exclude 2>/dev/null \
    || { _rmall_die "$ERR_PFX" "opción no válida (prueba ${CYN}rmall -h${R})"; return 2 }
  [[ $1 == -- ]] && shift

  (( $#o_help ))    && { _rmall_help "$B" "$D" "$CYN" "$R"; return 0 }
  (( $#o_version )) && { print -r -- "rmall $RMALL_VERSION"; return 0 }
  (( $# > 1 ))      && { _rmall_die "$ERR_PFX" "solo acepto un directorio (recibí $#)"; return 2 }

  local -a excludes
  local -i i
  for (( i = 2; i <= $#o_exclude; i += 2 )); do excludes+=("${o_exclude[i]#=}"); done

  local -i use_trash=$RMALL_USE_TRASH quiet=$#o_quiet dry=$#o_dry
  (( $#o_trash )) && use_trash=1
  (( $#o_rm ))    && use_trash=0

  # ── Directorio objetivo ──
  local target=${1:-$PWD}
  [[ -e $target ]] || { _rmall_die "$ERR_PFX" "no existe: $target"; return 1 }
  [[ -d $target ]] || { _rmall_die "$ERR_PFX" "no es un directorio: $target"; return 1 }
  target=${target:A}

  # ── Rutas protegidas ──
  local -a protected=(
    / $HOME /Users /home /root /System /Library /Applications /Volumes /Network
    /usr /usr/local /bin /sbin /etc /var /private /private/etc /private/var
    /opt /opt/homebrew /dev /boot /proc /sys /lib /lib64 /srv /mnt /media /snap
    $HOME/Library $HOME/Documents $HOME/Desktop $HOME/.ssh $HOME/.gnupg $HOME/.config
    ${ZSH:-} ${ZSH_CUSTOM:-} $RMALL_PROTECTED
  )
  local p
  for p in ${protected:#}; do
    if [[ $target == ${p:A} ]]; then
      _rmall_die "$ERR_PFX" "${B}$target${R} está protegido. Ni con -y."
      return 1
    fi
  done
  if [[ ${HOME:A} == $target/* ]]; then
    _rmall_die "$ERR_PFX" "${B}$target${R} contiene tu \$HOME. Ni lo sueñes."
    return 1
  fi
  [[ -w $target && -x $target ]] || { _rmall_die "$ERR_PFX" "sin permisos de escritura en $target"; return 1 }

  # ── Qué se va a borrar ──
  local -a all entries kept
  if (( $#o_nohidden )); then all=( $target/*(N) ); else all=( $target/*(DN) ); fi
  local e pat
  for e in $all; do
    for pat in $excludes; do
      if [[ ${e:t} == ${~pat} ]]; then kept+=$e; continue 2; fi
    done
    entries+=$e
  done
  local -i hidden_kept=0
  (( $#o_nohidden )) && { local -a _h=( $target/.*(DN) ); hidden_kept=$#_h }

  local pretty=$target
  [[ $target == $HOME/* ]] && pretty="~${target#$HOME}"

  if (( ! $#entries )); then
    (( quiet )) || print -r -- "${GRN}✨${R} ${B}$pretty${R} ya está vacío${D}${kept:+ (conservando $#kept)}${R}"
    return 0
  fi

  # ── Análisis (tamaño y conteo) ──
  local -i spin=0; (( ! quiet )) && [[ -t 1 ]] && spin=1
  (( spin )) && print -rn -- "${D}  analizando…${R}"
  local -a du_lines sorted
  du_lines=( "${(@f)$(command du -sk -- $entries 2>/dev/null)}" )
  sorted=( ${(On)du_lines} )
  local -i total_kb=0 nfiles=0
  local line
  for line in $du_lines; do (( total_kb += ${line%%$'\t'*} )); done
  nfiles=$(command find $entries 2>/dev/null | command wc -l)
  (( spin )) && print -rn -- $'\r\e[K'

  # ── Advertencias ──
  local -a warnings strict_reasons
  if (( ${entries[(Ie)$target/.git]} )); then
    local -i dirty=0 unpushed=0 stashes=0
    dirty=$(command git -C $target status --porcelain 2>/dev/null | command wc -l)
    local -i noremote=0
    if [[ -n $(command git -C $target remote 2>/dev/null) ]]; then
      unpushed=$(command git -C $target log --branches --not --remotes --oneline 2>/dev/null | command wc -l)
    else
      noremote=1
    fi
    stashes=$(command git -C $target stash list 2>/dev/null | command wc -l)
    local gmsg="Es la raíz de un repositorio git: se perderá ${B}.git${R}"
    local -a gextra
    (( dirty ))    && gextra+=("$dirty cambio(s) sin commit")
    (( unpushed )) && gextra+=("$unpushed commit(s) sin push")
    (( stashes ))  && gextra+=("$stashes stash(es)")
    (( noremote )) && gextra+=("sin remoto")
    (( $#gextra )) && gmsg+=" ${YEL}(${(j:, :)gextra})${R}"
    warnings+=$gmsg
    (( dirty + unpushed + stashes + noremote )) && strict_reasons+="repositorio git con trabajo sin respaldar"
  fi
  (( nfiles >= RMALL_STRICT_COUNT ))           && strict_reasons+="$(_rmall_num $nfiles) archivos"
  (( total_kb >= RMALL_STRICT_SIZE_MB * 1024 )) && strict_reasons+="$(_rmall_human $total_kb)"
  [[ ${PWD:A} == $target ]] || warnings+="No es tu directorio actual (${D}estás en ${PWD/#$HOME/~}${R})"

  # ── Resumen ──
  local mode
  if (( use_trash )); then mode="${BLU}🗑  a la papelera${R}"; else mode="${RED}${B}borrado permanente${R}"; fi
  (( dry )) && mode="${MAG}simulación${R} ${D}(no se borra nada)${R}"

  if (( ! quiet )); then
    print -r -- ""
    print -r -- "  ${B}${RED}rmall${R}  ${B}$pretty${R}"
    print -r -- "  ${D}────────────────────────────────────────────${R}"
    print -r -- "  ${B}$(_rmall_num $#entries)${R} elementos · ${B}$(_rmall_num $nfiles)${R} archivos y carpetas · ${B}$(_rmall_human $total_kb)${R}"
    print -r -- "  Modo: $mode"
    print -r -- ""

    local -i limit=$RMALL_PREVIEW
    (( dry )) && limit=$#sorted
    local kb fp name col
    for line in ${sorted[1,limit]}; do
      kb=${line%%$'\t'*} fp=${line#*$'\t'} name=${fp:t} col=
      if   [[ -L $fp ]]; then col=$CYN name+="${D} → $(command readlink -- $fp)"
      elif [[ -d $fp ]]; then col=$BLU$B name+=/
      elif [[ -x $fp ]]; then col=$GRN
      fi
      [[ ${fp:t} == .* && -z $col ]] && col=$D
      printf "  %s%10s%s  %s%s%s\n" "$D" "$(_rmall_human $kb)" "$R" "$col" "$name" "$R"
    done
    (( $#sorted > limit )) && print -r -- "  ${D}           … y $(( $#sorted - limit )) más${R}"

    local -a kept_names=( ${kept:t} )
    (( $#kept ))     && print -r -- "" && print -r -- "  ${OK} Se conservan $#kept por --exclude: ${D}${(j:, :)kept_names[1,5]}${kept[6]:+…}${R}"
    (( hidden_kept )) && print -r -- "  ${OK} Se conservan $hidden_kept oculto(s) por --no-hidden"
    for e in $warnings; do print -r -- "  ${WARN} $e"; done
    print -r -- ""
  fi

  (( dry )) && return 0

  # ── Confirmación ──
  if (( ! $#o_yes )); then
    if [[ ! -t 0 ]]; then
      _rmall_die "$ERR_PFX" "stdin no es una terminal; usa ${CYN}-y${R} para confirmar sin preguntar"
      return 1
    fi
    local ans
    if (( $#strict_reasons )); then
      print -r -- "  ${RED}${B}Esto es grande${R} ${D}(${(j:, :)strict_reasons})${R}"
      print -rn -- "  Escribe ${B}${target:t}${R} para confirmar: "
      read -r ans
      if [[ $ans != ${target:t} ]]; then
        print -r -- "  ${D}Cancelado. No se tocó nada.${R}"; return 1
      fi
    else
      print -rn -- "  ¿Eliminar todo esto? ${D}[y/N]${R} "
      read -r ans
      if [[ $ans != [yYsS]* ]]; then
        print -r -- "  ${D}Cancelado. No se tocó nada.${R}"; return 1
      fi
    fi
  fi

  # ── Borrado ──
  local -F t0=${EPOCHREALTIME:-0}
  local -i rc=0
  if (( use_trash )); then
    _rmall_trash $entries || rc=$?
  else
    command rm -rf -- $entries 2>/dev/null || rc=$?
  fi
  local -F secs=$(( ${EPOCHREALTIME:-0} - t0 ))

  local -a left
  for e in $entries; do [[ -e $e || -L $e ]] && left+=$e; done

  if (( $#left )); then
    print -u2 -r -- "  ${ERR} No pude eliminar $#left de $#entries elemento(s):"
    for e in ${left[1,5]}; do print -u2 -r -- "     ${D}${e:t}${R}"; done
    (( $#left > 5 )) && print -u2 -r -- "     ${D}… y $(( $#left - 5 )) más${R}"
    return 1
  fi

  local verb="eliminados" freed="liberados"
  (( use_trash )) && verb="enviados a la papelera" freed="movidos"
  if (( quiet )); then
    print -r -- "$#entries $verb ($(_rmall_human $total_kb))"
  else
    printf "  %s Listo: %s%d%s elementos %s · %s%s%s %s · %s%.2fs%s\n\n" \
      "$OK" "$B" $#entries "$R" "$verb" "$B" "$(_rmall_human $total_kb)" "$R" "$freed" "$D" $secs "$R"
  fi
  return $rc
}
