# One shared ALB for all five CMST services, routed by path prefix
# (/kyc/*, /circles/*, /lending/*, /arbitration/*, /payments/*).
# See docs/adr/0005-shared-alb-path-routing.md for why this replaced
# one-ALB-per-service.

resource "aws_lb" "this" {
  name               = "${var.project}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnet_ids
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port               = 80
  protocol           = "HTTP"

  # No service matches an unrecognised path -> explicit 404 instead of routing
  # to whichever service happened to register first.
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "No CMST service registered at this path."
      status_code  = "404"
    }
  }

  # In production: listen on 443 with an ACM cert and redirect 80 -> 443.
  # Omitted here to keep the demo certificate-free.
}
