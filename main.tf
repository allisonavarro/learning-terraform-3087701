# 1. Fetch the latest official and free Ubuntu 24.04 AMI
data "aws_ami" "app_ami" {
  most_recent = true
  owners      = ["099720109477"] # Canonical (Official Ubuntu)

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

module "blog_vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "dev"
  cidr = "10.0.0.0/16"

  azs             = ["us-west-2a", "us-west-2b", "us-west-2c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true

  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}

# Deploy Free-Tier EC2 Instance
resource "aws_instance" "blog" {
  ami           = data.aws_ami.app_ami.id
  instance_type = "t3.micro" # Free Tier eligible

  # Attach the Security Group
  vpc_security_group_ids = [
    module.http_80_security_group.id,
    module.tomcat_sg.id
    ]
  # Add subnet 
  subnet_id = module.blog_vpc.public_subnets[0]


  # Automatically install Tomcat 10 on boot
  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update -y
              sudo apt-get install -y tomcat10 tomcat10-admin
              sudo systemctl start tomcat10
              sudo systemctl enable tomcat10
              EOF

  tags = {
    Name = "Tomcat-Free-Tier"
  }
}

module "http_80_security_group" {
  source  = "terraform-aws-modules/security-group/aws//modules/http-80"
  version = "~> 6.0"

  name        = "http-80"
  description = "Security group for http-80"
  vpc_id = module.blog_vpc.vpc_id

  # Opens HTTP (port 80) to the Internet
  ingress_cidr_ipv4 = {
    internet = "0.0.0.0/0"
  }

  # Allow all outbound traffic
  egress_rules = {
    all = {
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
      description = "Allow all outbound traffic"
    }
  }
}

module "tomcat_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 6.0"

  name   = "tomcat-sg"
  vpc_id = module.blog_vpc.vpc_id

  ingress_rules = {
    tomcat = {
      ip_protocol = "tcp"
      from_port   = 8080
      to_port     = 8080
      cidr_ipv4   = "0.0.0.0/0"
    }
  }

  egress_rules = {
    all = {
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }
}

# 4. Output the public URL to easily click and test
output "tomcat_url" {
  value       = "http://${aws_instance.blog.public_ip}:8080"
  description = "The public web address for your Tomcat server"
}

module "blog_alb" {
  source = "terraform-aws-modules/alb/aws"

  name    = "blog-alb"
  vpc_id  = module.blog_vpc.vpc_id
  subnets = module.blog_vpc.public_subnets
  security_groups = [module.tomcat_sg.id]

  listeners = {
    blog-http = {
      port     = 80
      protocol = "HTTP"
      forward = {
        target_group_arn = aws_lb_target_group.blog.arn
      }
    }
  }

  tags = {
    Environment = "dev"
  }
}

resource "aws_lb_target_group" "blog" {
  name     = "blog"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.blog_vpc.vpc_id
}

resource "aws_lb_target_group_attachment" "blog" {
  target_group_arn = aws_lb_target_group.blog.arn
  target_id        = aws_instance.blog.id
  port             = 80
}