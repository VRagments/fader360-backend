#!/bin/bash
# Transcodes a given video file into MPEG-DASH

export PATH=$PATH:/bin:/usr/bin:/usr/local/bin

### Configuration
#####################################################################

set -o errexit
set -o nounset
set -o pipefail

LOG_LEVEL="${LOG_LEVEL:-6}" # 7 = debug -> 0 = emergency
NO_COLOR="${NO_COLOR:-}"    # true = disable color. otherwise autodetected

read -r -d '' usage <<-'EOF' || true # exits non-zero when EOF encountered
  -f --file     [arg] Video file to transcode. Required.
  -m --manifest [arg] Output filename of the manifest. Required.
  -o --out      [arg] Output directory.
  -b --basename [arg] Output file basename. Default="dash"
  -t --threads  [arg] Number of threads used for encoding. Default="1"
  -p --profiles [arg] Transcoding profiles to be used. Default="720_1"
  -v                  Enable verbose mode, print script as it is executed
  -d --debug          Enables debug mode
  -h --help           This page
  -n --no-color       Disable color output
  -1 --one            Do just one thing
EOF

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
  echo -e "$(date -u +"%Y-%m-%d %H:%M:%S UTC") ${color}$(printf "[%9s]" "${1}")${color_reset}";
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

[ -z "${arg_m:-}" ]     && help      "Setting a manifest name with -m or --manifest is required"
[ -z "${LOG_LEVEL:-}" ] && emergency "Cannot continue without LOG_LEVEL. "

[ -f "${arg_f}" ] || emergency "The parameter -f must point to a valid file"
[ -d "${arg_o}" ] || emergency "The parameter -o must point to a valid directory"

### Runtime
#####################################################################

ffmpeg="ffmpeg -y -v quiet"
convert="convert"

file_suffix="m3u8"

vcodec="-c:v libx264"

vcodec_hls_params="-dn -r 30 -g 30 -vsync 1 -pix_fmt yuv420p -ac 2 -profile:v baseline -level 30 \
  -rc-lookahead 0 -refs 1 -acodec aac -async 1 -ar 44100 -ab 64k \
  -muxdelay 0 -start_number 0 -hls_time 10 -hls_list_size 0 -f hls -threads ${arg_t}"

thumb_filename_png=thumb_${arg_m%.*}.png
thumb_filename_jpg=thumb_${arg_m%.*}.jpg
preview_filename_jpg=preview_${arg_m%.*}.jpg
squared_filename_jpg=squared_${arg_m%.*}.jpg

function transcode_video()
{
  local profile="$1"
  local width="$2"
  local height="$3"

  # video_res = ( "long edge" "short edge" "bitrate" )
  local video_res=()
  case "$profile" in
    720_1)
      video_res=( "1280" "720" "1000" )
      ;;
    720_2)
      video_res=( "1280" "720" "1500" )
      ;;
    720_3)
      video_res=( "1280" "720" "2500" )
      ;;
    1080_1)
      video_res=( "1920" "1080" "2000" )
      ;;
    1080_2)
      video_res=( "1920" "1080" "3000" )
      ;;
    1080_3)
      video_res=( "1920" "1080" "5000" )
      ;;
    1440_1)
      video_res=( "2560" "1440" "4000" )
      ;;
    1440_2)
      video_res=( "2560" "1440" "6000" )
      ;;
    1440_3)
      video_res=( "2560" "1440" "9000" )
      ;;
    *)
      video_res=( "1280" "720" "1000" )
      ;;
  esac

  local video_resolution="${video_res[0]}x${video_res[1]}"
  local video_scale="w=-2:h=${video_res[1]}"
  if [ ${width} -lt ${height} ]; then
    video_resolution="${video_res[1]}x${video_res[0]}"
    video_scale="w=${video_res[1]}:h=-2"
  fi
  local video_filename="${arg_o}/${arg_b}_${video_res[1]}p_${video_res[2]}k.${file_suffix}"

  ${ffmpeg} -i ${arg_f} -vf scale=${video_scale} ${vcodec} -x264opts \
    bitrate=${video_res[2]}:vbv-maxrate=${video_res[2]} \
    ${vcodec_hls_params} ${video_filename}

  local video_bandwidth=$(echo "${video_res[2]} * 1000" | bc)
  echo "#EXT-X-STREAM-INF:PROGRAM-ID=1,BANDWIDTH=${video_bandwidth},RESOLUTION=${video_resolution}" >> ${arg_o}/${arg_m}
  echo "$(basename ${video_filename})" >> ${arg_o}/${arg_m}
}

echo "#EXTM3U" > ${arg_o}/${arg_m}
echo "#EXT-X-VERSION:6" >> ${arg_o}/${arg_m}

dim=$(ffprobe -v error -select_streams v -show_entries stream=width,height -print_format default=noprint_wrappers=1:nokey=1 "${arg_f}")
width=$(echo $dim | cut -d' ' -f 1)
height=$(echo $dim | cut -d' ' -f 2)
# switch width and height on rotated video
rotation="$(ffprobe -v error -select_streams v -show_streams "${arg_f}" | (grep rotation || echo '0') | cut -d'=' -f 2)"

if [ ${rotation#-} -eq "90" ] || [ ${rotation#-} -eq "270" ]; then
  t=$width
  width=$height
  height=$t
fi

for i in ${arg_p//,/ }
do
  transcode_video $i $width $height
done

# Build thumbnail and preview images

${ffmpeg} -i ${arg_f} -vf "thumbnail" -frames:v 1 ${arg_o}/${thumb_filename_png}

${convert} -strip -resize 1080x540 -quality 40 ${arg_o}/${thumb_filename_png} ${arg_o}/${thumb_filename_jpg} &
${convert} -strip -resize 1920x960 -quality 40 ${arg_o}/${thumb_filename_png} ${arg_o}/${preview_filename_jpg} &
${convert} -thumbnail 512x512^ -gravity center -extent 512x512 ${arg_o}/${thumb_filename_png} ${arg_o}/${squared_filename_jpg} &
echo 'Waiting for image conversion jobs to finish.'
wait

rm ${arg_o}/${thumb_filename_png}
