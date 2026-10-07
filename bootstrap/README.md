# bootstrap

Things Terraform needs before it can run. Done once, by a human with admin rights.

## 1. AWS: Terraform state bucket

```bash
export AWS_PROFILE=<admin-sso-profile>
cd bootstrap/aws
terraform init && terraform apply                     # local state first
cp backend.hcl.example backend.hcl                    # fill in bucket + region
# uncomment the backend "s3" block in versions.tf, then:
terraform init -backend-config=backend.hcl -migrate-state
rm -f terraform.tfstate terraform.tfstate.backup      # local copy no longer needed
```

## 2. Snowflake: `TERRAFORM_SVC`

```bash
mkdir -p ~/.snowflake/keys && cd ~/.snowflake/keys
openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out terraform_svc.p8 -nocrypt
openssl rsa -in terraform_svc.p8 -pubout -out terraform_svc.pub && chmod 600 terraform_svc.p8
PUBKEY=$(grep -v -- '-----' terraform_svc.pub | tr -d '\n')

snow sql --role ACCOUNTADMIN -f bootstrap/snowflake/terraform_svc.sql -D "pubkey=$PUBKEY"

snow connection add --connection-name terraform_svc --account <org-account> \
  --user TERRAFORM_SVC --role SYSADMIN --authenticator SNOWFLAKE_JWT \
  --private-key-file ~/.snowflake/keys/terraform_svc.p8 --no-interactive
snow connection test -c terraform_svc
```
