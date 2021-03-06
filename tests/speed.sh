#!/bin/bash

#set -o xtrace

# Automation of https://ip.lafibre.info/neutralite.php

LINUX_REQUIRED_BINS="sha256sum"
MACOS_REQUIRED_BINS="shasum"
COMMON_REQUIRED_BINS="grep curl awk"

HASH_ALGORITHM=sha256sum

BASE_HOSTNAME=bouygues.testdebit.info
BASE_URI_PATTERN=@@size@@
FILE_FORMAT="3gp 7z aac aif apk asf au avi bin bz2 c com css dat deb divx dmg doc docx exe file flv gdf gif gz h hqx htm html ipa iso jpeg jpg js mka mks mkv mov mp3 mp4 mpg msi odp ods odt ova pdf php png ppt pptx rar raw rmvb rpm sea sit snap svg swf tar bz2 gz xz tgz ttf txt u unknown uu vqf wav webm webp wma wmv woff2 xls xlsx xml xvid xyz xz zip"
FILE_SIZE="0 1 5 10 50 100 500 1k 5k 10k 50k 100k 500k 1M 5M 10M 50M 100M 1G 10G"
SERVER_PORTS_HTTPS="443 444 554 585 843 1194 1935 5060 5061 6881 8080 8443 9001"
SERVER_PORTS_HTTP="80 81"
PROTOS="http https"
IPVXS="4 6"

FILE_PATTERN=@@size@@.@@format@@

OK_CHECK=0
TOTAL_CHECK=0

function OK() {
  printf "\e[1;32m${1}\e[1;0m"
}

function KO() {
  printf "\e[1;31m${1}\e[1;0m"
}

function get_checksum() {
  file_id=$(echo "${1}" | sed -e 's/\..*//')
  grep "  ${file_id}\.iso" "${WORKDIR}/${HASH_ALGORITHM}.txt" | awk '{ print $1 }'
}

function macos_hash() {
  file_path="${1}"
  case $HASH_ALGORITHM in
    sha256sum)
      shasum -a 256 "${file_path}" | awk '{ print $1 }'
      ;;
    *)
      echo "Unknown hash algorithm"
      ;;
  esac
}

function hash_calc() {
  file_path="${1}"
  uname -a | grep "Darwin" > /dev/null 2>&1
  if [ "$?" -eq "0" ]; then
    macos_hash "${file_path}"
  else
    ${HASH_ALGORITHM} "${file_path}" | awk '{ print $1 }'
  fi
}

function download_file() {
  ipvx="${1}"
  proto="${2}"
  port="${3}"
  file_path="${4}"
  file_id="${5}"
  workdir="${6}"
  curl -sSL -"${ipvx}" "${proto}://ipv${ipvx}.${BASE_HOSTNAME}:${port}/${file_path}/${file_id}" > "${workdir}/${ipvx}_${proto}_${port}_${file_id}" 2>/dev/null
}

function check_file() {
  TOTAL_CHECK=$((TOTAL_CHECK+1))
  ipvx="${1}"
  proto="${2}"
  port="${3}"
  file_id="${4}"
  workdir="${5}"
  printf "Checking file \"ipv${ipvx} ${proto} :${port} - ${file_id}\":\t\t"
  calculated_hashsum=$(hash_calc "${workdir}/${ipvx}_${proto}_${port}_${file_id}")
  real_hashsum=$(get_checksum "${file_id}")
  if [ "${calculated_hashsum}" == "${real_hashsum}" ]; then
    OK_CHECK=$((OK_CHECK+1))
    OK "OK\n"
  else
    KO "KO"
    printf " - Got ${calculated_hashsum} instead of ${real_hashsum}\n"
  fi
}

function clear_file() {
  ipvx="${1}"
  proto="${2}"
  port="${3}"
  file_id="${4}"
  workdir="${5}"
  
  rm "${workdir}/${ipvx}_${proto}_${port}_${file_id}"
}

function check_times() {
  times="${1}"

  standard_deviation=$(echo -e "${times}" | awk '{sum+=$1; sumsq+=$1*$1}END{print sqrt(sumsq/NR - (sum/NR)**2)}')
  echo -e "\n==========\n"
  echo -e "Standard Deviation:\t ${standard_deviation}s"
  echo -e "\n==========\n"
}

function resume() {
  diff=$((TOTAL_CHECK-OK_CHECK))

  printf "Passed "
  if [ "$diff" -ne "0" ]; then
    KO "${OK_CHECK}"
    printf "/${TOTAL_CHECK}\n"
    KO "Your internet connection doesn't respect net neutrality standard. Check with your ISP provider...\n"
    exit 1
  else
    OK "${OK_CHECK}"
    printf "/${TOTAL_CHECK}\n"
    OK "Net neutrality seems to be applied by your ISP provider, great news !\n"
    exit 0
  fi
}

