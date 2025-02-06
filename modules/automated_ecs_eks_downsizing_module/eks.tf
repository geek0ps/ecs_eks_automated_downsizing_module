
# EKS Lambda Functions
resource "aws_lambda_function" "eks_scale_down" {
  count = var.enable_eks ? 1 : 0

  function_name    = "eks-scale-down"
  role             = aws_iam_role.scheduler.arn
  runtime          = "python3.9"
  handler          = "eks_scale_down.lambda_handler"
  timeout          = 300
  memory_size      = 256
  filename         = data.archive_file.eks_scale_down[0].output_path
  source_code_hash = data.archive_file.eks_scale_down[0].output_base64sha256

  environment {
    variables = {
      CLUSTER_NAMES    = join(",", var.eks_cluster_names)
      CONFIG_TABLE     = local.config_table_name
    }
  }
}

resource "aws_lambda_function" "eks_scale_up" {
  count = var.enable_eks ? 1 : 0

  function_name    = "eks-scale-up"
  role             = aws_iam_role.scheduler.arn
  runtime          = "python3.9"
  handler          = "eks_scale_up.lambda_handler"
  timeout          = 300
  memory_size      = 256
  filename         = data.archive_file.eks_scale_up[0].output_path
  source_code_hash = data.archive_file.eks_scale_up[0].output_base64sha256

  environment {
    variables = {
      CONFIG_TABLE = local.config_table_name
    }
  }
}


# Lambda Permissions
resource "aws_lambda_permission" "eks_scale_down" {
  count = var.enable_eks ? 1 : 0

  statement_id  = "AllowExecutionFromCloudWatchEKSDown"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.eks_scale_down[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.scale_down.arn
}

resource "aws_lambda_permission" "eks_scale_up" {
  count = var.enable_eks ? 1 : 0

  statement_id  = "AllowExecutionFromCloudWatchEKSUp"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.eks_scale_up[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.scale_up.arn
}


# Event Targets
resource "aws_cloudwatch_event_target" "eks_scale_down" {
  count = var.enable_eks ? 1 : 0

  rule      = aws_cloudwatch_event_rule.scale_down.name
  target_id = "eks-scale-down-target"
  arn       = aws_lambda_function.eks_scale_down[0].arn
}

resource "aws_cloudwatch_event_target" "eks_scale_up" {
  count = var.enable_eks ? 1 : 0

  rule      = aws_cloudwatch_event_rule.scale_up.name
  target_id = "eks-scale-up-target"
  arn       = aws_lambda_function.eks_scale_up[0].arn
}