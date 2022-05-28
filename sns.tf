resource "aws_sns_topic" "stock_empty" {
  name = "stock_empty"
}

resource "aws_sns_topic_subscription" "stock_empty_sqs_target" {
  topic_arn = "arn:aws:sns:ap-northeast-2:<유저아이디숫자>:stock_empty"
  protocol = "sqs"
  endpoint = "arn:aws:sqs:ap-northeast-2:<유저아이디숫자>:stock_queue"
}

resource "aws_sns_topic_policy" "default" {
  arn = aws_sns_topic.stock_empty.arn

  policy = data.aws_iam_policy_document.sns_topic_policy.json
}

data "aws_iam_policy_document" "sns_topic_policy" {
  policy_id = "__default_policy_ID"

  statement {
    actions = [
      "SNS:Subscribe",
      "SNS:SetTopicAttributes",
      "SNS:RemovePermission",
      "SNS:Receive",
      "SNS:Publish",
      "SNS:ListSubscriptionsByTopic",
      "SNS:GetTopicAttributes",
      "SNS:DeleteTopic",
      "SNS:AddPermission",
    ]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceOwner"

      values = [
        "<유저아이디 숫자>",
      ]
    }

    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    resources = [
      aws_sns_topic.stock_empty.arn,
    ]

    sid = "__default_statement_ID"
  }
}
