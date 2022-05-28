// sales 람다
resource "aws_lambda_function" "sale_lambda" {
    filename = "${path.module}/files/sale-lambda.zip"
    function_name = "sale-lambda"
    role = aws_iam_role.iam_for_lambda.arn
    description = "재고확인요청 보내는 람다"
    handler = "sale_handler.handler"

    source_code_hash = data.archive_file.sale_lambda.output_base64sha256

    runtime = "nodejs14.x"

    environment {
      variables = {
        DB_HOST = var.db_host,
          DB_NAME = var.db_name,
          DB_PASSWORD = var.db_pw,
          DB_USER = var.db_user,
          TOPIC_ARN = aws_sns_topic.stock_empty.arn
      }
    }
}

//sales 람다의 리소스가 있는 위치 설정(핸들러 및 모듈들)
data "archive_file" "sale_lambda" {
    type = "zip"

    source_dir = "${path.module}/sale-lambda"
    output_path = "${path.module}/files/sale-lambda.zip"
    output_file_mode = "0666"
}

//모니터링 설정
resource "aws_cloudwatch_log_group" "sale_lambda_cloudwatch" {
    name = "/aws/lambda/${aws_lambda_function.sale_lambda.function_name}"

    retention_in_days = 30
}

//api-gateway-rest-api 만들기
resource "aws_api_gateway_rest_api" "sale_api" {
    name = "sale_api"
}

//api-gateway-리소스
resource "aws_api_gateway_resource" "sale_api" {
  path_part = "send"
  parent_id = aws_api_gateway_rest_api.sale_api.root_resource_id
  rest_api_id = aws_api_gateway_rest_api.sale_api.id
}

//요청 방법 설정
resource "aws_api_gateway_method" "sale_api" {
  rest_api_id = aws_api_gateway_rest_api.sale_api.id
  resource_id = aws_api_gateway_resource.sale_api.id
  http_method = "POST"
  authorization = "NONE"
}


//게이트 웨이 붙이기
resource "aws_api_gateway_integration" "sale_api" {
  rest_api_id = aws_api_gateway_rest_api.sale_api.id
  resource_id = aws_api_gateway_resource.sale_api.id
  http_method = aws_api_gateway_method.sale_api.http_method
  integration_http_method = "POST"
  type = "AWS_PROXY"
  uri = aws_lambda_function.sale_lambda.invoke_arn
}
// 람다 실행 권한
resource "aws_lambda_permission" "sale_api" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.sale_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = "arn:aws:execute-api:ap-northeast-2:<유저 번호>:${aws_api_gateway_rest_api.sale_api.id}/*/${aws_api_gateway_method.sale_api.http_method}${aws_api_gateway_resource.sale_api.path}"
}
resource "aws_api_gateway_deployment" "sale_api" {
  rest_api_id = aws_api_gateway_rest_api.sale_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.sale_api.id,
      aws_api_gateway_method.sale_api.id,
      aws_api_gateway_integration.sale_api.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}
resource "aws_api_gateway_stage" "sale_api" {
  deployment_id = aws_api_gateway_deployment.sale_api.id
  rest_api_id = aws_api_gateway_rest_api.sale_api.id
  stage_name = "sale_api"
}

resource "aws_lambda_function_event_invoke_config" "sale_lambda" {
  function_name = aws_lambda_function.sale_lambda.function_name

  destination_config {
    on_success {
      destination = aws_sns_topic.tf_stock_empty.arn
    }
  }
}



// stock_empty_lambda

resource "aws_lambda_function" "stock_empty_lambda" {
    filename = "${path.module}/files/stock-empty-lambda.zip"
    function_name = "stock-empty-lambda"
    role = aws_iam_role.iam_for_lambda.arn
    handler = "empty_handler.handler"
    description = "재고없음 알림 보내는 람다"
    source_code_hash = data.archive_file.stock_empty_lambda.output_base64sha256

    runtime = "nodejs14.x"

    environment {
        variables = {
            CALLBACKURL = aws_api_gateway_deployment.stock_increase_api.invoke_url
            CALLBACKURLSTAGE = aws_api_gateway_stage.stock_increase_api.stage_name
        }
    }   
}

