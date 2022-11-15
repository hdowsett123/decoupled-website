#Backend
terraform {
  backend "s3" {
    bucket         = "terraform-state-static-website"
    key            = "global/s3/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform_state_locking"
    encrypt        = true
  }
}
#VPC
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name           = "static_website_vpc"
  cidr           = "10.0.0.0/16"
  azs            = ["us-east-1a"]
  public_subnets = ["10.0.101.0/24"]

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

#Cloudfront
module "cdn" {
  source = "terraform-aws-modules/cloudfront/aws"

  aliases = ["*.${var.domain_name}"]

  comment             = "Static website CloudFront"
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  price_class         = var.cloudfront_price_class

  create_origin_access_identity = true
  origin_access_identities = {
    s3_bucket_one = "local.s3_origin_id"
  }

  logging_config = {
    include_cookies = false
    bucket          = "${var.bucket_name}.s3.amazonaws.com"
  }

  origin = {
    something = {
      domain_name = "${var.bucket_name}.s3.amazonaws.com"
      origin_id   = local.s3_origin_id
    }

    s3_one = {
      domain_name = "${var.bucket_name}.s3.amazonaws.com"
      s3_origin_config = {
        origin_access_identity = "s3_bucket_one"
      }
    }
  }

  default_cache_behavior = {
    target_origin_id       = local.s3_origin_id
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods  = ["GET", "HEAD"]
    query_string    = false
    forward         = "none"
    min_ttl         = 0
    default_ttl     = 3600
    max_ttl         = 86400
  }


  viewer_certificate = {
    acm_certificate_arn = aws_acm_certificate.harry-dowsett-resume.arn
    ssl_support_method  = "sni-only"
  }
}

#Route53
resource "aws_acm_certificate" "harry-dowsett-resume" {
  domain_name       = "*.${var.domain_name}"
  validation_method = "DNS"

  tags = {
    Environment = "test"
  }

  lifecycle {
    create_before_destroy = true
  }
}

module "zones" {
  source  = "terraform-aws-modules/route53/aws//modules/zones"
  version = "~> 2.0"

  zones = {
    "harrydowsettresume.co.uk" = {
      comment = "harrydowsettresume.co.uk (production)"
      tags = {
        env = "production"
      }
    }

  }

  tags = {
    ManagedBy = "Terraform"
  }
}

module "records" {
  source  = "terraform-aws-modules/route53/aws//modules/records"
  version = "~> 2.0"

  zone_name = keys(module.zones.route53_zone_zone_id)[0]

  records = [
    {
      name = "www"
      type = "A"
      alias = {
        name                   = module.cdn.cloudfront_distribution_domain_name
        zone_id                = module.cdn.cloudfront_distribution_hosted_zone_id
        evaluate_target_health = true
      }
    },
  ]

  depends_on = [module.zones]
}

#S3
resource "aws_s3_bucket" "resume-website" {
  bucket        = var.bucket_name
  acl           = "private"
  force_destroy = true

  website {
    index_document = "index.html"
    error_document = "error.html"
  }

  policy = <<EOF
{
  "Version" : "2012-10-17",
  "Statement" : [
    {
      "Sid" : "AddPerm",
      "Effect" : "Allow",
      "Principal" : "*",
      "Action" : ["s3:GetObject"],
      "Resource" : ["arn:aws:s3:::${var.bucket_name}/*"]
    }
  ]
}
  EOF
}

locals {
  s3_origin_id = "myS3Origin"
}


resource "aws_s3_bucket_object" "index_html" {
  bucket       = var.bucket_name
  key          = "index.html"
  source       = "./files/index.html"
  content_type = "text/html"

  etag = filemd5("./files/index.html")
}

resource "aws_s3_bucket_object" "index_css" {
  bucket       = var.bucket_name
  key          = "index.css"
  source       = "./files/index.css"
  content_type = "text/css"

  etag = filemd5("./files/index.css")
}

resource "aws_s3_bucket_object" "error_html" {
  bucket       = var.bucket_name
  key          = "error.html"
  source       = "./files/error.html"
  content_type = "text/html"

  etag = filemd5("./files/error.html")
}

resource "aws_s3_bucket_object" "put-function" {
  bucket       = var.bucket_name
  key          = "put-function.zip"
  source       = "./put-function.zip"
  content_type = "zip"

  etag = filemd5("./put-function.zip")
}

resource "aws_s3_bucket_object" "get-function" {
  bucket       = var.bucket_name
  key          = "get-function.zip"
  source       = "./get-function.zip"
  content_type = "zip"

  etag = filemd5("./get-function.zip")
}

#DynamoDB
resource "aws_dynamodb_table_item" "item" {
  table_name = aws_dynamodb_table.harry-resume-database.name
  hash_key   = aws_dynamodb_table.harry-resume-database.hash_key

  item = <<ITEM
{
  "ID": {"S": "Count"},
  "Visitors": {"N": "0"}
}
ITEM
}

