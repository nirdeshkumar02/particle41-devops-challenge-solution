resource "aws_security_group" "cluster" {
  name        = "${var.name}-cluster-sg"
  description = "${var.name}-cluster-sg"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name}-cluster-sg"
  }
}

resource "aws_security_group_rule" "cluster_ingress_from_nodes" {
  security_group_id        = aws_security_group.cluster.id
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.nodes.id
  description              = "Allow nodes to reach API server"
}

resource "aws_security_group_rule" "cluster_egress_all" {
  security_group_id = aws_security_group.cluster.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound from control plane"
}

resource "aws_security_group" "nodes" {
  name        = "${var.name}-nodes-sg"
  description = "${var.name}-nodes-sg"
  vpc_id      = var.vpc_id

  tags = {
    Name                                          = "${var.name}-nodes-sg"
    "karpenter.sh/discovery"                      = var.cluster_name
    "kubernetes.io/cluster/${var.cluster_name}"   = "owned"
  }
}

resource "aws_security_group_rule" "nodes_ingress_self" {
  security_group_id        = aws_security_group.nodes.id
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  source_security_group_id = aws_security_group.nodes.id
  description              = "Allow all node-to-node traffic"
}

resource "aws_security_group_rule" "nodes_ingress_from_cluster" {
  security_group_id        = aws_security_group.nodes.id
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  source_security_group_id = aws_security_group.cluster.id
  description              = "Allow all traffic from control plane"
}

resource "aws_security_group_rule" "nodes_egress_all" {
  security_group_id = aws_security_group.nodes.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound from nodes"
}
