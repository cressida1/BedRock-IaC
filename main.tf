Here's the Terraform code to create the infrastructure based on the requirements:

```hcl
# Provider configuration
provider "aws" {
  region = "us-west-2"
}

# Data source for default VPC
data "aws_vpc" "default" {
  default = true
}

# Data source for public subnets
data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "map-public-ip-on-launch"
    values = ["true"]
  }
}

# EKS Cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = "my-eks-cluster"
  cluster_version = "1.27"

  vpc_id     = data.aws_vpc.default.id
  subnet_ids = data.aws_subnets.public.ids

  eks_managed_node_groups = {
    default = {
      min_size     = 1
      max_size     = 1
      desired_size = 1

      instance_types = ["t2.micro"]
      capacity_type  = "ON_DEMAND"
    }
  }

  tags = {
    Environment = "test"
    Project     = "migration"
  }
}

# RDS Oracle
module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 5.0"

  identifier = "my-rds-oracle"

  engine               = "oracle-ee"
  engine_version       = "19.0.0.0.ru-2023-01.rur-2023-01.r1"
  family               = "oracle-ee-19"
  major_engine_version = "19"
  instance_class       = "db.t3.micro"

  allocated_storage     = 20
  max_allocated_storage = 100

  db_name  = "mydb"
  username = "admin"
  port     = 1521

  multi_az               = true
  db_subnet_group_name   = aws_db_subnet_group.default.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  maintenance_window = "Sat:00:00-Sat:03:00"
  backup_window      = "03:00-06:00"

  backup_retention_period = 1
  skip_final_snapshot     = true
  deletion_protection     = false

  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  create_monitoring_role                = true
  monitoring_interval                   = 60

  parameters = [
    {
      name  = "character_set_server"
      value = "utf8mb4"
    },
    {
      name  = "character_set_client"
      value = "utf8mb4"
    }
  ]

  tags = {
    Environment = "test"
    Project     = "migration"
  }
}

# S3 Bucket
module "s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 3.0"

  bucket = "migration-test-987"
  acl    = "private"

  versioning = {
    enabled = true
  }

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  tags = {
    Environment = "test"
    Project     = "migration"
  }
}

# Application Load Balancer
module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 8.0"

  name = "my-alb"

  load_balancer_type = "application"

  vpc_id          = data.aws_vpc.default.id
  subnets         = data.aws_subnets.public.ids
  security_groups = [aws_security_group.alb.id]

  target_groups = [
    {
      name_prefix      = "eks-"
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "ip"
    }
  ]

  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0
    }
  ]

  https_listeners = [
    {
      port               = 443
      protocol           = "HTTPS"
      certificate_arn    = module.acm.acm_certificate_arn
      target_group_index = 0
    }
  ]

  tags = {
    Environment = "test"
    Project     = "migration"
  }
}

# Route 53
module "route53" {
  source  = "terraform-aws-modules/route53/aws"
  version = "~> 2.0"

  zone_name = "test.health.com"

  records = [
    {
      name    = ""
      type    = "A"
      alias   = {
        name    = module.alb.lb_dns_name
        zone_id = module.alb.lb_zone_id
      }
    }
  ]

  tags = {
    Environment = "test"
    Project     = "migration"
  }
}

# ACM Certificate
module "acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "~> 4.0"

  domain_name  = "test.health.com"
  zone_id      = module.route53.route53_zone_zone_id

  validation_method = "DNS"

  tags = {
    Environment = "test"
    Project     = "migration"
  }
}

# CloudWatch
module "cloudwatch" {
  source  = "terraform-aws-modules/cloudwatch/aws"
  version = "~> 3.0"

  create_log_group = true
  log_group_name   = "my-log-group"
  log_group_retention_in_days = 30

  tags = {
    Environment = "test"
    Project     = "migration"
  }
}

# Direct Connect
resource "aws_dx_connection" "example" {
  name      = "my-dx-connection"
  bandwidth = "1Gbps"
  location  = "EqDC2"
}

# Security Groups
resource "aws_security_group" "rds" {
  name_prefix = "rds-"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port = 1521
    to_port   = 1521
    protocol  = "tcp"
    cidr_blocks = [data.aws_vpc.default.cidr_block]
  }
}

resource "aws_security_group" "alb" {
  name_prefix = "alb-"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# DB Subnet Group
resource "aws_db_subnet_group" "default" {
  name       = "my-db-subnet-group"
  subnet_ids = data.aws_subnets.public.ids

  tags = {
    Environment = "test"
    Project     = "migration"
  }
}

# Jenkins (outside AWS)
resource "null_resource" "jenkins" {
  provisioner "local-exec" {
    command = <<-EOT
      cat <<EOF > jenkins_pipeline.groovy
      pipeline {
        agent any
        stages {
          stage('Build') {
            steps {
              sh 'python -m py_compile app.py'
            }
          }
          stage('Deploy') {
            steps {
              sh 'python app.py'
            }
          }
        }
      }
      EOF
    EOT
  }
}

# Splunk (outside AWS)
resource "null_resource" "splunk" {
  provisioner "local-exec" {
    command = "echo 'Splunk configuration with default settings' > splunk_config.txt"
  }
}
```

This Terraform code creates the infrastructure based on the requirements you provided. It uses modules where applicable and follows AWS best practices for security and performance. Note that you'll need to adjust some values (like region, AMI IDs, etc.) to match your specific requirements and environment.

Also, remember that the Jenkins and Splunk resources are represented as `null_resource` with local-exec provisioners, as they are to be deployed outside AWS. In a real-world scenario, you'd typically use separate configuration management tools or infrastructure provisioning tools specific to the environment where Jenkins and Splunk will be deployed.