/* provider "aws" {
  shared_credentials_file = var.shared_credentials_file
  profile                 = var.profile
  region                  = var.region
} */

data "aws_route53_zone" "zone" {
  name = var.zone_name
}

resource "aws_route53_record" "mx-1" {
  count   = var.is_mx ? 1 : 0
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = ""
  type    = "MX"
  records = [
    "1 ASPMX.L.GOOGLE.COM",
    "5 ALT1.ASPMX.L.GOOGLE.COM",
    "5 ALT2.ASPMX.L.GOOGLE.COM",
    "10 ASPMX2.GOOGLEMAIL.COM",
    "10 ASPMX3.GOOGLEMAIL.COM",
  ]

  ttl = var.ttl
}


locals {
  a_records_settings = {
    /*     "www" = { records = ["10.10.10.10"] },
    "dev" = { records = ["10.10.10.11"] } */
  }
}

resource "aws_route53_record" "a-records" {
  //count    = var.is_a ? 1 : 0
  for_each = local.a_records_settings
  zone_id  = data.aws_route53_zone.zone.zone_id
  //name    = "dev"
  name    = each.key
  records = each.value.records
  type    = "A"
  //records = ["10.10.10.10"]
  ttl = var.ttl
}

locals {
  txt_records_settings = {
    "txt1" = { records = ["2z/Uk/zjEGfOFijjVHpd9z1CoqwlMqgKZfD64V75P0k="] },
    "txt2" = { records = ["2z/Uk/zjEGfOFijjVHpd9z1CoqwlMqgKZfD64V75P0k="] }
  }
}

resource "aws_route53_record" "txt-records" {
  //count   = var.is_txt ? 1 : 0
  for_each = local.txt_records_settings
  zone_id  = data.aws_route53_zone.zone.zone_id
  //name    = "txt"
  name    = each.key
  records = each.value.records
  type    = "TXT"
  //records = ["2z/Uk/zjEGfOFijjVHpd9z1CoqwlMqgKZfD64V75P0k="]
  ttl = var.ttl
}

locals {
  cname_records_settings = {
    "cname1" = { records = ["ghs.google.com"] },
    "cname2" = { records = ["ghs.google.com"] },
    "cname3" = { records = ["ghs.google.com"] }
  }
}

resource "aws_route53_record" "cname-records" {
  //count   = var.is_cname ? 1 : 0
  for_each = local.cname_records_settings
  zone_id  = data.aws_route53_zone.zone.zone_id
  //name    = "mail"
  name    = each.key
  records = each.value.records
  type    = "CNAME"
  //records = ["ghs.google.com"]
  ttl = var.ttl
}


module "acm_request_certificate" {
  source                            = "git::https://github.com/cloudposse/terraform-aws-acm-request-certificate.git?ref=tags/0.7.0"
  domain_name                       = "${var.zone_name}"
  process_domain_validation_options = true
  ttl                               = "300"
  subject_alternative_names         = ["*.${var.zone_name}"]
}

//Region us-east-1 (North Virginia)  

provider "aws" {
  shared_credentials_file = var.shared_credentials_file
  profile                 = var.profile
  region                  = "us-east-1"
}

resource "aws_security_group" "sg_us" {
  count    = var.no_alb ? 1 : 0
  provider = aws
  name     = "leadgen-http-default"
  vpc_id   = var.us_vpc_id[var.profile]
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
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${var.workspace}-http-default"
  }
}

data "aws_vpc" "default_us" {
  count    = var.no_alb ? 1 : 0
  provider = aws
  id       = var.us_vpc_id[var.profile]
}

data "aws_subnet_ids" "all_us" {
  count    = var.no_alb ? 1 : 0
  provider = aws
  vpc_id   = var.us_vpc_id[var.profile]
  //depends_on = [aws_vpc.main]
}

