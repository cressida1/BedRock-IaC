Based on the provided architecture diagram and configuration details, here's the Terraform code to create the infrastructure:

```hcl
provider "aws" {
  region = "us-west-2"  # Replace with your desired region
}

resource "aws_sqs_queue" "migration_queue" {
  name                        = "migration-queue.fifo"
  fifo_queue                  = true
  content_based_deduplication = true
}

resource "aws_lambda_function" "migration_processor" {
  filename         = "lambda_function.zip"  # Ensure this file exists
  function_name    = "migration-processor"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.12"
  timeout          = 900
  memory_size      = 512

  environment {
    variables = {
      SQS_QUEUE_URL = aws_sqs_queue.migration_queue.url
      DYNAMODB_TABLE = aws_dynamodb_table.migration_table.name
    }
  }
}

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

resource "aws_iam_role" "lambda_role" {
  name = "migration_processor_lambda_role"

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

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  policy_arn = aws_iam_policy.lambda_policy.arn
  role       = aws_iam_role.lambda_role.name
}

resource "aws_iam_policy" "lambda_policy" {
  name = "migration_processor_lambda_policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "dynamodb:PutItem"
        ]
        Resource = [
          aws_sqs_queue.migration_queue.arn,
          aws_dynamodb_table.migration_table.arn
        ]
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

resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.migration_queue.arn
  function_name    = aws_lambda_function.migration_processor.function_name
}

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.migration_processor.function_name}"
  retention_in_days = 14
}
```

This Terraform code creates the following resources:

1. An SQS FIFO queue
2. A Lambda function with the specified configuration
3. A DynamoDB table with the given attributes
4. IAM role and policy for the Lambda function
5. Event source mapping to trigger the Lambda from SQS
6. CloudWatch log group for Lambda logs

Make sure to replace the region in the AWS provider block with your desired region. Also, ensure that you have a `lambda_function.zip` file containing your Lambda code in the same directory as this Terraform configuration.