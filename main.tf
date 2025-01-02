Here's the Terraform code to create the infrastructure based on the provided architecture diagram and requirements:

```hcl
# Provider configuration
provider "aws" {
  region = "us-west-2"  # Change this to your desired region
}

# SQS Queue
resource "aws_sqs_queue" "migration_queue" {
  name = "migration-queue"
  fifo_queue = false
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
  filename      = "lambda_function.zip"  # Make sure to create this ZIP file with your Lambda code
  function_name = "migration_processor"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.handler"
  runtime       = "python3.12"
  timeout       = 900  # 15 minutes
  memory_size   = 512

  environment {
    variables = {
      SQS_QUEUE_URL = aws_sqs_queue.migration_queue.id
      DYNAMODB_TABLE = aws_dynamodb_table.migration_table.name
    }
  }
}

# Lambda Event Source Mapping
resource "aws_lambda_event_source_mapping" "sqs_lambda_trigger" {
  event_source_arn = aws_sqs_queue.migration_queue.arn
  function_name    = aws_lambda_function.migration_lambda.arn
  batch_size       = 10
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
```

This Terraform code creates the following resources:

1. An SQS queue named "migration-queue"
2. An IAM role and policy for the Lambda function
3. A Lambda function named "migration_processor" with the specified configuration
4. An event source mapping to trigger the Lambda function from the SQS queue
5. A DynamoDB table named "Migration" with the specified attributes and capacity

Make sure to create a ZIP file named "lambda_function.zip" containing your Lambda function code before applying this Terraform configuration. Also, adjust the AWS region in the provider block if needed.