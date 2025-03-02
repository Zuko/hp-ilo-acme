# HP iLO ACME
Simple BASH script for generating and signing *HP iLO 4* CSR using DNS Challange _(OVH DNS)_ with [acme.sh](https://github.com/acmesh-official/acme.sh) client.

Dependencies:
* [acme.sh](https://github.com/acmesh-official/acme.sh)
* [jq](https://github.com/jqlang/jq)
* [curl (>8.3.0)](https://github.com/curl/curl)
* [openssl](https://github.com/openssl/openssl)

## Configuration

Download _(and unpack)_ [acme.sh](https://github.com/acmesh-official/acme.sh/archive/refs/heads/master.zip) to script directory and edit few variables:

```
FQDN="ilo.example.com"
USERNAME="USER"
PASSWORD='PA$$W0RD'
```

```
_OVH_END_POINT="ovh-eu" # OVH endpoint
_OVH_AK="xXx" # Application key
_OVH_AS="xXx" # Application secret
_OVH_CK="xXx" # Consumer key
```

## Run

```
./hp-ilo-acme.sh 
```

```
./hp-ilo-acme.sh
Requesting CSR from iLO
{
  "Messages": [
    {
      "MessageID": "iLO.0.10.GeneratingCertificate"
    }
  ],
  "Type": "ExtendedError.1.0.0",
  "error": {
    "@Message.ExtendedInfo": [
      {
        "MessageID": "iLO.0.10.GeneratingCertificate"
      }
    ],
    "code": "iLO.0.10.ExtendedInfo",
    "message": "See @Message.ExtendedInfo for more information."
  }
}
This will take a while…
Signing CSR with ACME.sh
[pon, 3 mar 2025, 00:05:55 CET] Copying CSR to: ./ilo.example.com/ilo.example.com.csr
[pon, 3 mar 2025, 00:05:55 CET] Using CA: https://acme-v02.api.letsencrypt.org/directory
[pon, 3 mar 2025, 00:05:55 CET] Signing from existing CSR.
[pon, 3 mar 2025, 00:05:57 CET] Getting webroot for domain='ilo.example.com'
[pon, 3 mar 2025, 00:05:57 CET] ilo.example.com is already verified, skipping dns-01.
[pon, 3 mar 2025, 00:05:57 CET] Verification finished, beginning signing.
[pon, 3 mar 2025, 00:05:57 CET] Let's finalize the order.
[pon, 3 mar 2025, 00:05:57 CET] Le_OrderFinalize='https://acme-v02.api.letsencrypt.org/acme/finalize/'
[pon, 3 mar 2025, 00:05:59 CET] Downloading cert.
[pon, 3 mar 2025, 00:05:59 CET] Le_LinkCert='https://acme-v02.api.letsencrypt.org/acme/cert/'
[pon, 3 mar 2025, 00:06:00 CET] Cert success.
-----BEGIN CERTIFICATE-----

-----END CERTIFICATE-----
[pon, 3 mar 2025, 00:06:00 CET] Your cert is in: ./ilo.example.com/ilo.example.com.cer
[pon, 3 mar 2025, 00:06:00 CET] The intermediate CA cert is in: ./ilo.example.com/ca.cer
[pon, 3 mar 2025, 00:06:00 CET] And the full-chain cert is in: ./ilo.example.com/fullchain.cer
Installing certificate
{
  "Messages": [
    {
      "MessageID": "iLO.0.10.ImportCertSuccessfuliLOResetinProgress"
    }
  ],
  "Type": "ExtendedError.1.0.0",
  "error": {
    "@Message.ExtendedInfo": [
      {
        "MessageID": "iLO.0.10.ImportCertSuccessfuliLOResetinProgress"
      }
    ],
    "code": "iLO.0.10.ExtendedInfo",
    "message": "See @Message.ExtendedInfo for more information."
  }
}
```
