#!/bin/bash

#set -o xtrace

# Automation of https://ip.lafibre.info/neutralite.php

# md5sum OR sha256sum
HASH_ALGORITHM=md5sum

BASE_HOSTNAME=ipv4v6.lafibre.info
BASE_URI=images_test

IMAGE_PATTERN=image_@@id@@.@@format@@

OK_CHECK=0
TOTAL_CHECK=0

function OK() {
  printf "\e[1;32m${1}\e[1;0m"
}

function KO() {
  printf "\e[1;31m${1}\e[1;0m"
}

function get_checksum() {
  image_id="$1"
  grep "${image_id}" "${WORKDIR}/${HASH_ALGORITHM}.txt" | awk '{ print $1 }'
}

function macos_hash() {
  image_path="${1}"
  case $HASH_ALGORITHM in
    md5sum)
      md5 -q "${image_path}"
      ;;
    sha256sum)
      sha -a 256 "${image_path}" | awk '{ print $1 }'
      ;;
    *)
      echo "Unknown hash algorithm"
      ;;
  esac
}

function hash_calc() {
  image_path="${1}"
  uname -a | grep "Darwin" > /dev/null 2>&1
  if [ "$?" -eq "0" ]; then
    macos_hash "${image_path}"
  else
    ${HASH_ALGORITHM} "${image_path}"
  fi
}

function download_image() {
  ipvx="${1}"
  proto="${2}"
  image_id="${3}"
  workdir="${4}"
  curl -sSL -"${ipvx}" "https://${BASE_HOSTNAME}/${BASE_URI}/${image_id}" > "${workdir}/${ipvx}_${proto}_${image_id}"
}

function check_image() {
  TOTAL_CHECK=$((TOTAL_CHECK+1))
  ipvx="${1}"
  proto="${2}"
  image_id="${3}"
  workdir="${4}"
  printf "Checking image \"ipv${ipvx} ${proto} - ${image_id}\": "
  calculated_hashsum=$(hash_calc "${workdir}/${ipvx}_${proto}_${image_id}")
  real_hashsum=$(get_checksum "${image_id}")
  if [ "${calculated_hashsum}" == "${real_hashsum}" ]; then
    OK_CHECK=$((OK_CHECK+1))
    OK "OK\n"
  else
    KO "KO"
    printf " - Got ${calculated_hashsum} instead of ${real_hashsum}\n"
  fi
}

function resume() {
  diff=$((TOTAL_CHECK-OK_CHECK))

  printf "Passed "
  if [ "$diff" -ne "0" ]; then
    KO "${OK_CHECK}"
    printf "/${TOTAL_CHECK}\n"
    KO "Your internet connection doesn't respect net neutrality standard. Check with your ISP provider...\n"
  else
    OK "${OK_CHECK}"
    printf "/${TOTAL_CHECK}\n"
    OK "Net neutrality seems to be applied by your ISP provider, great news !\n"
  fi
} 

function main() {
  echo "#########################"
  echo "## Starting Image Test ##"
  echo "#########################"

  printf "Setup workdir: "
  WORKDIR=$(mktemp -d)
  printf "${WORKDIR}\n"

  printf "Downloading test data: "
  curl -sSL "https://${BASE_HOSTNAME}/${BASE_URI}/${HASH_ALGORITHM}.txt" > "${WORKDIR}/${HASH_ALGORITHM}.txt"
  OK "OK\n"

  for ipvx in 4 6; do
    for proto in http https; do
      image_id=$(echo ${IMAGE_PATTERN} | sed -e 's/@@id@@/original/' -e 's/@@format@@/png/')
      download_image "${ipvx}" "${proto}" "${image_id}" "${WORKDIR}"
      check_image "${ipvx}" "${proto}" "${image_id}" "${WORKDIR}"
    done
  done

  for ipvx in 4 6; do
    for proto in http https; do
      for i in {1..10}; do
        image_id=$(echo ${IMAGE_PATTERN} | sed -e 's/@@id@@/quality_'$(printf "%02d" $i)'0/' -e 's/@@format@@/jpg/')

        download_image "${ipvx}" "${proto}" "${image_id}" "${WORKDIR}"
        check_image "${ipvx}" "${proto}" "${image_id}" "${WORKDIR}"
      done
    done
  done


  printf "Cleaning up workdir: "
  rm -rf "${WORKDIR}"
  OK "OK\n"

  resume
}

main