function check_bin() {
  for bin in ${COMMON_REQUIRED_BINS}; do
    which "${bin}" > /dev/null 2>&1
    if [ "$?" -ne "0" ]; then
      echo "Missing binary : ${bin}"
      exit 1
    fi
  done

  uname -a | grep "Darwin" > /dev/null 2>&1
  if [ "$?" -eq "0" ]; then
    specific_bins="${MACOS_REQUIRED_BINS}"
  else
    specific_bins="${LINUX_REQUIRED_BINS}"
  fi

  for bin in ${specific_bins}; do
    which "${bin}" > /dev/null 2>&1
    if [ "$?" -ne "0" ]; then
      echo "Missing binary : ${bin}"
      exit 1
    fi
  done
}

function main_file() {
  size="${1}"
  format="${2}"
  ipvx="${3}"
  proto="${4}"
  port="${5}"
  workdir="${6}"

  file_id=$(echo ${FILE_PATTERN} | sed -e 's/@@size@@/'${size}'/' -e 's/@@format@@/'${format}'/')
  file_path=$(echo ${BASE_URI_PATTERN} | sed -e 's/@@size@@/'${size}'/')

  start_at=$(date +%s)
  printf "Downloading file \"ipv${ipvx} ${proto} :${port} - ${file_id}\":\t"
  download_file "${ipvx}" "${proto}" "${port}" "${file_path}" "${file_id}" "${workdir}"
  if [ "$?" -eq "0" ]; then
    end_at=$(date +%s)

    delta=$((end_at-start_at))
    uname -a | grep "Darwin" > /dev/null 2>&1
    if [ "$?" -eq "0" ]; then
      printf "$(date -r ${delta} +%Mm%Ss)\n"
    else
      printf "$(date -d "@${delta}" +%Mm%Ss)\n"
    fi
    times="${times}${delta}\n"

    check_file "${ipvx}" "${proto}" "${port}" "${file_id}" "${workdir}"
  else
    KO "KO"
    printf " - Unable to download the file\n"
  fi
  clear_file "${ipvx}" "${proto}" "${port}" "${file_id}" "${workdir}"
}

function loop() {
  if [ "$#" -ne "6" ]; then
    usage
    exit 1
  fi

  workdir="${1}"
  file_sizes="${2}"
  file_formats="${3}"
  protos="${4}"
  ports="${5}"
  ipvxs="${6}"

  for size in $file_sizes; do
    times=""
    for format in $file_formats; do
      for proto in $protos; do
        if [ "$ports" == "all" ]; then
          if [ "$proto" == "https" ]; then
            ports2="$SERVER_PORTS_HTTPS"
          elif [ "$proto" == "http" ]; then
            ports2="$SERVER_PORTS_HTTP"
          fi
        else
          ports1="$portss"
        fi
        for port in $ports2; do
          for ipvx in $ipvxs; do
            main_file "${size}" "${format}" "${ipvx}" "${proto}" "${port}" "${workdir}"
          done
        done
      done
    done
    check_times "${times}"
  done
}

function usage() {
  echo -e "\nUsage : $0 all | $0 <size> <format> <ipvx> <proto> <port>"
  echo -e "\t<size> : ${FILE_SIZE}"
  echo -e "\t<format> : ${FILE_FORMAT}"
  echo -e "\t<ipvx> : ${IPVXS}"
  echo -e "\t<proto> : ${PROTOS}"
  echo -e "\t<port> : http : ${SERVER_PORTS_HTTP} | https : ${SERVER_PORTS_HTTPS}"
}

function main() {
  echo "#########################"
  echo "## Starting Image Test ##"
  echo "#########################"

  check_bin

  printf "Setup workdir: "
  WORKDIR=$(mktemp -d)
  printf "${WORKDIR}\n"

  printf "Downloading test data:\t\t"
  curl -sSL "https://${BASE_HOSTNAME}/${HASH_ALGORITHM}.txt" > "${WORKDIR}/${HASH_ALGORITHM}.txt"
  OK "OK\n"

  if [ "${1}" == "all" ]; then
    loop "${WORKDIR}" "${FILE_SIZE}" "${FILE_FORMAT}" "${PROTOS}" "all" "${IPVXS}"
  else
    loop "${WORKDIR}" "${@}"
  fi

  printf "Cleaning up workdir: "
  rm -rf "${WORKDIR}"
  OK "OK\n"

  resume
}

main "${@}"