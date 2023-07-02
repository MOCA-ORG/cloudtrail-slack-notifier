data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

locals {
  project_root          = "${path.module}/../"
  lambda_src_path       = "${path.module}/lambda/"
  lambda_zip_local_path = "${path.module}/../../tmp/lambda.zip"
}

resource "aws_cloudtrail" "slack_notifier" {
  name                          = "slack_notifier"
  s3_bucket_name                = aws_s3_bucket.slack_notifier.id
  include_global_service_events = true
  is_multi_region_trail         = true

  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }
}

resource "aws_s3_bucket" "slack_notifier" {
  bucket        = "${var.ORG_NAME}-cloudtrail-slack-notifier"
  force_destroy = true
}

data "aws_iam_policy_document" "allow_cloudtrail_write_to_s3" {
  statement {
    sid    = "AWSCloudTrailAclCheck"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.slack_notifier.arn]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [
        "arn:aws:cloudtrail:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:trail/slack_notifier"
      ]
    }
  }

  statement {
    sid    = "AWSCloudTrailWrite"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.slack_notifier.arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [
        "arn:aws:cloudtrail:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:trail/slack_notifier"
      ]
    }
  }
}

resource "aws_s3_bucket_policy" "allow_cloudtrail_write_to_s3" {
  bucket = aws_s3_bucket.slack_notifier.id
  policy = data.aws_iam_policy_document.allow_cloudtrail_write_to_s3.json
}

resource "aws_cloudwatch_log_group" "slack_notifier" {
    name              = "/aws/lambda/${var.ORG_NAME}-cloudtrail-slack-notifier"
    retention_in_days = 7
}

data "aws_iam_policy_document" "allow_lambda_read_from_s3" {
  statement {
    sid       = "AllowReadFromS3"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.slack_notifier.arn}/*"]
  }
}

data "aws_iam_policy_document" "allow_lambda_write_logs_to_cloudwatch" {
    statement {
        sid       = "AllowWriteLogsToCloudWatch"
        effect    = "Allow"
        actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        resources = ["${aws_cloudwatch_log_group.slack_notifier.arn}:*"]
    }
}

resource "aws_iam_role" "slack_notifier" {
  name               = "${var.ORG_NAME}-cloudtrail-slack-notifier"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
  inline_policy {
    name   = "allow_lambda_read_from_s3"
    policy = data.aws_iam_policy_document.allow_lambda_read_from_s3.json
  }
  inline_policy {
    name   = "allow_lambda_write_logs_to_cloudwatch"
    policy = data.aws_iam_policy_document.allow_lambda_write_logs_to_cloudwatch.json
  }
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = local.lambda_src_path
  output_path = local.lambda_zip_local_path
  depends_on = [
    null_resource.package_lambda
  ]
}

resource "aws_lambda_function" "slack_notifier" {
  function_name    = "${var.ORG_NAME}-cloudtrail-slack-notifier"
  description      = "Send CloudTrail events to Slack."
  role             = aws_iam_role.slack_notifier.arn
  handler          = "handler.handler"
  runtime          = "nodejs18.x"
  timeout          = 30
  memory_size      = 128
  architectures    = ["x86_64"]
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  environment {
    variables = {
      TRUSTED_IPS = var.TRUSTED_IPS
      SLACK_WEBHOOK_URL = var.SLACK_WEBHOOK_URL
    }
  }
}

resource "null_resource" "package_lambda" {
  triggers = {
    diff = join(",", [
      for file in fileset("./lambda/", "*") : filebase64(join("/", [local.project_root, file]))
    ])
  }

  provisioner "local-exec" {
    command = "npm install"
    working_dir = local.lambda_src_path
  }
}

resource "aws_s3_bucket_notification" "aws-lambda-trigger" {
  bucket = aws_s3_bucket.slack_notifier.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.slack_notifier.arn
    events              = ["s3:ObjectCreated:*"]
  }
}

resource "aws_lambda_permission" "allow_s3_to_invoke_lambda" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.slack_notifier.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.slack_notifier.arn
}
