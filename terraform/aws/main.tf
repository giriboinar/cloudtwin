# ---------------------------------------------------------------------------
# CloudTwin — networking: VPC, subnets, internet gateway, routing
# FREE TIER ONLY: no NAT gateway (it costs ~$32+/month). Private subnets are
# intentionally created WITHOUT a NAT route — workloads that need outbound
# internet run in the PUBLIC subnets. See the commented PRODUCTION UPGRADE
# block at the bottom for the paid alternative.
# ---------------------------------------------------------------------------

# First two available AZs in the region, e.g. ap-south-1a / ap-south-1b.
data "aws_availability_zones" "available" {
  state = "available"
}

# ---------------------------------------------------------------------------
# VPC
# ---------------------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true # needed so the EC2 instance gets a public DNS name

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# ---------------------------------------------------------------------------
# Public subnets (2 AZs) — instances here get direct internet access via IGW.
# ---------------------------------------------------------------------------
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.${count.index + 1}.0/24" # 10.0.1.0/24, 10.0.2.0/24
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true # instances auto-receive a public IP

  tags = {
    Name = "${var.project_name}-public-${count.index + 1}"
    Type = "public"
  }
}

# ---------------------------------------------------------------------------
# Private subnets (2 AZs) — NO internet egress without a NAT gateway.
# NO NAT ROUTE BY DESIGN: adding a NAT gateway would cost ~$32+/month plus
# data processing fees, breaking the Free Tier rule. Anything that must reach
# the internet (the Docker host) lives in the public subnets instead.
# ---------------------------------------------------------------------------
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 11}.0/24" # 10.0.11.0/24, 10.0.12.0/24
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.project_name}-private-${count.index + 1}"
    Type = "private"
  }
}

# ---------------------------------------------------------------------------
# Internet gateway + public route table
# ---------------------------------------------------------------------------
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ---------------------------------------------------------------------------
# PRODUCTION UPGRADE (costs money — do NOT uncomment on the Free Tier path):
#
#   resource "aws_eip" "nat" {
#     domain = "vpc"
#     tags   = { Name = "${var.project_name}-nat-eip" }
#   }
#
#   resource "aws_nat_gateway" "main" {
#     allocation_id = aws_eip.nat.id
#     subnet_id     = aws_subnet.public[0].id
#     tags          = { Name = "${var.project_name}-nat" }
#   }
#
#   resource "aws_route_table" "private" {
#     vpc_id = aws_vpc.main.id
#     route {
#       cidr_block     = "0.0.0.0/0"
#       nat_gateway_id = aws_nat_gateway.main.id
#     }
#   }
#
# COST NOTE: a NAT gateway is billed per hour (~$0.045/h ≈ $32.85/month) plus
# data processing (~$0.045/GB). Keep it commented out for the Free Tier build.
# ---------------------------------------------------------------------------
