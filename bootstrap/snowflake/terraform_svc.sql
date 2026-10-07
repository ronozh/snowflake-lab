-- Service user that Terraform authenticates as. Run once as ACCOUNTADMIN:
--   snow sql --role ACCOUNTADMIN -f bootstrap/snowflake/terraform_svc.sql -D "pubkey=<base64 public key>"
--
-- TYPE = SERVICE: no password, no MFA, cannot use the Snowsight UI. Key-pair only.
-- Roles: SYSADMIN (objects), SECURITYADMIN (roles/users/grants),
--        ACCOUNTADMIN (storage integrations, resource monitors -- nothing else can create them).
-- Terraform uses one provider alias per role, so each resource gets the least role it needs.

USE ROLE ACCOUNTADMIN;

CREATE USER IF NOT EXISTS TERRAFORM_SVC
  TYPE = SERVICE
  DEFAULT_ROLE = SYSADMIN
  COMMENT = 'Terraform automation (snowflake-lab). Key-pair auth only.';

ALTER USER TERRAFORM_SVC SET RSA_PUBLIC_KEY = '<% pubkey %>';

GRANT ROLE SYSADMIN      TO USER TERRAFORM_SVC;
GRANT ROLE SECURITYADMIN TO USER TERRAFORM_SVC;
GRANT ROLE ACCOUNTADMIN  TO USER TERRAFORM_SVC;

-- Warehouse for Terraform's own queries (some resources read state via SQL).
-- Bootstrap, not Terraform: the provider needs it before any stack runs.
CREATE WAREHOUSE IF NOT EXISTS TERRAFORM_WH
  WAREHOUSE_SIZE = XSMALL AUTO_SUSPEND = 60 AUTO_RESUME = TRUE INITIALLY_SUSPENDED = TRUE
  COMMENT = 'Terraform automation (snowflake-lab).';
GRANT USAGE ON WAREHOUSE TERRAFORM_WH TO ROLE SYSADMIN;
GRANT USAGE ON WAREHOUSE TERRAFORM_WH TO ROLE SECURITYADMIN;
ALTER USER TERRAFORM_SVC SET DEFAULT_WAREHOUSE = TERRAFORM_WH;
