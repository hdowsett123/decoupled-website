#iam
resource "aws_iam_policy" "api_gw-policy" {
  name = "api_gw_s3"

  policy = <<-EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:Get*",
                "s3:Put*"
             ],
            "Resource": "*"
        }
    ]
}
EOF
}

resource "aws_iam_policy" "dynamo-policy" {
  name = "dynamodb_lambda"

  policy = <<-EOF
{
  "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
              "dynamodb:BatchGetItem",
              "dynamodb:GetItem",
              "dynamodb:Scan",
              "dynamodb:Query",
              "dynamodb:BatchWriteItem",
              "dynamodb:PutItem",
              "dynamodb:UpdateItem",
              "dynamodb:DeleteItem"
            ],
            "Resource": "arn:aws:dynamodb:us-east-1:660129909495:table/cloud-resume-challenge"
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "dynamodb-attach" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.dynamo-policy.arn
}

resource "aws_iam_role" "lambda_exec" {
  name = "resume_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"},
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

#Permisions
resource "aws_lambda_permission" "get_allow_api" {
  statement_id  = "Allowresume-apiInvokation"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get-resume.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.resume-api.execution_arn}/*/*/*"
}

resource "aws_lambda_permission" "put_allow_api" {
  statement_id  = "Allowresume-apiInvokation"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.put-resume.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.put-resume-api.execution_arn}/*/*/*"
}
