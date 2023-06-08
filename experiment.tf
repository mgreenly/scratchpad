terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

}

provider "aws" {
  region  = "us-east-2"
  profile = "RootAdministrator"
}

resource "aws_s3_bucket" "tf_bucket" {
  bucket = "tf.root.metaspot.org"
}

resource "aws_dynamodb_table" "tf_dynamo_table" {
  name = "tf.root.metaspot.org"
  hash_key = "LockID"
  read_capacity = 20     # what's the minimum values for read/write?
  write_capacity = 20

  attribute {
    name = "LockID"
    type = "S"
  }
}

#
#   creates the following OU structure, where root, workload, test and prod are OUs and
#   the accouts are; example and test
#
#   root
#    |
#    +---work
#          +
#          |
#          +---- test
#          |       |
#          |       +--- example
#          |       |
#          |       +--- demo
#          |
#          +---- prod
#                  |
#                  +--- example
#                  |
#                  +--- demo
#

#
# root ou
#
data "aws_organizations_organization" "org" {}

data "aws_organizations_organizational_units" "ou" {
  parent_id = data.aws_organizations_organization.org.roots[0].id
}

#
# the top level 'workload' ou
#
resource "aws_organizations_organizational_unit" "workload" {
  name      = "workload"
  parent_id = data.aws_organizations_organization.org.roots[0].id
}

#
# test ou and test accounts
#
resource "aws_organizations_organizational_unit" "test" {
  name      = "test"
  parent_id = aws_organizations_organizational_unit.workload.id
}

resource "aws_organizations_account" "sample_test" {
  parent_id = aws_organizations_organizational_unit.test.id
  name  = "sample"
  email = "mgreenly+aws.test.sample@doe.org"
  close_on_deletion = true
}

resource "aws_organizations_account" "demo_test" {
  parent_id = aws_organizations_organizational_unit.test.id
  name  = "demo"
  email = "mgreenly+aws.test.demo@doe.org"
  close_on_deletion = true
}

#
# prod ou and the prod accounts
#
resource "aws_organizations_organizational_unit" "prod" {
  name      = "prod"
  parent_id = aws_organizations_organizational_unit.workload.id
}

resource "aws_organizations_account" "sample_prod" {
  parent_id = aws_organizations_organizational_unit.prod.id
  name  = "sample"
  email = "mgreenly+aws.prod.sample@doe.org"
  close_on_deletion = true
}

resource "aws_organizations_account" "demo_prod" {
  parent_id = aws_organizations_organizational_unit.prod.id
  name  = "demo3"
  email = "mgreenly+aws.prod.demo3@doe.org"
  close_on_deletion = true
}

#
# pilot portfolio and its shares
#
resource "aws_servicecatalog_portfolio" "pilot" {
  name          = "Pilot"
  description   = "Stuff NOT ready for pod"
  provider_name = "WhoWhat"
}

resource "aws_servicecatalog_portfolio_share" "pilot_test" {
  type         = "ORGANIZATIONAL_UNIT"
  principal_id = aws_organizations_organizational_unit.test.arn
  portfolio_id = aws_servicecatalog_portfolio.pilot.id
}

resource "aws_servicecatalog_portfolio_share" "pilot_prod" {
  type         = "ORGANIZATIONAL_UNIT"
  principal_id = aws_organizations_organizational_unit.prod.arn
  portfolio_id = aws_servicecatalog_portfolio.pilot.id
  share_principals = true
}

#
# workload portfolio and its shares
#
resource "aws_servicecatalog_portfolio" "workload" {
  name          = "Workload"
  description   = "Stuff ready for prod"
  provider_name = "WhoWhat"
}

resource "aws_servicecatalog_portfolio_share" "workload_test" {
  type         = "ORGANIZATIONAL_UNIT"
  principal_id = aws_organizations_organizational_unit.test.arn
  portfolio_id = aws_servicecatalog_portfolio.workload.id
}

resource "aws_servicecatalog_portfolio_share" "workload_prod" {
  type         = "ORGANIZATIONAL_UNIT"
  principal_id = aws_organizations_organizational_unit.prod.arn
  portfolio_id = aws_servicecatalog_portfolio.workload.id
}

#
# service catalog products and associations
#
resource "aws_servicecatalog_product" "example" {
  name  = "example42"
  owner = "foobart"
  type  = "CLOUD_FORMATION_TEMPLATE"

  provisioning_artifact_parameters {
    name         = "Exmaple Product 42"
    description  = "An example product to include in portfolios."
    type         = "CLOUD_FORMATION_TEMPLATE"
    template_url = "https://s3.us-west-2.amazonaws.com/cloudformation-templates-us-west-2/S3_Website_Bucket_With_Retain_On_Delete.template"
  }
}

resource "aws_servicecatalog_product_portfolio_association" "pilot_example" {
  portfolio_id = aws_servicecatalog_portfolio.pilot.id
  product_id   = aws_servicecatalog_product.example.id
}

resource "aws_servicecatalog_product_portfolio_association" "workload_example" {
  portfolio_id = aws_servicecatalog_portfolio.workload.id
  product_id   = aws_servicecatalog_product.example.id
}


#
# some experiemnts
#

locals {
 accounts_test = { for account in aws_organizations_organizational_unit.test.accounts : account.name => account.id }
}

output "accounts_test" {
  value =  local.accounts_test
}

output "demo_account" {
  value =  lookup(local.accounts_test, "demo")
}

output "account_keys" {
  value = keys(aws_organizations_organizational_unit.test.accounts[0])
}