data "archive_file" "stock_empty_lambda" {
    type = "zip"

    source_dir = "${path.module}/stock-empty-lambda"
    output_path = "${path.module}/files/stock-empty-lambda.zip"
    output_file_mode = "0666"
}

resource "aws_cloudwatch_log_group" "stock_empty_lambda_cloudwatch" {
    name = "/aws/lambda/${aws_lambda_function.stock_empty_lambda.function_name}"

    retention_in_days = 30
}

resource "aws_lambda_permission" "with_sqs" {
    statement_id = "AllowExecutionFromSQS"
    action = "lambda:InvokeFunction"
    function_name = aws_lambda_function.stock_empty_lambda.function_name
    principal = "sqs.amazonaws.com"
    source_arn = aws_sqs_queue.stock_queue.arn
}

resource "aws_lambda_event_source_mapping" "sqs_stock_empty_lambda" {
  event_source_arn = aws_sqs_queue.stock_queue.arn
  function_name = aws_lambda_function.stock_empty_lambda.arn
  enabled = true
  batch_size = 10
}

//stock-increase lambda

resource "aws_lambda_function" "stock_increase_lambda" {
    filename = "${path.module}/files/stock-increase-lambda.zip"
    function_name = "stock-inc-lambda"
    role = aws_iam_role.iam_for_lambda.arn
    handler = "increase_handler.handler"
    description = "입고 알림 람다"
    source_code_hash = data.archive_file.stock_increase_lambda.output_base64sha256

    runtime = "nodejs14.x"
}

data "archive_file" "stock_increase_lambda" {
    type = "zip"

    source_dir = "${path.module}/stock_increase_lambda"
    output_path = "${path.module}/files/stock_increase_lambda.zip"
    output_file_mode = "0666"
}

resource "aws_cloudwatch_log_group" "stock_increase_lambda_cloudwatch" {
    name = "/aws/lambda/${aws_lambda_function.stock_increase_lambda.function_name}"

    retention_in_days = 30
}

resource "aws_api_gateway_rest_api" "stock_increase_api" {
    name = "stock_inc_api"
}

resource "aws_api_gateway_resource" "stock_increase_api" {
  path_part = "send"
  parent_id = aws_api_gateway_rest_api.stock_increase_api.root_resource_id
  rest_api_id = aws_api_gateway_rest_api.stock_increase_api.id
}

resource "aws_api_gateway_method" "stock_increase_api" {
  rest_api_id = aws_api_gateway_rest_api.stock_increase_api.id
  resource_id = aws_api_gateway_resource.stock_increase_api.id
  http_method = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "stock_increase_api" {
  rest_api_id = aws_api_gateway_rest_api.stock_increase_api.id
  resource_id = aws_api_gateway_resource.stock_increase_api.id
  http_method = aws_api_gateway_method.stock_increase_api.http_method
  integration_http_method = "POST"
  type = "AWS_PROXY"
  uri = aws_lambda_function.stock_increase_lambda.invoke_arn
}

resource "aws_lambda_permission" "stock_increase_api" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.stock_increase_lambda.function_name
  principal     = "apigateway.amazonaws.com"

   
  source_arn = "arn:aws:execute-api:ap-northeast-2:694280818671:${aws_api_gateway_rest_api.stock_increase_api.id}/*/${aws_api_gateway_method.stock_increase_api.http_method}${aws_api_gateway_resource.sale_api.path}"
}
resource "aws_api_gateway_deployment" "stock_increase_api" {
  rest_api_id = aws_api_gateway_rest_api.stock_increase_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.stock_increase_api.id,
      aws_api_gateway_method.stock_increase_api.id,
      aws_api_gateway_integration.stock_increase_api.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}
resource "aws_api_gateway_stage" "stock_increase_api" {
  deployment_id = aws_api_gateway_deployment.stock_increase_api.id
  rest_api_id = aws_api_gateway_rest_api.stock_increase_api.id
  stage_name = "stock_increase_api"
}

output "rest_api_url" {
    value = aws_api_gateway_deployment.stock_increase_api.invoke_url
    description = "CALLBACK_URL로 들어갈 stock_inc_lambda 엔드포인트"
}

output "stage_name" {
    value = aws_api_gateway_stage.stock_increase_api.stage_name
}
