# UPDATED
resource "aws_ecs_service" "tesla_http_proxy_service" {
  name            = "tesla-http-proxy-service"
  cluster         = data.terraform_remote_state.secrets_proxy.outputs.ecs.cluster.id
  task_definition = aws_ecs_task_definition.tesla_http_proxy_task.id
  desired_count   = var.replica_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets = [
      for subnet in data.terraform_remote_state.secrets_proxy.outputs.network.private_subnets : subnet.id
    ]
    security_groups = [
      data.terraform_remote_state.secrets_proxy.outputs.security_groups.vpc_internal.id
    ]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.tesla_http_proxy_target.arn
    container_name   = "tesla-http-proxy"
    container_port   = 8080
  }
}
