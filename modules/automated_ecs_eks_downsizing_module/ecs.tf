# ECS Lambda Functions
resource "aws_lambda_function" "ecs_scale_down" {
  count = var.enable_ecs ? 1 : 0

  function_name    = "ecs-scale-down"
  role             = aws_iam_role.scheduler.arn
  runtime          = "python3.9"
  handler          = "ecs_scale_down.lambda_handler"
  timeout          = 300
  memory_size      = 256
  filename         = data.archive_file.ecs_scale_down[0].output_path
  source_code_hash = data.archive_file.ecs_scale_down[0].output_base64sha256

  environment {
    variables = {
      CLUSTER_NAMES = join(",", var.ecs_cluster_names)
      CONFIG_TABLE     = local.config_table_name
    }
  }
}

resource "aws_lambda_function" "ecs_scale_up" {
  count = var.enable_ecs ? 1 : 0

  function_name    = "ecs-scale-up"
  role             = aws_iam_role.scheduler.arn
  runtime          = "python3.9"
  handler          = "ecs_scale_up.lambda_handler"
  timeout          = 300
  memory_size      = 256
  filename         = data.archive_file.ecs_scale_up[0].output_path
  source_code_hash = data.archive_file.ecs_scale_up[0].output_base64sha256

  environment {
    variables = {
      CLUSTER_NAMES = join(",", var.ecs_cluster_names)
      CONFIG_TABLE     = local.config_table_name
    }
  }
}

# Lambda Permissions
resource "aws_lambda_permission" "ecs_scale_down" {
  count = var.enable_ecs ? 1 : 0

  statement_id  = "AllowExecutionFromCloudWatchECSDown"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ecs_scale_down[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.scale_down.arn
}

resource "aws_lambda_permission" "ecs_scale_up" {
  count = var.enable_ecs ? 1 : 0

  statement_id  = "AllowExecutionFromCloudWatchECSUp"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ecs_scale_up[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.scale_up.arn
}

# Event Targets
resource "aws_cloudwatch_event_target" "ecs_scale_down" {
  count = var.enable_ecs ? 1 : 0

  rule      = aws_cloudwatch_event_rule.scale_down.name
  target_id = "ecs-scale-down-target"
  arn       = aws_lambda_function.ecs_scale_down[0].arn
}

resource "aws_cloudwatch_event_target" "ecs_scale_up" {
  count = var.enable_ecs ? 1 : 0

  rule      = aws_cloudwatch_event_rule.scale_up.name
  target_id = "ecs-scale-up-target"
  arn       = aws_lambda_function.ecs_scale_up[0].arn
}
