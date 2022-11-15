variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}
variable "lambda_function_arn" {
  type = list(string)
}
variable "stage_name" {
  type = list(string)
}
variable "domain_name" {
  type    = string
  default = "harrydowsettresume.co.uk"
}
variable "bucket_name" {
  type    = string
  default = "harry-resume-website"
}
variable "cloudfront_price_class" {
  type = string
}
