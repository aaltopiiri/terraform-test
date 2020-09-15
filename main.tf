terraform {
  required_version = ">=0.12.13"
  backend "s3" {
    bucket         = "aaltopiiri-terraform-bucket"
    key            = "terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "aws-locks"
    encrypt        = true
  }
}


provider "aws" {
  region                  = terraform.workspace
  shared_credentials_file = var.shared_credentials_file
  profile                 = var.profile
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_security_group" "instance" {
  name = "my-sg"
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "HTTP-Only"
  }
}

resource "aws_instance" "web-1" {
  ami                    = lookup(var.amis, "${terraform.workspace}")
  instance_type          = "t2.micro"
  availability_zone      = data.aws_availability_zones.available.names[0]
  vpc_security_group_ids = [aws_security_group.instance.id]
  user_data              = <<-EOF
              #!/bin/bash
              yum -y update
              yum -y install httpd
              echo "<html><body bgcolor=white><center><h1><font color=black>WebServer-1</h1></center></body></html>" > /var/www/html/index.html
              sudo systemctl start httpd
              sudo systemctl enable httpd
              EOF
  tags = {
    Name = "web-server-1"
  }
}

resource "aws_instance" "web-2" {
  ami                    = lookup(var.amis, "${terraform.workspace}")
  instance_type          = "t2.micro"
  availability_zone      = data.aws_availability_zones.available.names[1]
  vpc_security_group_ids = [aws_security_group.instance.id]

  user_data = <<-EOF
              #!/bin/bash
              yum -y update
              yum -y install httpd
              echo "<html><body bgcolor=white><center><h1><font color=black>WebServer-2</h1></center></body></html>" > /var/www/html/index.html
              sudo systemctl start httpd
              sudo systemctl enable httpd
              EOF  
  tags = {
    Name = "web-server-2"
  }
}

resource "aws_eip" "web-1-ip" {
  instance = aws_instance.web-1.id
}

resource "aws_eip" "web-2-ip" {
  instance = aws_instance.web-2.id
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "all" {
  vpc_id = data.aws_vpc.default.id
}

resource "aws_alb" "alb" {
  name            = "my-alb"
  security_groups = ["${aws_security_group.instance.id}"]
  subnets         = data.aws_subnet_ids.all.ids
  tags = {
    Name = "terraform-alb"
  }
}

resource "aws_alb_target_group" "group" {
  name     = "terraform-example-alb-target"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id
  stickiness {
    type = "lb_cookie"
  }
  health_check {
    path = "/"
    port = 80
  }
}

resource "aws_alb_listener" "listener_http" {
  load_balancer_arn = aws_alb.alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_alb_target_group.group.arn
    type             = "forward"
  }
}

resource "aws_lb_target_group_attachment" "atachment-1" {
  target_group_arn = aws_alb_target_group.group.arn
  target_id        = aws_instance.web-1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "atachment-2" {
  target_group_arn = aws_alb_target_group.group.arn
  target_id        = aws_instance.web-2.id
  port             = 80
}