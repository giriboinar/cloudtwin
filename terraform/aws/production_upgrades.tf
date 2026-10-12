# ---------------------------------------------------------------------------
# PRODUCTION UPGRADE (costs money) — everything in this file is COMMENTED OUT.
# These three services are excluded from the Free Tier build on purpose.
# Uncomment and extend only when you are ready to pay for them.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# PRODUCTION UPGRADE 1: Application Load Balancer
# COST NOTE: ~$16.20/month ($0.0225/hour) + LCU (Load Balancer Capacity Unit)
# charges for traffic. Uncomment to terminate TLS, run health checks, and
# scale to multiple instances behind one endpoint.
#
#   resource "aws_lb" "app" {
#     name               = "${var.project_name}-alb"
#     load_balancer_type = "application"
#     security_groups    = [aws_security_group.app.id]
#     subnets            = aws_subnet.public[*].id
#
#     tags = { Name = "${var.project_name}-alb" }
#   }
#
#   resource "aws_lb_target_group" "app" {
#     name     = "${var.project_name}-tg"
#     port     = 8000
#     protocol = "HTTP"
#     vpc_id   = aws_vpc.main.id
#
#     health_check {
#       path = "/health"
#       port = "8000"
#     }
#   }
#
#   resource "aws_lb_listener" "http" {
#     load_balancer_arn = aws_lb.app.arn
#     port              = 80
#     protocol          = "HTTP"
#
#     default_action {
#       type             = "forward"
#       target_group_arn = aws_lb_target_group.app.arn
#     }
#   }
#
# Then move aws_instance.app into a private subnet, enable the NAT gateway in
# main.tf, and tighten the app SG so port 8000 accepts traffic from the ALB
# security group only.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# PRODUCTION UPGRADE 2: RDS (managed database)
# COST NOTE: db.t3.micro is inside the Free Tier for the first 12 months
# (~$0), then roughly $13-15/month + storage. Uncomment for managed,
# backed-up relational storage instead of running a DB in a container.
#
#   resource "aws_db_subnet_group" "app" {
#     name       = "${var.project_name}-db-subnets"
#     subnet_ids = aws_subnet.private[*].id
#   }
#
#   resource "aws_security_group" "db" {
#     name   = "${var.project_name}-db-sg"
#     vpc_id = aws_vpc.main.id
#
#     # PostgreSQL only from the app security group — never public.
#     ingress {
#       from_port       = 5432
#       to_port         = 5432
#       protocol        = "tcp"
#       security_groups = [aws_security_group.app.id]
#     }
#   }
#
#   resource "aws_db_instance" "app" {
#     identifier             = "${var.project_name}-db"
#     engine                 = "postgres"
#     engine_version         = "16"
#     instance_class         = "db.t3.micro"
#     allocated_storage      = 20
#     db_subnet_group_name   = aws_db_subnet_group.app.name
#     vpc_security_group_ids = [aws_security_group.db.id]
#     skip_final_snapshot    = true
#
#     # Never hardcode credentials: use a generated password stored in
#     # Secrets Manager (also costs money — ~$0.40/secret/month).
#   }
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# PRODUCTION UPGRADE 3: Route 53 hosted zone (DNS)
# COST NOTE: $0.50/month per hosted zone + $0.40 per million queries.
# Uncomment to give the ALB a real domain name with health-checked routing.
#
#   resource "aws_route53_zone" "app" {
#     name = "app.example.com" # replace with your real domain
#   }
#
#   resource "aws_route53_record" "app" {
#     zone_id = aws_route53_zone.app.zone_id
#     name    = "app.example.com"
#     type    = "A"
#
#     alias {
#       name                   = aws_lb.app.dns_name
#       zone_id                = aws_lb.app.zone_id
#       evaluate_target_health = true
#     }
#   }
#
# Delegate the domain to these name servers at your registrar to go live.
# ---------------------------------------------------------------------------
