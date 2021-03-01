provider "aws" {
  region = var.REGION
}

resource "aws_sns_topic" "topic" {
  name            = var.SNS_TOPIC_NAME
  delivery_policy = <<EOF
{
  "http": {
    "defaultHealthyRetryPolicy": {
      "minDelayTarget": 20,
      "maxDelayTarget": 20,
      "numRetries": 3,
      "numMaxDelayRetries": 0,
      "numNoDelayRetries": 0,
      "numMinDelayRetries": 0,
      "backoffFunction": "linear"
    },
    "disableSubscriptionOverrides": false,
    "defaultThrottlePolicy": {
      "maxReceivesPerSecond": 1
    }
  }
}
EOF
}


resource "aws_iam_role" "iam_for_lambda" {
  depends_on         = [aws_sns_topic.topic]
  name               = "iam_for_lambda"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}


resource local_file indexjs {

  depends_on = [aws_sns_topic.topic]

  content  = data.template_file.indexjs.rendered
  filename = format("%s/%s", var.CONFIG_DIR, var.INDEXJS)
}


data "archive_file" "lambda_zip" {
  depends_on   = [local_file.indexjs]
  type         = "zip"
  source_dir   = "function"
  output_path  = "lambda_function.zip"
}

resource "aws_lambda_function" "helloworld" {
  depends_on       = [local_file.indexjs]
  filename         = "lambda_function.zip"
  function_name    = var.LAMBDA_FUNCTION_NAME
  role             = aws_iam_role.iam_for_lambda.arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "nodejs12.x"

  vpc_config {
    subnet_ids         = module.cluster.private_subnet_ids
    security_group_ids = [module.cluster.node_security_group_id]
  }

}

resource "aws_cloudwatch_log_group" "helloworld" {
  depends_on        = [aws_sns_topic.topic]
  name              = "/aws/lambda/${var.LAMBDA_FUNCTION_NAME}"
  retention_in_days = 14
}

# See also the following AWS managed policy: AWSLambdaBasicExecutionRole
resource "aws_iam_policy" "lambda_logging" {
  depends_on  = [aws_sns_topic.topic]
  name        = "helloworld_logging"
  path        = "/"
  description = "IAM policy for logging from a helloworld lambda"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*",
      "Effect": "Allow"
    }
  ]
}
EOF
}
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  depends_on = [aws_sns_topic.topic]
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

resource "aws_iam_policy" "lambda_networking" {
  depends_on  = [aws_sns_topic.topic]
  name        = "helloworld_networking"
  path        = "/"
  description = "IAM policy for networking from a helloworld lambda"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeNetworkInterfaces",
        "ec2:CreateNetworkInterface",
        "ec2:DeleteNetworkInterface",
        "ec2:DescribeInstances",
        "ec2:AttachNetworkInterface"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_network" {
  depends_on = [aws_sns_topic.topic]
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.lambda_networking.arn
}


module cluster {
  source                 = "../module"
  NAME                   = var.NAME
  REGION                 = var.REGION
  VPC_CIDR               = var.VPC_CIDR
  PUBLIC_SUBNET_CIDRS    = var.PUBLIC_SUBNET_CIDRS
  PRIVATE_SUBNET_CIDRS   = var.PRIVATE_SUBNET_CIDRS
  ENDPOINT_PUBLIC_ACCESS = true
  CONFIG_DIR             = var.STATE_DIR
  OWNER_TAG              = var.EKS_OWNER_TAG
  PROJECT_TAG            = var.EKS_PROJECT_TAG
  AZ_COVERAGE            = 2 #Cover 2 different AZ
}
