#!/bin/bash
# Transcodes a given image file

export PATH=$PATH:/bin:/usr/bin:/usr/local/bin

### Configuration
#####################################################################

set -o errexit
set -o nounset
set -o pipefail

LOG_LEVEL="${LOG_LEVEL:-6}" # 7 = debug -> 0 = emergency
NO_COLOR="${NO_COLOR:-}"    # true = disable color. otherwise autodetected

read -r -d '' usage <<-'EOF' || true # exits non-zero when EOF encountered
  -f --file     [arg] Image file to transcode. Required.
  -m --manifest [arg] Output filename. Required.
  -o --out      [arg] Output directory. Required.
  -v                  Enable verbose mode, print script as it is executed
  -d --debug          Enables debug mode
  -h --help           This page
  -n --no-color       Disable color output
  -1 --one            Do just one thing
EOF

### Transcoding options
#####################################################################

MAX_RES="4096"
MID_RES="2048"
LOW_RES="1024"

### Functions
#####################################################################

function _fmt ()      {
  local color_debug="\x1b[35m"
  local color_info="\x1b[32m"
  local color_notice="\x1b[34m"
  local color_warning="\x1b[33m"
  local color_error="\x1b[31m"
  local color_critical="\x1b[1;31m"
  local color_alert="\x1b[1;33;41m"
  local color_emergency="\x1b[1;4;5;33;41m"
  local colorvar=color_$1

  local color="${!colorvar:-$color_error}"
  local color_reset="\x1b[0m"
  if [ "${NO_COLOR}" = "true" ] || [[ "${TERM:-}" != "xterm"* ]] || [ -t 1 ]; then
    # Don't use colors on pipes or non-recognized terminals
    color=""; color_reset=""
  fi
  echo -e "$(date -u +"%Y-%m-%d %H:%M:%S UTC") ${color}$(printf "[%9s]" ${1})${color_reset}";
}
function emergency () {                             echo "$(_fmt emergency) ${*}" 1>&2 || true; exit 1; }
function alert ()     { if [ "${LOG_LEVEL}" -ge 1 ]; then echo "$(_fmt alert) ${*}" 1>&2; else true; fi }
function critical ()  { if [ "${LOG_LEVEL}" -ge 2 ]; then echo "$(_fmt critical) ${*}" 1>&2; else true; fi }
function error ()     { if [ "${LOG_LEVEL}" -ge 3 ]; then echo "$(_fmt error) ${*}" 1>&2; else true; fi }
function warning ()   { if [ "${LOG_LEVEL}" -ge 4 ]; then echo "$(_fmt warning) ${*}" 1>&2; else true; fi }
function notice ()    { if [ "${LOG_LEVEL}" -ge 5 ]; then echo "$(_fmt notice) ${*}" 1>&2; else true; fi }
function info ()      { if [ "${LOG_LEVEL}" -ge 6 ]; then echo "$(_fmt info) ${*}" 1>&2; else true; fi }
function debug ()     { if [ "${LOG_LEVEL}" -ge 7 ]; then echo "$(_fmt debug) ${*}" 1>&2; else true; fi }

function help () {
  echo "" 1>&2
  echo " ${*}" 1>&2
  echo "" 1>&2
  echo "  ${usage}" 1>&2
  echo "" 1>&2
  exit 1
}

function adjust_resolution () {
  local height="$1"
  local width="$2"
  local max_res="$3"
  local filename="$4"

  if [ "${height}" -gt "${max_res}" ] || [ "${width}" -gt "${max_res}" ]; then
    convert -auto-orient -resize "${max_res}" "${arg_f}" "${arg_o}/${filename}" &
  else
    convert -auto-orient -resize "${width}"x"${height}" "${arg_f}" "${arg_o}/${filename}" &
  fi
  }

### Parse commandline options
#####################################################################

# Translate usage string -> getopts arguments, and set $arg_<flag> defaults
while read line; do
  # fetch single character version of option string
  opt="$(echo "${line}" |awk '{print $1}' |sed -e 's#^-##')"

  # fetch long version if present
  long_opt="$(echo "${line}" |awk '/\-\-/ {print $2}' |sed -e 's#^--##')"
  long_opt_mangled="$(sed 's#-#_#g' <<< $long_opt)"

  # map long name back to short name
  varname="short_opt_${long_opt_mangled}"
  eval "${varname}=\"${opt}\""

  # check if option takes an argument
  varname="has_arg_${opt}"
  if ! echo "${line}" |egrep '\[.*\]' >/dev/null 2>&1; then
    init="0" # it's a flag. init with 0
    eval "${varname}=0"
  else
    opt="${opt}:" # add : if opt has arg
    init=""  # it has an arg. init with ""
    eval "${varname}=1"
  fi
  opts="${opts:-}${opt}"

  varname="arg_${opt:0:1}"
  if ! echo "${line}" |egrep '\. Default=' >/dev/null 2>&1; then
    eval "${varname}=\"${init}\""
  else
    match="$(echo "${line}" |sed 's#^.*Default=\(\)#\1#g')"
    eval "${varname}=\"${match}\""
  fi
done <<< "${usage}"

# Allow long options like --this
opts="${opts}-:"

# Reset in case getopts has been used previously in the shell.
OPTIND=1

# start parsing command line
set +o nounset # unexpected arguments will cause unbound variables
               # to be dereferenced
