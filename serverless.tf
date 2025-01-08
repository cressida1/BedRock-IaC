Here's the Terraform code to create the infrastructure based on the architecture diagram and specifications you provided:

```hcl
provider "aws" {
  region = "us-west-2"  # Replace with your desired region
}

# SQS FIFO Queue
resource "aws_sqs_queue" "migration_queue" {
  name                        = "migration-queue.fifo"
  fifo_queue                  = true
  content_based_deduplication = true
}

# DynamoDB Table
resource "aws_dynamodb_table" "migration_table" {
  name           = "Migration"
  billing_mode   = "PROVISIONED"
  read_capacity  = 10
  write_capacity = 30
  hash_key       = "MigrationId"
  range_key      = "Entity"

  attribute {
    name = "MigrationId"
    type = "S"
  }

  attribute {
    name = "Entity"
    type = "S"
  }
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "migration_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for Lambda
resource "aws_iam_role_policy" "lambda_policy" {
  name = "migration_lambda_policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.migration_queue.arn
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem"
        ]
        Resource = aws_dynamodb_table.migration_table.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Lambda Function
resource "aws_lambda_function" "migration_lambda" {
  filename      = "lambda_function.zip"  # Replace with your Lambda function code
  function_name = "migration_processor"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.handler"
  runtime       = "python3.12"
  timeout       = 900  # 15 minutes
  memory_size   = 512

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.migration_table.name
    }
  }
}

# Lambda Event Source Mapping
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.migration_queue.arn
  function_name    = aws_lambda_function.migration_lambda.arn
  batch_size       = 10
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.migration_lambda.function_name}"
  retention_in_days = 14
}
```

This Terraform script creates all the necessary resources as specified:

1. A FIFO SQS queue
2. An AWS Lambda function with the specified runtime, timeout, and memory, triggered by SQS messages
3. A DynamoDB table with the specified configuration
4. IAM role and policy for the Lambda function with permissions to read from SQS and write to DynamoDB
5. CloudWatch logging for the Lambda function

Note: You'll need to provide the Lambda function code in a file named `lambda_function.zip` in the same directory as this Terraform script. The Lambda function should have a handler named `lambda_function.handler`.