resource "aws_dynamodb_table" "harry-resume-database" {
  name         = "cloud-resume-challenge"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "ID"

  attribute {
    name = "ID"
    type = "S"
  }

}

#Lambda
resource "aws_lambda_function" "put-resume" {
  function_name = "ResumePut"
  s3_bucket     = "harry-resume-website"
  s3_key        = "put-function.zip"

  handler = "put-function.lambda_handler"
  runtime = "python3.9"

  role = aws_iam_role.lambda_exec.arn
}

resource "aws_lambda_function" "get-resume" {
  function_name = "ResumeGet"

  s3_bucket = "harry-resume-website"
  s3_key    = "get-function.zip"

  handler = "get-function.lambda_handler"
  runtime = "python3.9"

  role = aws_iam_role.lambda_exec.arn
}

#API GW
resource "aws_api_gateway_rest_api" "resume-api" {
  name = "ResumeAPI"
  endpoint_configuration {
    types = ["EDGE"]
  }
}

resource "aws_api_gateway_resource" "counter" {
  rest_api_id = aws_api_gateway_rest_api.resume-api.id
  parent_id   = aws_api_gateway_rest_api.resume-api.root_resource_id
  path_part   = "counter"
}

resource "aws_api_gateway_method" "counter_post" {
  rest_api_id   = aws_api_gateway_rest_api.resume-api.id
  resource_id   = aws_api_gateway_resource.counter.id
  http_method   = "POST"
  authorization = "NONE"
}

#Get
resource "aws_api_gateway_integration" "get-lambda" {
  rest_api_id = aws_api_gateway_rest_api.resume-api.id
  resource_id = aws_api_gateway_resource.counter.id
  http_method = aws_api_gateway_method.counter_post.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.get-resume.invoke_arn
}

resource "aws_api_gateway_method" "get-proxy_root" {
  rest_api_id   = aws_api_gateway_rest_api.resume-api.id
  resource_id   = aws_api_gateway_resource.counter.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "get-lambda_root" {
  rest_api_id = aws_api_gateway_rest_api.resume-api.id
  resource_id = aws_api_gateway_resource.counter.id
  http_method = aws_api_gateway_method.get-proxy_root.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.get-resume.invoke_arn
}

resource "aws_api_gateway_deployment" "get-deploy" {
  depends_on = [
    "aws_api_gateway_integration.get-lambda",
    "aws_api_gateway_integration.get-lambda_root",
  ]

  rest_api_id = aws_api_gateway_rest_api.resume-api.id
}

resource "aws_api_gateway_stage" "get-function" {
  deployment_id = aws_api_gateway_deployment.get-deploy.id
  rest_api_id   = aws_api_gateway_rest_api.resume-api.id
  stage_name    = "Get-Function"
}


#Put
resource "aws_api_gateway_rest_api" "put-resume-api" {
  name = "Put-ResumeAPI"
  endpoint_configuration {
    types = ["EDGE"]
  }
}

resource "aws_api_gateway_resource" "put-counter" {
  rest_api_id = aws_api_gateway_rest_api.put-resume-api.id
  parent_id   = aws_api_gateway_rest_api.put-resume-api.root_resource_id
  path_part   = "counter"
}

resource "aws_api_gateway_method" "put_counter_post" {
  rest_api_id   = aws_api_gateway_rest_api.put-resume-api.id
  resource_id   = aws_api_gateway_resource.put-counter.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "put-lambda" {
  rest_api_id = aws_api_gateway_rest_api.put-resume-api.id
  resource_id = aws_api_gateway_resource.put-counter.id
  http_method = aws_api_gateway_method.put_counter_post.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.put-resume.invoke_arn
}

resource "aws_api_gateway_method" "put-proxy_root" {
  rest_api_id   = aws_api_gateway_rest_api.put-resume-api.id
  resource_id   = aws_api_gateway_resource.put-counter.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "put-lambda_root" {
  rest_api_id = aws_api_gateway_rest_api.put-resume-api.id
  resource_id = aws_api_gateway_resource.put-counter.id
  http_method = aws_api_gateway_method.put-proxy_root.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.put-resume.invoke_arn
}



resource "aws_api_gateway_deployment" "put-deploy" {
  depends_on = [
    "aws_api_gateway_integration.put-lambda",
    "aws_api_gateway_integration.put-lambda_root",
  ]

  rest_api_id = aws_api_gateway_rest_api.put-resume-api.id
}

resource "aws_api_gateway_stage" "put-function" {
  deployment_id = aws_api_gateway_deployment.put-deploy.id
  rest_api_id   = aws_api_gateway_rest_api.put-resume-api.id
  stage_name    = "Put-Function"
}

