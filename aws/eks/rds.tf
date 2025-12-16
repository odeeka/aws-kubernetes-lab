
# Create RDS Subnet Group using the private subnets
resource "aws_db_subnet_group" "rds" {
  name       = "rds-default-vpc-private-subnets"
  subnet_ids = [for s in aws_subnet.private : s.id]
}

resource "aws_security_group" "rds_sg" {
  name   = "rdsdemo-private-sg"
  vpc_id = data.aws_vpc.default.id

  dynamic "ingress" {
    for_each = [
      { port = 5432, name = "postgres" },
      { port = 3306, name = "mysql" }
    ]
    content {
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = "tcp"
      cidr_blocks = [data.aws_vpc.default.cidr_block]
      description = "Allow ${ingress.value.name} from VPC"
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "rdsdemo-private-sg" }
}

module "rds" {
  count = local.rds_enabled ? 1 : 0

  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.13.1"

  identifier = local.rds_name
  # All available versions: http://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_MySQL.html#MySQL.Concepts.VersionMgmt
  # engine               = "mysql"
  # engine_version       = "8.0.42"
  # family               = "mysql8.0" # DB parameter group
  # major_engine_version = "8.0"      # DB option group

  # engine         = "aurora-postgresql"
  # engine_version = "13.23"
  # family               = "aurora-postgresql13" # DB parameter group
  # major_engine_version = "13"         # DB option group

  engine               = "postgres"
  engine_version       = "15.15"
  family               = "postgres15" # DB parameter group
  major_engine_version = "15"         # DB option group

  instance_class    = "db.t3.micro"
  storage_encrypted = false

  skip_final_snapshot = true # Need because the destroy failed (snapshot already exists)

  allocated_storage     = 20
  max_allocated_storage = 100

  db_name                     = "student"
  username                    = var.rds_username
  password                    = var.rds_password
  manage_master_user_password = false
  port                        = 5432 # Mysql:3306

  multi_az               = false
  db_subnet_group_name   = aws_db_subnet_group.rds.name
  publicly_accessible    = false
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
}
