#!/bin/bash


COMMON_REQUIRED_BINS="nslookup grep tail awk"

OK_CHECK=0
TOTAL_CHECK=0

CHECK_DNS_ENTRY="exemple.org"
CHECK_DNS_ENTRY_VALUE="91.195.241.136"

CLOUDFLARE_v4="1.1.1.1 1.0.0.1"
CLOUDFLARE_v6="2606:4700:4700::1111 2606:4700:4700::1001"
ALTERNATE_DNS_v4="198.101.242.72 23.253.163.53"
CENSURFRIDNS_v4="91.239.100.100 89.233.43.71"
CENSURFRIDNS_v6="2001:67c:28a4::"
COMODO_SECURE_DNS_v4="8.26.56.26 8.20.247.20"
DNS_WATCH_v4="84.200.69.80 84.200.70.40"
DNS_WATCH_v6="2001:1608:10:25::1c04:b12f 2001:1608:10:25::9249:d69b"
FDN_v4="80.67.169.12"
FDN_v6="2001:910:800::12"
FREEDNS_v4="37.235.1.174 37.235.1.177"
FREENOM_WORLD_v4="80.80.80.80 80.80.81.81"
GOOGLE_PUBLIC_DNS_v4="8.8.8.8 8.8.4.4"
GOOGLE_PUBLIC_DNS_v6="2001:4860:4860::8888 2001:4860:4860::8844"
HURRICANE_ELECTRIC_v4="74.82.42.42"
LEVEL3_v4="209.244.0.3 209.244.0.4"
NEUSTAR_DNS_ADVANTAGE_v4="156.154.70.1 156.154.71.1"
NORTON_DNS_v4="198.153.192.1 198.153.194.1"
OPENDNS_v4="208.67.222.222 208.67.220.220"
OPENDNS_v6="2620:0:ccc::2 2620:0:ccd::2"
QUAD9_v4="9.9.9.9"
QUAD9_v6="2620:fe::fe"
VERISIGN_v4="64.6.64.6 64.6.65.6"
VERISIGN_v6="2620:74:1b::1:1 2620:74:1c::2:2"
YANDEX_DNS_v4="77.88.8.88 77.88.8.2"
YANDEX_DNS_v6="2a02:6b8::feed:bad 2a02:6b8:0:1::feed:bad"
PUNTCAT_v4="109.69.8.51"
PUNTCAT_v6="2a00:1508:0:4::9"

PUBLIC_DNS_RESOLVERS_v4="$CLOUDFLARE_v4 $ALTERNATE_DNS_v4 $CENSURFRIDNS_v4 $COMODO_SECURE_DNS_v4 $DNS_WATCH_v4 $FDN_v4 $FREEDNS_v4 $FREENOM_WORLD_v4 $GOOGLE_PUBLIC_DNS_v4 $HURRICANE_ELECTRIC_v4 $LEVEL3_v4 $NEUSTAR_DNS_ADVANTAGE_v4 $NORTON_DNS_v4 $OPENDNS_v4 $QUAD9_v4 $SAFEDNS_v4 $SKYDNS_v4 $VERISIGN_v4 $YANDEX_DNS_v4 $PUNTCAT_v4"
PUBLIC_DNS_RESOLVERS_v6="$CLOUDFLARE_v6 $CENSURFRIDNS_v6 $DNS_WATCH_v6 $FDN_v6 $GOOGLE_PUBLIC_DNS_v6 $OPENDNS_v6 $QUAD9_v6 $VERISIGN_v6 $YANDEX_DNS_v6 $PUNTCAT_v6"

function OK() {
  printf "\e[1;32m${1}\e[1;0m"
}

function KO() {
  printf "\e[1;31m${1}\e[1;0m"
}

function check_dns() {
  TOTAL_CHECK=$((TOTAL_CHECK+1))
  resolver="${1}"

  printf "Checking ${resolver}\t\t"
  ip=$(nslookup --timeout=1 "${CHECK_DNS_ENTRY}" "${resolver}" | grep Address: | tail -1 | awk '{ print $2 }')
  if [ "${ip}" == "${CHECK_DNS_ENTRY_VALUE}" ]; then
    OK_CHECK=$((OK_CHECK+1))
    OK "OK\n"
  else
    KO "KO"
    printf " - Expected ${CHECK_DNS_ENTRY_VALUE} got ${ip}\n"
  fi
}

function resume() {
  diff=$((TOTAL_CHECK-OK_CHECK))

  printf "Passed "
  if [ "$diff" -ne "0" ]; then
    KO "${OK_CHECK}"
    printf "/${TOTAL_CHECK}\n"
    KO "Your ISP doesn't allow you to talk to some public DNS servers...\n"
  else
    OK "${OK_CHECK}"
    printf "/${TOTAL_CHECK}\n"
    OK "Your ISP doesn't block external public DNS servers\n"
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
}

function main() {
  echo "########################"
  echo "## Starting DNS1 Test ##"
  echo "########################"

  check_bin

  for resolver_v4 in ${PUBLIC_DNS_RESOLVERS_v4}; do
    check_dns "${resolver_v4}"
  done

  for resolver_v6 in ${PUBLIC_DNS_RESOLVERS_v6}; do
    check_dns "${resolver_v6}"
  done

  resume
}

main