variable "zone_name" {}
variable "shared_credentials_file" {
  type    = string
  default = "/var/lib/jenkins/.aws/credentials"
}
variable "profile" {}
variable "region" {
  type    = string
  default = "us-east-1"
}
variable "ttl" {
  default = "300"
}
/* variable "is_cname" {
  type    = bool
  default = false
}
variable "is_a" {
  type    = bool
  default = false
}
variable "is_txt" {
  type    = bool
  default = false
}
 */
variable "is_mx" {
  type    = bool
  default = false
}

variable "is_alb" {
  type    = bool
  default = false
}
variable "no_alb" {
  type    = bool
  default = false
}
variable "elb_us_zone_id" {
  type = string
  //default = "Z35SXDOTRQ7X7K"
}
variable "elb_eu_zone_id" {
  type = string
  //default = "Z32O12XQLNTSW2"
}
variable "elb_ap_zone_id" {
  type = string
  //default = "ZP97RAFLXTNZK"
}
/* variable "us_vpc_id" {
  type    = string
  default = "vpc-0a96141bed41d6cab"
} */

variable "us_vpc_id" {
  type = map
  default = {
    terraform = "vpc-0a96141bed41d6cab"
    lg        = ""
    cd        = ""
  }
}

/* variable "eu_vpc_id" {
  type    = string
  default = "vpc-0e117b6e55f6ef62e"
} */

variable "eu_vpc_id" {
  type = map
  default = {
    terraform = "vpc-0e117b6e55f6ef62e"
    lg        = ""
    cd        = ""
  }
}

/* variable "ap_vpc_id" {
  type    = string
  default = "vpc-0d43b32159f734a2f"
}
 */
variable "ap_vpc_id" {
  type = map
  default = {
    terraform = "vpc-0d43b32159f734a2f"
    lg        = ""
    cd        = ""
  }
}

variable "workspace" {
  type    = string
  default = "lgp-tds-alb-3d"
}
