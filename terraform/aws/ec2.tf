# ---------------------------------------------------------------------------
# CloudTwin — EC2 Docker host (Free Tier: t3.micro)
# Amazon Linux 2023 + Docker + Compose plugin, ready to run the platform
# containers on boot. No ALB — the instance sits in a public subnet with the
# least-privilege app SG (see the PRODUCTION UPGRADE block in main.tf).
# ---------------------------------------------------------------------------

# Latest Amazon Linux 2023 x86_64 AMI (Free Tier eligible).
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "app" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type # t3.micro — Free Tier eligible
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.app.id]
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.app.name

  # Bootstrap Docker + Compose plugin on first boot, then start the daemon.
  user_data = <<-EOF
    #!/bin/bash
    set -euo pipefail

    # Install Docker Engine and the Compose plugin on Amazon Linux 2023
    dnf -y install docker docker-compose-plugin

    # Start Docker now and on every reboot; grant the default user access
    systemctl enable --now docker
    usermod -aG docker ec2-user

    # Sanity check: the daemon must be up before the instance reports healthy
    docker version >/dev/null
    docker compose version >/dev/null
  EOF

  root_block_device {
    volume_size           = 30 # AL2023 default; 30 GB gp3 is Free Tier eligible
    volume_type           = "gp3"
    delete_on_termination = true

    tags = {
      Name = "${var.project_name}-app-root"
    }
  }

  tags = {
    Name = "${var.project_name}-app"
    Role = "docker-host"
  }
}