resource "aws_lb" "alb_us" {
  count              = var.no_alb ? 1 : 0
  provider           = aws
  name               = var.workspace
  load_balancer_type = "application"
  //security_groups = [aws_security_group.sg_us.id]
  //subnets         = data.aws_subnet_ids.all_us.ids
  security_groups = [aws_security_group.sg_us[count.index].id]
  subnets         = data.aws_subnet_ids.all_us[count.index].ids
  ip_address_type = "dualstack"
  tags = {
    Name = var.workspace
  }
}

data "aws_lb" "default_us_alb" {
  count    = var.is_alb ? 1 : 0
  provider = aws
  name     = var.elb_ap_zone_id
}

resource "aws_lb_target_group" "group_us" {
  count    = var.no_alb ? 1 : 0
  provider = aws
  name     = var.workspace
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.us_vpc_id[var.profile]

  health_check {
    enabled             = true
    interval            = 30
    path                = "/status"
    port                = 80
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    protocol            = "HTTP"
  }
  tags = {
    Name = var.workspace
  }
}

resource "aws_lb_listener" "listener_http_us" {
  count    = var.no_alb ? 1 : 0
  provider = aws
  //load_balancer_arn = aws_lb.alb_us.arn
  load_balancer_arn = aws_lb.alb_us[count.index].arn

  port     = "80"
  protocol = "HTTP"

  default_action {
    //target_group_arn = aws_lb_target_group.group_us.arn
    target_group_arn = aws_lb_target_group.group_us[count.index].arn

    type = "forward"
  }
}

//Latency Policy

