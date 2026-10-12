# ---------------------------------------------------------------------------
# CloudTwin — security groups (least privilege)
# Egress is deliberately NOT 0.0.0.0/0 on all ports: the instance needs
# HTTP/HTTPS (package repos, Docker Hub, ECR) and DNS only.
# ---------------------------------------------------------------------------

resource "aws_security_group" "app" {
  name        = "${var.project_name}-app-sg"
  description = "Least-privilege SG for the CloudTwin Docker host."
  vpc_id      = aws_vpc.main.id

  # HTTP — public health checks / future web traffic
  ingress {
    description = "HTTP from the internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS — public secure web traffic
  ingress {
    description = "HTTPS from the internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # App API port — only reachable from inside the VPC (e.g. a future ALB
  # subnet), never exposed to the public internet.
  ingress {
    description = "App API (port 8000) from VPC only"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  # SSH — restricted to var.allowed_ssh_cidr (restrict this to your IP!).
  ingress {
    description = "SSH from allowed_ssh_cidr only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  # Egress: HTTP (package repos, Docker Hub) + HTTPS (ECR, CloudWatch, SSM)
  # only, instead of wide-open 0.0.0.0/0 on all ports.
  egress {
    description = "Outbound HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Outbound HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress: DNS (UDP and TCP port 53) so name resolution keeps working
  # with the restricted HTTP/HTTPS-only rules above.
  egress {
    description = "Outbound DNS (UDP)"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Outbound DNS (TCP)"
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress: NTP (UDP port 123) so chrony can keep the system clock in sync
  egress {
    description = "Outbound NTP (UDP)"
    from_port   = 123
    to_port     = 123
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-app-sg"
  }
}
