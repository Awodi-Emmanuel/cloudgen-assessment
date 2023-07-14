# Define the provider
provider "aws" {
  region = "us-east-1" # Change to your desired region
}

# Create a VPC
resource "aws_vpc" "cloudgen_vpc" {
  cidr_block = "10.0.0.0/16"
}

# Create a public subnet
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.cloudgen_vpc.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "us-east-1a" # Change to your desired availability zone
  map_public_ip_on_launch = true
}

# Create a security group for the EC2 instances
resource "aws_security_group" "ec2_security_group" {
  name        = "ec2_security_group"
  description = "Allow inbound HTTP traffic"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create an auto-scaling group
resource "aws_launch_template" "cloudgen_launch_template" {
  image_id        = "ami-053b0d53c279acc90" # Change to your desired AMI
  instance_type   = "t2.micro" # Change to your desired instance type

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 10
    }
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups = [aws_security_group.ec2_security_group.id]
  }

  user_data = <<-EOF
                #!/bin/bash
                echo "Hello World" > index.html
                nohup python -m SimpleHTTPServer 80 &
                EOF
}

resource "aws_autoscaling_group" "cloudgen_autoscaling_group" {
  launch_template {
    id      = aws_launch_template.cloudgen_launch_template.id
    version = "$Latest"
  }
  min_size          = 2
  max_size          = 4
  desired_capacity  = 2
  vpc_zone_identifier = [aws_subnet.public_subnet.id]
}

# Create a load balancer
resource "aws_elb" "cloudgen_elb" {
  name               = "cloudgen-elb"
  subnets            = [aws_subnet.public_subnet.id]
  security_groups    = [aws_security_group.ec2_security_group.id]
  instances          = aws_autoscaling_group.cloudgen_autoscaling_group.id

  listener {
    instance_port     = 80
    instance_protocol = "HTTP"
    lb_port           = 80
    lb_protocol       = "HTTP"
  }

  health_check {
    target              = "HTTP:80/"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
  }
}

# Create an RDS instance
resource "aws_db_instance" "cloudgen_db_instance" {
  engine               = "mysql"
  instance_class       = "db.t2.micro" # Change to your desired instance type
  allocated_storage    = 10
  storage_type         = "gp2"
  username             = "admin"
  password             = "gencloud123_" # Change to your desired password
  db_subnet_group_name = aws_db_subnet_group.cloudgen_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db_security_group.id]
}

# Create a DB subnet group
resource "aws_db_subnet_group" "cloudgen_db_subnet_group" {
  name       = "cloudgen-db-subnet-group"
  subnet_ids = [aws_subnet.public_subnet.id]
}

# Create a security group for the RDS instance
resource "aws_security_group" "db_security_group" {
  name        = "db-security-group"
  description = "Allow inbound MySQL traffic"

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [aws_security_group.ec2_security_group.id]
  }
}

# Output the load balancer DNS name and RDS endpoint
output "load_balancer_dns" {
  value = aws_elb.cloudgen_elb.dns_name
}

output "rds_endpoint" {
  value = aws_db_instance.cloudgen_db_instance.endpoint
}
