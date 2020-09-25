#!/bin/bash

COMMON_REQUIRED_BINS="nslookup grep tail awk"

OK_CHECK=0
TOTAL_CHECK=0

TOP_50_DOMAINS="google.com youtube.com tmall.com baidu.com qq.com facebook.com sohu.com taobao.com 360.cn jd.com yahoo.com amazon.com wikipedia.org sina.com.cn weibo.com zoom.us live.com reddit.com netflix.com xinhuanet.com microsoft.com okezone.com vk.com office.com instagram.com alipay.com csdn.net myshopify.com yahoo.co.jp microsoftonline.com bongacams.com twitch.tv zhanqi.tv panda.tv google.com.hk bing.com naver.com ebay.com aliexpress.com china.com.cn amazon.in tianya.cn tribunnews.com google.co.in amazon.co.jp livejasmin.com adobe.com chaturbate.com twitter.com yandex.ru"

function get_dns_servers() {
  cat /etc/resolv.conf | grep 'nameserver' | awk '{ print $2 }'
}

FAKE_IPS="127.0.0.1 0.0.0.0 $(get_dns_servers)"


function OK() {
  printf "\e[1;32m${1}\e[1;0m"
}

function KO() {
  printf "\e[1;31m${1}\e[1;0m"
}

function check_dns() {
  TOTAL_CHECK=$((TOTAL_CHECK+1))
  domain="${1}"

  printf "Checking ${domain}\t\t"
  ip=$(nslookup --timeout=1 "${domain}" | grep Address: | tail -1 | awk '{ print $2 }')
  echo "${FAKE_IPS}" | grep "${ip}" > /dev/null 2>&1
  if [ "$?" -eq "1" ]; then
    OK_CHECK=$((OK_CHECK+1))
    OK "OK\n"
  else
    KO "KO"
    printf " - Got ${ip}\n"
  fi
}

function resume() {
  diff=$((TOTAL_CHECK-OK_CHECK))

  printf "Passed "
  if [ "$diff" -ne "0" ]; then
    KO "${OK_CHECK}"
    printf "/${TOTAL_CHECK}\n"
    KO "Your DNS server seems to be blocking some DNS entries...\n"
  else
    OK "${OK_CHECK}"
    printf "/${TOTAL_CHECK}\n"
    OK "Your DNS server can resolve anything, great news!\n"
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
  echo "## Starting DNS2 Test ##"
  echo "########################"

  check_bin

  for domain in ${TOP_50_DOMAINS}; do
    check_dns "${domain}"
  done

  resume
}

main