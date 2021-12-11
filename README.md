# log4j_CVE-2021-44228_tester
Test for the log4j vulnerability ( CVE-2021-44228 ) across your external footprint

## Example Use

```
./log4j_CVE-2021-44228_tester.sh <INPUT_FILE> <CANARY_DOMAIN>
```

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

## False Positives
If you use egress SSL decryption + inspection this script may trigger false positives (as your IDS may before lookups on the canary token.. thus triggering it).

If this is the case then you are better off running it from a cloud instance that is not being inspected.


