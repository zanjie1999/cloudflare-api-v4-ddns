#!/usr/bin/env bash
set -o errexit
set -o nounset
#set -o pipefail

# Automatically update your CloudFlare DNS record to the IP, Dynamic DNS
# Can retrieve cloudflare Domain id and list zone's, because, lazy
# Sparkle version

# Place at:
# sudo wget https://raw.githubusercontent.com/zanjie1999/cloudflare-api-v4-ddns/master/cf-v4-ddns.sh -O /usr/local/bin/cf-ddns.sh
# sudo chmod +x /usr/local/bin/cf-ddns.sh
# sudo nano /usr/local/bin/cf-ddns.sh
# run `crontab -e` and add next line:
# */2 * * * * /usr/local/bin/cf-ddns.sh >/dev/null 2>&1
# or you need log:
# */2 * * * * /usr/local/bin/cf-ddns.sh >> /var/log/cf-ddns.log 2>&1


# Usage:
# cf-ddns.sh -k cloudflare-api-token \
#            -h host.example.com \     # fqdn of the record you want to update
#            -z example.com \          # will show you all zones if forgot, but you need this
#            -t A|AAAA                 # specify ipv4/ipv6, default: ipv4
#            -p cache file path        # default /$HOME/.cf

# Optional flags:
#            -f false|true \           # force dns update, disregard local stored ip

# default config

# API Token, see https://dash.cloudflare.com/profile/api-tokens,
CFTOKEN=

# Zone name, eg: example.com
CFZONE_NAME=

# Hostname to update, eg: homeserver.example.com or example.com
CFRECORD_NAME=

# Record type, A(IPv4)|AAAA(IPv6), default IPv4
CFRECORD_TYPE=A

# Cloudflare TTL for record, between 120 and 86400 seconds
CFTTL=120

# Ignore local file, update ip anyway
FORCE=false

CFFILE_PATH=/$HOME/.cf

WANIPSITE="http://v4.ipv6-test.com/api/myip.php"

NOW_DATE_TIME=$(date "+%Y-%m-%d %H:%M:%S")

# Site to retrieve WAN ip, other examples are: bot.whatismyipaddress.com, https://api.ipify.org/ ...
if [ "$CFRECORD_TYPE" = "A" ]; then
  :
elif [ "$CFRECORD_TYPE" = "AAAA" ]; then
  WANIPSITE="http://v6.ipv6-test.com/api/myip.php"
else
  echo "$NOW_DATE_TIME $CFRECORD_TYPE specified is invalid, CFRECORD_TYPE can only be A(for IPv4)|AAAA(for IPv6)"
  exit 2
fi

# get parameter
while getopts k:h:z:t:f:p: opts; do
  case ${opts} in
    k) CFTOKEN=${OPTARG} ;;
    h) CFRECORD_NAME=${OPTARG} ;;
    z) CFZONE_NAME=${OPTARG} ;;
    t) CFRECORD_TYPE=${OPTARG} ;;
    f) FORCE=${OPTARG} ;;
    p) CFFILE_PATH=${OPTARG} ;;
  esac
done

# mkdir if CFFILE_PATH not exist
if [ ! -d "$CFFILE_PATH" ];then
    mkdir -p $CFFILE_PATH
fi

# If required settings are missing just exit
if [ "$CFTOKEN" = "" ]; then
  echo "$NOW_DATE_TIME Missing api-key, get at: https://dash.cloudflare.com/profile/api-tokens"
  echo "$NOW_DATE_TIME and save in ${0} or using the -k flag"
  exit 2
fi

if [ "$CFRECORD_NAME" = "" ]; then
  echo "$NOW_DATE_TIME Missing hostname, what host do you want to update?"
  echo "$NOW_DATE_TIME save in ${0} or using the -h flag"
  exit 2
fi

# If the hostname is not a FQDN
if [ "$CFRECORD_NAME" != "$CFZONE_NAME" ] && ! [ -z "${CFRECORD_NAME##*$CFZONE_NAME}" ]; then
  CFRECORD_NAME="$CFRECORD_NAME.$CFZONE_NAME"
  echo "$NOW_DATE_TIME  => Hostname is not a FQDN, assuming $CFRECORD_NAME"
fi

# Get current and old WAN ip
WAN_IP=`curl -s ${WANIPSITE}`
WAN_IP_FILE=$CFFILE_PATH/.cf-wan_ip_$CFRECORD_NAME.txt
if [ -f $WAN_IP_FILE ]; then
  OLD_WAN_IP=`cat $WAN_IP_FILE`
else
  echo "$NOW_DATE_TIME No file, need IP"
  OLD_WAN_IP=""
fi

# If WAN IP is unchanged an not -f flag, exit here
if [ "$WAN_IP" = "$OLD_WAN_IP" ] && [ "$FORCE" = false ]; then
  echo "$NOW_DATE_TIME WAN IP Unchanged, to update anyway use flag -f true"
  exit 0
fi

# Get zone_identifier & record_identifier
ID_FILE=$CFFILE_PATH/.cf-id_$CFRECORD_NAME.txt
if [ -f $ID_FILE ] && [ $(wc -l $ID_FILE | cut -d " " -f 1) == 4 ] \
  && [ "$(sed -n '3,1p' "$ID_FILE")" == "$CFZONE_NAME" ] \
  && [ "$(sed -n '4,1p' "$ID_FILE")" == "$CFRECORD_NAME" ]; then
    CFZONE_ID=$(sed -n '1,1p' "$ID_FILE")
    CFRECORD_ID=$(sed -n '2,1p' "$ID_FILE")
else
    echo "$NOW_DATE_TIME Updating zone_identifier & record_identifier"
    CFZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$CFZONE_NAME" -H "Authorization: Bearer $CFTOKEN" -H "Content-Type: application/json" | grep -Po '(?<="id":")[^"]*' | head -1 )
    CFRECORD_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CFZONE_ID/dns_records?name=$CFRECORD_NAME" -H "Authorization: Bearer $CFTOKEN" -H "Content-Type: application/json"  | grep -Po '(?<="id":")[^"]*' | head -1 )
    echo "$CFZONE_ID" > $ID_FILE
    echo "$CFRECORD_ID" >> $ID_FILE
    echo "$CFZONE_NAME" >> $ID_FILE
    echo "$CFRECORD_NAME" >> $ID_FILE
fi

# If WAN is changed, update cloudflare
echo "$NOW_DATE_TIME Updating DNS to $WAN_IP"

RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$CFZONE_ID/dns_records/$CFRECORD_ID" \
  -H "Authorization: Bearer $CFTOKEN" \
  -H "Content-Type: application/json" \
  --data "{\"id\":\"$CFZONE_ID\",\"type\":\"$CFRECORD_TYPE\",\"name\":\"$CFRECORD_NAME\",\"content\":\"$WAN_IP\", \"ttl\":$CFTTL}")

if [ "$RESPONSE" != "${RESPONSE%success*}" ] && [ "$(echo $RESPONSE | grep "\"success\":true")" != "" ]; then
  echo "$NOW_DATE_TIME Updated succesfuly!"
  echo "$WAN_IP" > $WAN_IP_FILE
  exit
else
  echo "$NOW_DATE_TIME Something went wrong :("
  echo "$NOW_DATE_TIME Response: $RESPONSE"
  exit 1
fi
