# UPDATED
resource "aws_ecs_service" "tesla_http_proxy_service" {
  name            = "tesla-http-proxy-service"
  cluster         = data.terraform_remote_state.secrets_proxy.outputs.ecs.cluster.id
  task_definition = aws_ecs_task_definition.tesla_http_proxy_task.id
  desired_count   = var.replica_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets = [
      for subnet in data.terraform_remote_state.secrets_proxy.outputs.vpc.network.private_subnets : subnet.id
    ]
    security_groups = [
      data.terraform_remote_state.secrets_proxy.outputs.vpc.security_groups.internal_ingress.id,
      data.terraform_remote_state.secrets_proxy.outputs.vpc.security_groups.internal_egress.id,
      data.terraform_remote_state.secrets_proxy.outputs.vpc.security_groups.global_egress.id,
    ]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.tesla_http_proxy_target.arn
    container_name   = "tesla-http-proxy"
    container_port   = 8080
  }
}
