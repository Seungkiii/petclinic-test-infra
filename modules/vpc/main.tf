# =============================================================================
# VPC Module
# 고가용성(HA)을 위한 2-Tier Architecture with Zonal Isolation
# =============================================================================

# -----------------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = var.vpc_tags
}

# -----------------------------------------------------------------------------
# Internet Gateway
# -----------------------------------------------------------------------------
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = var.igw_tags
}

# -----------------------------------------------------------------------------
# Public Subnets (2개 - 각 AZ별 1개)
# 용도: Bastion Host, NAT Gateway, ALB
# -----------------------------------------------------------------------------
resource "aws_subnet" "public" {
  count = length(var.availability_zones)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    var.public_subnet_tags,
    {
      Name = "${var.name_prefix}-public-subnet-${count.index + 1}"
    }
  )
}

# -----------------------------------------------------------------------------
# App Private Subnets (2개 - 각 AZ별 1개)
# 용도: Management Server, EKS Nodes, Application Pods
# -----------------------------------------------------------------------------
resource "aws_subnet" "private_app" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.app_private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    var.app_private_subnet_tags,
    {
      Name = "${var.name_prefix}-private-app-subnet-${count.index + 1}"
    }
  )
}

# -----------------------------------------------------------------------------
# DB Private Subnets (2개 - 각 AZ별 1개)
# 용도: RDS, Database
# -----------------------------------------------------------------------------
resource "aws_subnet" "private_db" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.db_private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    var.db_private_subnet_tags,
    {
      Name = "${var.name_prefix}-private-db-subnet-${count.index + 1}"
    }
  )
}

# -----------------------------------------------------------------------------
# Elastic IPs for NAT Gateways (HA - 2개)
# -----------------------------------------------------------------------------
resource "aws_eip" "nat" {
  count  = length(var.availability_zones)
  domain = "vpc"

  tags = merge(
    var.nat_gateway_tags,
    {
      Name = "${var.name_prefix}-nat-eip-${count.index + 1}"
    }
  )

  depends_on = [aws_internet_gateway.main]
}

# -----------------------------------------------------------------------------
# NAT Gateways (HA - 각 Public Subnet에 1개씩, 총 2개)
# Zonal Isolation: 각 AZ의 Private Subnet이 같은 AZ의 NAT Gateway 사용
# -----------------------------------------------------------------------------
resource "aws_nat_gateway" "main" {
  count = length(var.availability_zones)

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(
    var.nat_gateway_tags,
    {
      Name = "${var.name_prefix}-nat-gw-${count.index + 1}"
      AZ   = var.availability_zones[count.index]
    }
  )

  depends_on = [aws_internet_gateway.main]
}

# -----------------------------------------------------------------------------
# Public Route Table (1개 - 모든 Public Subnet 공유)
# -----------------------------------------------------------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(
    var.public_rt_tags,
    {
      Name = "${var.name_prefix}-public-rt"
    }
  )
}

# Public Subnet Route Table Association
resource "aws_route_table_association" "public" {
  count = length(var.availability_zones)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# -----------------------------------------------------------------------------
# App Private Route Tables (2개 - 각 AZ별 1개, Zonal Isolation)
# 각 App Private Subnet이 자신과 같은 AZ에 있는 NAT Gateway를 사용
# -----------------------------------------------------------------------------
resource "aws_route_table" "private_app" {
  count = length(var.availability_zones)

  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = merge(
    var.app_private_rt_tags,
    {
      Name = "${var.name_prefix}-private-app-rt-${count.index + 1}"
      AZ   = var.availability_zones[count.index]
    }
  )
}

# App Private Subnet Route Table Association (Zonal Isolation)
resource "aws_route_table_association" "private_app" {
  count = length(var.availability_zones)

  subnet_id      = aws_subnet.private_app[count.index].id
  route_table_id = aws_route_table.private_app[count.index].id
}

# -----------------------------------------------------------------------------
# DB Private Route Tables (2개 - 각 AZ별 1개, Zonal Isolation)
# DB Private Subnet은 NAT Gateway를 사용하지 않음 (인터넷 접근 불필요)
# 또는 필요시 NAT Gateway 사용 가능
# -----------------------------------------------------------------------------
resource "aws_route_table" "private_db" {
  count = length(var.availability_zones)

  vpc_id = aws_vpc.main.id

  # DB 서브넷은 일반적으로 인터넷 접근이 필요 없지만,
  # 필요시 NAT Gateway를 통해 접근 가능하도록 설정
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = merge(
    var.db_private_rt_tags,
    {
      Name = "${var.name_prefix}-private-db-rt-${count.index + 1}"
      AZ   = var.availability_zones[count.index]
    }
  )
}

# DB Private Subnet Route Table Association (Zonal Isolation)
resource "aws_route_table_association" "private_db" {
  count = length(var.availability_zones)

  subnet_id      = aws_subnet.private_db[count.index].id
  route_table_id = aws_route_table.private_db[count.index].id
}

