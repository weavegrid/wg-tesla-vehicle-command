data "aws_secretsmanager_secret" "tesla_http_proxy_env_secret" {
  name = "tesla-http-proxy-task-environment"
}

data "aws_secretsmanager_secret_version" "tesla_http_proxy_env_secret" {
  secret_id = data.aws_secretsmanager_secret.tesla_http_proxy_env_secret.id
}

locals {
  env_data = jsondecode(data.aws_secretsmanager_secret_version.tesla_http_proxy_env_secret.secret_string)
}

resource "aws_ecs_task_definition" "tesla_http_proxy_task" {
  family                   = "tesla-http-proxy-task-${var.stack}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 1024 # 1 vCPU
  memory                   = 2048

  execution_role_arn = data.terraform_remote_state.secrets_proxy.outputs.iam.exec_role

  # TODO: No special role should be fine, ensure this is what happens
  # task_role_arn            = ...

  container_definitions = jsonencode([
    {
      name              = "tesla-http-proxy"
      image             = "${var.image_repo}:${var.image_tag}"
      memoryReservation = 1024
      memory            = 2048
      essential         = true
      portMappings = [
        {
          name          = "tesla-http-proxy"
          containerPort = 8080
          hostPort      = 8080
          protocol      = "http"
        }
      ]
      environment = [
        for key, val in local.env_data : {
          name  = key
          value = val
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-create-group  = "true"
          awslogs-group         = "/ecs/tesla-http-proxy"
          awslogs-region        = "us-west-2"
          awslogs-stream-prefix = "ecs"
        }
      }

      # TODO: Figure out appropriate health check
      healthCheck = {
        command = [
          "CMD",
          "python",
          "-c",
          "import httpx; httpx.get('http://localhost:8080/health').raise_for_status()",
        ]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 10
      }

    },
  ])

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
}
