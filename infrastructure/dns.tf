variable "gandi_api_key" {
  sensitive = true
}

provider "gandi" {
  key = var.gandi_api_key
}

data "gandi_domain" "BF_dev" {
  name = "BF.dev"
}

resource "gandi_livedns_record" "BF_dev_ALIAS" {
  zone   = data.gandi_domain.BF_dev.id
  name   = "@"
  type   = "ALIAS"
  ttl    = 3600
  values = ["${aws_lb.BF.dns_name}."]
}

resource "gandi_livedns_record" "BF_dev_www" {
  zone   = data.gandi_domain.BF_dev.id
  name   = "www"
  type   = "CNAME"
  ttl    = 3600
  values = ["BF.dev."]
}

resource "gandi_livedns_record" "BF_dev_MX" {
  zone   = data.gandi_domain.BF_dev.id
  name   = "@"
  type   = "MX"
  ttl    = 10800
  values = ["10 spool.mail.gandi.net.", "50 fb.mail.gandi.net."]
}

resource "gandi_livedns_record" "BF_dev_SPF" {
  zone   = data.gandi_domain.BF_dev.id
  name   = "@"
  type   = "TXT"
  ttl    = 10800
  values = ["\"v=spf1 include:_mailcust.gandi.net ?all\""]
}
