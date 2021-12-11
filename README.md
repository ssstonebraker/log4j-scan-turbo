# log4j_CVE-2021-44228_tester
Test for log4j vulnerability across your external footprint

## Requirements
You will need:
1. An inputfile with a list of IP addresses/domains (one per line)
2. A Canary Token (see below)


## Get a Canary Domain 
1. Browse to https://canarytokens.org/generate#
2. Selection Option "DNS"
3. Input Email Address
4. Input Comment
5. Hit "Create my Canary Token"

<img width="973" alt="image" src="https://user-images.githubusercontent.com/774940/145664156-fee98504-0a18-427c-8213-5f3818864a9a.png">


## Example Use

```
./log4j_CVE-2021-44228_tester.sh <INPUT_FILE> <CANARY_DOMAIN>
```
