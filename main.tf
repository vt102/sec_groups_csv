locals {
  sg_rules = csvdecode(file("./sg_rules.csv"))

  sg_names      = toset([for rule in local.sg_rules : rule.sg_name])

  # Two different mechanisms to loop through the rules; one using a map and one using a list
  #
  # egress_rules is our map.  We use index as an arbitrary, unused key
  egress_rules  = { for index, rule in local.sg_rules : index => rule if rule.rule_type == "egress" }
  #
  # ingress_rules is our list.  Conceptually simpler, but references below are longer and harder to read
  ingress_rules = [ for rule in local.sg_rules : rule if rule.rule_type == "ingress" ]
}

resource "aws_security_group" "sg" {
  for_each = local.sg_names

  vpc_id = "vpc-0ad4ed17f04608261"
  name   = each.value
  tags = {
    Name = each.value
  }
}

resource "aws_vpc_security_group_egress_rule" "erule" {
  for_each = local.egress_rules

  security_group_id = aws_security_group.sg[each.value["sg_name"]].id

  cidr_ipv4                    = each.value["dst_cidr"] != "" ? each.value["dst_cidr"] : null
  referenced_security_group_id = each.value["dst_sg"] != "" ? aws_security_group.sg[each.value["dst_sg"]].id : null

  ip_protocol = each.value["protocol"]
  from_port   = split("-", each.value["port_range"])[0]
  to_port     = split("-", each.value["port_range"])[1]
}

resource "aws_vpc_security_group_ingress_rule" "irule" {
  count = length(local.ingress_rules)

  security_group_id = aws_security_group.sg[local.ingress_rules[count.index]["sg_name"]].id

  cidr_ipv4                    = local.ingress_rules[count.index]["dst_cidr"] != "" ? local.ingress_rules[count.index]["dst_cidr"] : null
  referenced_security_group_id = local.ingress_rules[count.index]["dst_sg"] != "" ? aws_security_group.sg[local.ingress_rules[count.index]["dst_sg"]].id : null

  ip_protocol = local.ingress_rules[count.index]["protocol"]
  from_port   = split("-", local.ingress_rules[count.index]["port_range"])[0]
  to_port     = split("-", local.ingress_rules[count.index]["port_range"])[1]
}

# Using output and `terraform plan` is useful for debugging
#
# output "ingress_rules" {
#   value = local.ingress_rules
# }
