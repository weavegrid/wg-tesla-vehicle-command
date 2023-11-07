#TODO: fix remote state stuff
#TODO: need peer, or just hack the route53 stuff in
resource "aws_lb" "tesla_http_proxy_lb" {
  name               = "tesla-http-proxy-lb-${var.stack}"
  internal           = true
  load_balancer_type = "application"
  security_groups = [
    data.terraform_remote_state.secrets_proxy.outputs.security_groups.vpc_internal.id,
  ]
  subnets = [
    for subnet in data.terraform_remote_state.secrets_proxy.outputs.network.private_subnets : subnet.id
  ]
  idle_timeout = 2000

  tags = {
    Stack = var.stack
  }
}

resource "aws_lb_target_group" "tesla_http_proxy_target" {
  name        = "tesla-http-proxy-ecs-target-${var.stack}"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = data.terraform_remote_state.secrets_proxy.outputs.network.vpc.id
}

resource "aws_lb_listener" "vsp_lb_listener" {
  load_balancer_arn = aws_lb.tesla_http_proxy_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tesla_http_proxy_target.arn
  }
}

data "aws_route53_zone" "wg_dev" {
  provider = aws.peer
  name     = "weave-grid-dev.com"
}

resource "aws_route53_record" "tesla_http_proxy_dns" {
  provider = aws.peer
  zone_id  = data.aws_route53_zone.wg_dev.zone_id
  name     = "tesla-vehicle-proxy-${var.stack}"
  type     = "CNAME"
  ttl      = 300
  records = [
    aws_lb.tesla_http_proxy_lb.dns_name,
  ]
}
