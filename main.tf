variable "region" {}
#variable "shared_credentials_file" {}
variable "profile" {}
variable "amis" {
  type = map
  }

variable "server_port" {
description = "The port the server will use for HTTP requests"
  type        = number
}

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
  region                  = var.region
  #shared_credentials_file = "${var.shared_credentials_file}"
  profile                 = var.profile
}

/* resource "aws_key_pair" "example" {
  key_name   = "examplekey"
  public_key = file("~/.ssh/terraform.pub")
} */

resource "aws_security_group" "instance" { 
  name = "terraform-sg"
  ingress {
  from_port = var.server_port
  to_port = var.server_port
  protocol = "tcp"
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

}

resource "aws_instance" "web" {
  ami = lookup(var.amis, var.region)
  instance_type = "t2.micro"
  #key_name = aws_key_pair.example.key_name
  key_name = "AWS-Free"
  vpc_security_group_ids = [aws_security_group.instance.id]
    
    provisioner "remote-exec" {
     inline = [
       "sudo amazon-linux-extras enable nginx1.12",
       "sudo yum -y install nginx",
       "sudo systemctl start nginx",
     ]
   }  

   connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("./AWS-Free.pem")
    #private_key = file("~/.ssh/terraform")
    host        = self.public_ip
     }

  tags = {
  Name = "terraform-example"
}
}

resource "aws_eip" "ip" {
  #vpc      = true
  instance = aws_instance.web.id
}