resource "aws_route53_record" "a-latency-us-east-1-alb" {
  count          = var.no_alb ? 1 : 0
  zone_id        = data.aws_route53_zone.zone.zone_id
  name           = var.zone_name
  type           = "A"
  set_identifier = "cdp-tds-us-east-1-a"
  latency_routing_policy {
    region = "us-east-1"
  }
  alias {
    name                   = aws_lb.alb_us[count.index].dns_name
    zone_id                = aws_lb.alb_us[count.index].zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "aaaa-latency-us-east-1-alb" {
  count          = var.no_alb ? 1 : 0
  zone_id        = data.aws_route53_zone.zone.zone_id
  name           = var.zone_name
  type           = "AAAA"
  set_identifier = "cdp-tds-us-east-1-aaaa"
  latency_routing_policy {
    region = "us-east-1"
  }
  alias {
    name                   = aws_lb.alb_us[count.index].dns_name
    zone_id                = aws_lb.alb_us[count.index].zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "a-latency-us-east-1" {
  count          = var.is_alb ? 1 : 0
  zone_id        = data.aws_route53_zone.zone.zone_id
  name           = var.zone_name
  type           = "A"
  set_identifier = "cdp-tds-us-east-1-a"
  latency_routing_policy {
    region = "us-east-1"
  }
  alias {
    name                   = data.aws_lb.default_us_alb[count.index].dns_name
    zone_id                = data.aws_lb.default_us_alb[count.index].zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "aaaa-latency-us-east-1" {
  count          = var.is_alb ? 1 : 0
  zone_id        = data.aws_route53_zone.zone.zone_id
  name           = var.zone_name
  type           = "AAAA"
  set_identifier = "cdp-tds-us-east-1-aaaa"
  latency_routing_policy {
    region = "us-east-1"
  }
  alias {
    name                   = data.aws_lb.default_us_alb[count.index].dns_name
    zone_id                = data.aws_lb.default_us_alb[count.index].zone_id
    evaluate_target_health = false
  }
}

//Region eu-west-1 (Dublin) 

provider "aws" {
  alias                   = "eu"
  shared_credentials_file = var.shared_credentials_file
  profile                 = var.profile
  region                  = "eu-west-1"
}

resource "aws_security_group" "sg_eu" {
  count    = var.no_alb ? 1 : 0
  provider = aws.eu
  name     = "leadgen-http-default"
  vpc_id   = var.eu_vpc_id[var.profile]
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
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${var.workspace}-eu-west-1-http-default"
  }
}

data "aws_vpc" "default_eu" {
  count    = var.no_alb ? 1 : 0
  provider = aws.eu
  id       = var.eu_vpc_id[var.profile]
}

data "aws_subnet_ids" "all_eu" {
  count    = var.no_alb ? 1 : 0
  provider = aws.eu
  vpc_id   = var.eu_vpc_id[var.profile]
  //depends_on = [aws_vpc.main]
}

resource "aws_lb" "alb_eu" {
  count              = var.no_alb ? 1 : 0
  provider           = aws.eu
  name               = "${var.workspace}-eu-west"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.sg_eu[count.index].id]
  subnets            = data.aws_subnet_ids.all_eu[count.index].ids
  ip_address_type    = "dualstack"
  tags = {
    Name = "${var.workspace}-eu-west"
  }
}

data "aws_lb" "default_eu_alb" {
  count    = var.is_alb ? 1 : 0
  provider = aws.eu
  name     = var.elb_ap_zone_id
}

resource "aws_lb_target_group" "group_eu" {
  count    = var.no_alb ? 1 : 0
  provider = aws.eu
  name     = "${var.workspace}-eu-west"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.eu_vpc_id[var.profile]

  health_check {
    enabled             = true
    interval            = 30
    path                = "/status"
    port                = 80
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    protocol            = "HTTP"
  }
  tags = {
    Name = "${var.workspace}-eu-west"
  }
}

resource "aws_lb_listener" "listener_http_eu" {
  count             = var.no_alb ? 1 : 0
  provider          = aws.eu
  load_balancer_arn = aws_lb.alb_eu[count.index].arn

  port     = "80"
  protocol = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.group_eu[count.index].arn

    type = "forward"
  }
}

//Health Check eu-west-1

resource "aws_route53_health_check" "health_check_eu-alb" {
  count             = var.no_alb ? 1 : 0
  fqdn              = aws_lb.alb_eu[count.index].dns_name
  port              = 80
  type              = "HTTP"
  resource_path     = "/status"
  failure_threshold = "5"
  request_interval  = "30"

  tags = {
    Name = "${var.workspace}-eu-west-1"
  }
}

resource "aws_route53_health_check" "health_check_eu" {
  count             = var.is_alb ? 1 : 0
  fqdn              = data.aws_lb.default_eu_alb[count.index].dns_name
  port              = 80
  type              = "HTTP"
  resource_path     = "/status"
  failure_threshold = "5"
  request_interval  = "30"

  tags = {
    Name = "${var.workspace}-eu-west-1"
  }
}

//Failover Policy eu-west-1

resource "aws_route53_record" "a-failover-primary-eu-west-1-alb" {
  count           = var.no_alb ? 1 : 0
  provider        = aws.eu
  zone_id         = data.aws_route53_zone.zone.zone_id
  name            = "eu-west-1.${var.zone_name}"
  type            = "A"
  health_check_id = aws_route53_health_check.health_check_eu-alb[count.index].id

  failover_routing_policy {
    type = "PRIMARY"
  }

  set_identifier = "eu-west-1-primary-a"
  alias {
    name                   = aws_lb.alb_eu[count.index].dns_name
    zone_id                = aws_lb.alb_eu[count.index].zone_id
    evaluate_target_health = true
  }

}

resource "aws_route53_record" "a-failover-secondary-eu-west-1-alb" {
  count    = var.no_alb ? 1 : 0
  provider = aws.eu
  zone_id  = data.aws_route53_zone.zone.zone_id
  name     = "eu-west-1.${var.zone_name}"
  type     = "A"

  failover_routing_policy {
    type = "SECONDARY"
  }

  set_identifier = "eu-west-1-secondary-a"
  alias {
    name                   = aws_lb.alb_us[count.index].dns_name
    zone_id                = aws_lb.alb_us[count.index].zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "aaaa-failover-primary-eu-west-1-alb" {
  count           = var.no_alb ? 1 : 0
  provider        = aws.eu
  zone_id         = data.aws_route53_zone.zone.zone_id
  name            = "eu-west-1.${var.zone_name}"
  type            = "AAAA"
  health_check_id = aws_route53_health_check.health_check_eu-alb[count.index].id

  failover_routing_policy {
    type = "PRIMARY"
  }

  set_identifier = "eu-west-1-primary-a"
  alias {
    name                   = aws_lb.alb_eu[count.index].dns_name
    zone_id                = aws_lb.alb_eu[count.index].zone_id
    evaluate_target_health = true
  }

}

resource "aws_route53_record" "aaaa-failover-secondary-eu-west-1-alb" {
  count    = var.no_alb ? 1 : 0
  provider = aws.eu
  zone_id  = data.aws_route53_zone.zone.zone_id
  name     = "eu-west-1.${var.zone_name}"
  type     = "AAAA"

  failover_routing_policy {
    type = "SECONDARY"
  }

  set_identifier = "eu-west-1-secondary-a"
  alias {
    name                   = aws_lb.alb_us[count.index].dns_name
    zone_id                = aws_lb.alb_us[count.index].zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "a-failover-primary-eu-west-1" {
  count           = var.is_alb ? 1 : 0
  zone_id         = data.aws_route53_zone.zone.zone_id
  name            = "eu-west-1.${var.zone_name}"
  type            = "A"
  health_check_id = aws_route53_health_check.health_check_eu[count.index].id

  failover_routing_policy {
    type = "PRIMARY"
  }

  set_identifier = "eu-west-1-primary-a"
  alias {
    name                   = data.aws_lb.default_eu_alb[count.index].dns_name
    zone_id                = data.aws_lb.default_eu_alb[count.index].zone_id
    evaluate_target_health = true
  }

}

resource "aws_route53_record" "a-failover-secondary-eu-west-1" {
  count   = var.is_alb ? 1 : 0
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = "eu-west-1.${var.zone_name}"
  type    = "A"

  failover_routing_policy {
    type = "SECONDARY"
  }

  set_identifier = "eu-west-1-secondary-a"
  alias {
    name                   = data.aws_lb.default_us_alb[count.index].dns_name
    zone_id                = data.aws_lb.default_us_alb[count.index].zone_id
    evaluate_target_health = true
  }
}



resource "aws_route53_record" "aaaa-failover-primary-eu-west-1" {
  count           = var.is_alb ? 1 : 0
  zone_id         = data.aws_route53_zone.zone.zone_id
  name            = "eu-west-1.${var.zone_name}"
  type            = "AAAA"
  health_check_id = aws_route53_health_check.health_check_eu[count.index].id

  failover_routing_policy {
    type = "PRIMARY"
  }

  set_identifier = "eu-west-1-primary-aaaa"
  alias {
    name                   = data.aws_lb.default_eu_alb[count.index].dns_name
    zone_id                = data.aws_lb.default_eu_alb[count.index].zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "aaaa-failover-secondary-eu-west-1" {
  count   = var.is_alb ? 1 : 0
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = "eu-west-1.${var.zone_name}"
  type    = "AAAA"

  failover_routing_policy {
    type = "SECONDARY"
  }

  set_identifier = "eu-west-1-secondary-aaaa"
  alias {
    name                   = data.aws_lb.default_us_alb[count.index].dns_name
    zone_id                = data.aws_lb.default_us_alb[count.index].zone_id
    evaluate_target_health = true
  }
}

//Latency Policy eu-west-1

resource "aws_route53_record" "a-latency-eu-west-1-alb" {
  count          = var.no_alb ? 1 : 0
  zone_id        = data.aws_route53_zone.zone.zone_id
  name           = var.zone_name
  type           = "A"
  set_identifier = "cdp-tds-eu-west-1-a"
  latency_routing_policy {
    region = "eu-west-1"
  }
  alias {
    name                   = aws_route53_record.a-failover-primary-eu-west-1-alb[count.index].name
    zone_id                = aws_route53_record.a-failover-primary-eu-west-1-alb[count.index].zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "aaaa-latency-eu-west-1-alb" {
  count          = var.no_alb ? 1 : 0
  zone_id        = data.aws_route53_zone.zone.zone_id
  name           = var.zone_name
  type           = "AAAA"
  set_identifier = "cdp-tds-eu-west-1-aaaa"
  latency_routing_policy {
    region = "eu-west-1"
  }
  alias {
    name                   = aws_route53_record.aaaa-failover-primary-eu-west-1-alb[count.index].name
    zone_id                = aws_route53_record.aaaa-failover-primary-eu-west-1-alb[count.index].zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "a-latency-eu-west-1" {
  count          = var.is_alb ? 1 : 0
  zone_id        = data.aws_route53_zone.zone.zone_id
  name           = var.zone_name
  type           = "A"
  set_identifier = "cdp-tds-eu-west-1-a"
  latency_routing_policy {
    region = "eu-west-1"
  }
  alias {
    name                   = aws_route53_record.a-failover-primary-eu-west-1[count.index].name
    zone_id                = aws_route53_record.a-failover-primary-eu-west-1[count.index].zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "aaaa-latency-eu-west-1" {
  count          = var.is_alb ? 1 : 0
  zone_id        = data.aws_route53_zone.zone.zone_id
  name           = var.zone_name
  type           = "AAAA"
  set_identifier = "cdp-tds-eu-west-1-aaaa"
  latency_routing_policy {
    region = "eu-west-1"
  }
  alias {
    name                   = aws_route53_record.aaaa-failover-primary-eu-west-1[count.index].name
    zone_id                = aws_route53_record.aaaa-failover-primary-eu-west-1[count.index].zone_id
    evaluate_target_health = false
  }
}



//Region ap-south-1 (Mumbai) 

provider "aws" {
  alias                   = "ap"
  shared_credentials_file = var.shared_credentials_file
  profile                 = var.profile
  region                  = "ap-south-1"
}

resource "aws_security_group" "sg_ap" {
  count    = var.no_alb ? 1 : 0
  provider = aws.ap
  name     = "leadgen-http-default"
  vpc_id   = var.ap_vpc_id[var.profile]
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
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${var.workspace}-ap-south-1-http-default"
  }
}

data "aws_vpc" "default_ap" {
  count    = var.no_alb ? 1 : 0
  provider = aws.ap
  id       = var.ap_vpc_id[var.profile]
}

data "aws_subnet_ids" "all_ap" {
  count    = var.no_alb ? 1 : 0
  provider = aws.ap
  vpc_id   = var.ap_vpc_id[var.profile]
  //depends_on = [aws_vpc.main]
}

resource "aws_lb" "alb_ap" {
  count              = var.no_alb ? 1 : 0
  provider           = aws.ap
  name               = "${var.workspace}-ap-south"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.sg_ap[count.index].id]
  subnets            = data.aws_subnet_ids.all_ap[count.index].ids
  ip_address_type    = "dualstack"
  tags = {
    Name = "${var.workspace}-ap-south"
  }
}

data "aws_lb" "default_ap_alb" {
  count    = var.is_alb ? 1 : 0
  provider = aws.ap
  name     = var.elb_ap_zone_id
}

resource "aws_lb_target_group" "group_ap" {
  count    = var.no_alb ? 1 : 0
  provider = aws.ap
  name     = "${var.workspace}-ap-south"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.ap_vpc_id[var.profile]

  health_check {
    enabled             = true
    interval            = 30
    path                = "/status"
    port                = 80
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    protocol            = "HTTP"
  }
  tags = {
    Name = "${var.workspace}-ap-south"
  }
}

resource "aws_lb_listener" "listener_http_ap" {
  count             = var.no_alb ? 1 : 0
  provider          = aws.ap
  load_balancer_arn = aws_lb.alb_ap[count.index].arn

  port     = "80"
  protocol = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.group_ap[count.index].arn

    type = "forward"
  }
}

//Health Check ap-south-1


resource "aws_route53_health_check" "health_check_ap-alb" {
  count             = var.no_alb ? 1 : 0
  fqdn              = aws_lb.alb_ap[count.index].dns_name
  port              = 80
  type              = "HTTP"
  resource_path     = "/status"
  failure_threshold = "5"
  request_interval  = "30"

  tags = {
    Name = "${var.workspace}-ap-south-1"
  }
}

resource "aws_route53_health_check" "health_check_ap" {
  count             = var.is_alb ? 1 : 0
  fqdn              = data.aws_lb.default_ap_alb[count.index].dns_name
  port              = 80
  type              = "HTTP"
  resource_path     = "/status"
  failure_threshold = "5"
  request_interval  = "30"

  tags = {
    Name = "${var.workspace}-ap-south-1"
  }
}

//Failover Policy ap-south-1

resource "aws_route53_record" "a-failover-primary-ap-south-1-alb" {
  count           = var.no_alb ? 1 : 0
  zone_id         = data.aws_route53_zone.zone.zone_id
  name            = "ap-south-1.${var.zone_name}"
  type            = "A"
  health_check_id = aws_route53_health_check.health_check_ap-alb[count.index].id

  failover_routing_policy {
    type = "PRIMARY"
  }

  set_identifier = "ap-south-1-primary-a"
  alias {
    name                   = aws_lb.alb_ap[count.index].dns_name
    zone_id                = aws_lb.alb_ap[count.index].zone_id
    evaluate_target_health = true
  }

}

resource "aws_route53_record" "a-failover-secondary-ap-south-1-alb" {
  count   = var.no_alb ? 1 : 0
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = "ap-south-1.${var.zone_name}"
  type    = "A"

  failover_routing_policy {
    type = "SECONDARY"
  }

  set_identifier = "ap-south-1-secondary-a"
  alias {
    name                   = aws_lb.alb_us[count.index].dns_name
    zone_id                = aws_lb.alb_us[count.index].zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "aaaa-failover-primary-ap-south-1-alb" {
  count           = var.no_alb ? 1 : 0
  zone_id         = data.aws_route53_zone.zone.zone_id
  name            = "ap-south-1.${var.zone_name}"
  type            = "AAAA"
  health_check_id = aws_route53_health_check.health_check_ap-alb[count.index].id

  failover_routing_policy {
    type = "PRIMARY"
  }

  set_identifier = "ap-south-1-primary-aaaa"
  alias {
    name                   = aws_lb.alb_ap[count.index].dns_name
    zone_id                = aws_lb.alb_ap[count.index].zone_id
    evaluate_target_health = true
  }

}

resource "aws_route53_record" "aaaa-failover-secondary-ap-south-1-alb" {
  count   = var.no_alb ? 1 : 0
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = "ap-south-1.${var.zone_name}"
  type    = "AAAA"

  failover_routing_policy {
    type = "SECONDARY"
  }

  set_identifier = "ap-south-1-secondary-aaaa"
  alias {
    name                   = aws_lb.alb_us[count.index].dns_name
    zone_id                = aws_lb.alb_us[count.index].zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "a-failover-primary-ap-south-1" {
  count           = var.is_alb ? 1 : 0
  zone_id         = data.aws_route53_zone.zone.zone_id
  name            = "ap-south-1.${var.zone_name}"
  type            = "A"
  health_check_id = aws_route53_health_check.health_check_ap[count.index].id

  failover_routing_policy {
    type = "PRIMARY"
  }

  set_identifier = "ap-south-1-primary-a"
  alias {
    name                   = data.aws_lb.default_ap_alb[count.index].dns_name
    zone_id                = data.aws_lb.default_ap_alb[count.index].zone_id
    evaluate_target_health = true
  }

}

resource "aws_route53_record" "a-failover-secondary-ap-south-1" {
  count   = var.is_alb ? 1 : 0
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = "ap-south-1.${var.zone_name}"
  type    = "A"

  failover_routing_policy {
    type = "SECONDARY"
  }

  set_identifier = "ap-south-1-secondary-a"
  alias {
    name                   = data.aws_lb.default_us_alb[count.index].dns_name
    zone_id                = data.aws_lb.default_us_alb[count.index].zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "aaaa-failover-primary-ap-south-1" {
  count           = var.is_alb ? 1 : 0
  zone_id         = data.aws_route53_zone.zone.zone_id
  name            = "ap-south-1.${var.zone_name}"
  type            = "AAAA"
  health_check_id = aws_route53_health_check.health_check_ap[count.index].id

  failover_routing_policy {
    type = "PRIMARY"
  }

  set_identifier = "ap-south-1-primary-aaaa"
  alias {
    name                   = data.aws_lb.default_ap_alb[count.index].dns_name
    zone_id                = data.aws_lb.default_ap_alb[count.index].zone_id
    evaluate_target_health = true
  }

}

resource "aws_route53_record" "aaaa-failover-secondary-ap-south-1" {
  count   = var.is_alb ? 1 : 0
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = "ap-south-1.${var.zone_name}"
  type    = "AAAA"

  failover_routing_policy {
    type = "SECONDARY"
  }

  set_identifier = "ap-south-1-secondary-aaaa"
  alias {
    name                   = data.aws_lb.default_us_alb[count.index].dns_name
    zone_id                = data.aws_lb.default_us_alb[count.index].zone_id
    evaluate_target_health = true
  }
}

//Latency Policy ap-south-1


resource "aws_route53_record" "a-latency-ap-south-1-alb" {
  count          = var.no_alb ? 1 : 0
  zone_id        = data.aws_route53_zone.zone.zone_id
  name           = var.zone_name
  type           = "A"
  set_identifier = "cdp-tds-ap-south-1-a"
  latency_routing_policy {
    region = "ap-south-1"
  }
  alias {
    name                   = aws_route53_record.a-failover-primary-ap-south-1-alb[count.index].name
    zone_id                = aws_route53_record.a-failover-primary-ap-south-1-alb[count.index].zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "aaaa-latency-ap-south-1-alb" {
  count          = var.no_alb ? 1 : 0
  zone_id        = data.aws_route53_zone.zone.zone_id
  name           = var.zone_name
  type           = "AAAA"
  set_identifier = "cdp-tds-ap-south-1-aaaa"
  latency_routing_policy {
    region = "ap-south-1"
  }
  alias {
    name                   = aws_route53_record.aaaa-failover-primary-ap-south-1-alb[count.index].name
    zone_id                = aws_route53_record.aaaa-failover-primary-ap-south-1-alb[count.index].zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "a-latency-ap-south-1" {
  count          = var.is_alb ? 1 : 0
  zone_id        = data.aws_route53_zone.zone.zone_id
  name           = var.zone_name
  type           = "A"
  set_identifier = "cdp-tds-ap-south-1-a"
  latency_routing_policy {
    region = "ap-south-1"
  }
  alias {
    name                   = aws_route53_record.a-failover-primary-ap-south-1[count.index].name
    zone_id                = aws_route53_record.a-failover-primary-ap-south-1[count.index].zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "aaaa-latency-ap-south-1" {
  count          = var.is_alb ? 1 : 0
  zone_id        = data.aws_route53_zone.zone.zone_id
  name           = var.zone_name
  type           = "AAAA"
  set_identifier = "cdp-tds-ap-south-1-aaaa"
  latency_routing_policy {
    region = "ap-south-1"
  }
  alias {
    name                   = aws_route53_record.aaaa-failover-primary-ap-south-1[count.index].name
    zone_id                = aws_route53_record.aaaa-failover-primary-ap-south-1[count.index].zone_id
    evaluate_target_health = false
  }
}