# Overwrite $arg_<flag> defaults with the actual CLI options
while getopts "${opts}" opt; do
  [ "${opt}" = "?" ] && help "Invalid use of script: ${*} "

  if [ "${opt}" = "-" ]; then
    # OPTARG is long-option-name or long-option=value
    if [[ "${OPTARG}" =~ .*=.* ]]; then
      # --key=value format
      long=${OPTARG/=*/}
      long_mangled="$(sed 's#-#_#g' <<< $long)"
      # Set opt to the short option corresponding to the long option
      eval "opt=\"\${short_opt_${long_mangled}}\""
      OPTARG=${OPTARG#*=}
    else
      # --key value format
      # Map long name to short version of option
      long_mangled="$(sed 's#-#_#g' <<< $OPTARG)"
      eval "opt=\"\${short_opt_${long_mangled}}\""
      # Only assign OPTARG if option takes an argument
      eval "OPTARG=\"\${@:OPTIND:\${has_arg_${opt}}}\""
      # shift over the argument if argument is expected
      ((OPTIND+=has_arg_${opt}))
    fi
    # we have set opt/OPTARG to the short value and the argument as OPTARG if it exists
  fi
  varname="arg_${opt:0:1}"
  default="${!varname}"

  value="${OPTARG}"
  if [ -z "${OPTARG}" ] && [ "${default}" = "0" ]; then
    value="1"
  fi

  eval "${varname}=\"${value}\""
  debug "cli arg ${varname} = ($default) -> ${!varname}"
done
set -o nounset # no more unbound variable references expected

shift $((OPTIND-1))

[ "${1:-}" = "--" ] && shift

### Switches (like -d for debugmode, -h for showing helppage)
#####################################################################

# debug mode
if [ "${arg_d}" = "1" ]; then
  set -o xtrace
  LOG_LEVEL="7"
fi

# verbose mode
if [ "${arg_v}" = "1" ]; then
  set -o verbose
fi

# help mode
if [ "${arg_h}" = "1" ]; then
  # Help exists with code 1
  help "Help using ${0}"
fi

### Validation (decide what's required for running your script and error out)
#####################################################################

[ -z "${arg_m:-}" ]     && help      "Setting an output filename with -m or --manifest is required"
[ -z "${LOG_LEVEL:-}" ] && emergency "Cannot continue without LOG_LEVEL. "

[ -f "${arg_f}" ] || emergency "The parameter -f must point to a valid file"
[ -d "${arg_o}" ] || emergency "The parameter -o must point to a valid directory"

### Runtime
#####################################################################

# determine real extension from looking at the image format
file_format=$(identify -format "%m" "${arg_f}")
case "${file_format}" in
"PNG")
  target_extension=png
  ;;
"SVG")
  target_extension=svg
  ;;
"JPEG")
  target_extension=jpg
  ;;
"BMP")
  target_extension=bmp
  ;;
"BMP3")
  target_extension=bmp
  ;;
*)
  # this might be an SVG without size information
  file_format2=$(identify -format "%m" -size 100x100 "${arg_f}")
  case "${file_format2}" in
  "SVG")
    target_extension=svg
    ;;
  *)
    echo "Cannot handle image format: ${file_format}" && exit 1
    ;;
  esac
esac

lowres_filename=lowres_${arg_m%.*}.${target_extension}
midres_filename=midres_${arg_m%.*}.${target_extension}
preview_filename=preview_${arg_m%.*}.${target_extension}
squared_filename=squared_${arg_m%.*}.${target_extension}
thumb_filename=thumb_${arg_m%.*}.${target_extension}
maxres_filename=${arg_m%.*}.${target_extension} # for static image

if [ "${target_extension}" = "svg" ]; then
  if [ "${arg_f}" != "${arg_o}/${arg_m}" ]; then
    cp ${arg_f} ${arg_o}/${arg_m}
    cp ${arg_f} ${arg_o}/${lowres_filename}
    cp ${arg_f} ${arg_o}/${midres_filename}
    cp ${arg_f} ${arg_o}/${preview_filename}
    cp ${arg_f} ${arg_o}/${squared_filename}
    cp ${arg_f} ${arg_o}/${thumb_filename}
  fi
else
  dim=$(convert -auto-orient ${arg_f} -ping -format "%w %h" info:)
  width=$(echo $dim | cut -d' ' -f 1)
  height=$(echo $dim | cut -d' ' -f 2)

  # create support image paths
  convert -auto-orient -strip -resize 1920x960 -quality 40 ${arg_f} ${arg_o}/${preview_filename} &
  convert -auto-orient -strip -resize 1080x540 -quality 40 ${arg_f} ${arg_o}/${thumb_filename} &
  convert -auto-orient -thumbnail 512x512^ -gravity center -extent 512x512 ${arg_f} \
    ${arg_o}/${squared_filename} &

  # The image aspect ratio is preserved across all resolutions,
  # with the highest value of either height or width being replaced by the given resolution if it exceeds it.
  # Imagemagic then adjusts the other value accordingly.
  # If the original height and width values do not exceed the given resolution, the conversion is carried out using these values.

  # Static image
  adjust_resolution "${height}" "${width}" "${MAX_RES}" "${maxres_filename}"

  # Low resolution image
  adjust_resolution "${height}" "${width}" "${LOW_RES}" "${lowres_filename}"

  # Mid resolution image
  adjust_resolution "${height}" "${width}" "${MID_RES}" "${midres_filename}"

  echo "Waiting for image conversion jobs to finish."
  wait
fi
