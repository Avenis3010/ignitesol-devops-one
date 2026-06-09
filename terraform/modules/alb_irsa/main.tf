resource "aws_iam_role" "alb_controller" {
  name = "${var.project_name}-${var.env}-alb-controller-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = var.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${var.oidc_provider_url}:aud" = "sts.amazonaws.com"
          "${var.oidc_provider_url}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
        }
      }
    }]
  })

  tags = { Role = "alb-controller", Environment = var.env }
}

# AWS managed policy for the ALB controller
# Full policy doc: https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json
resource "aws_iam_role_policy_attachment" "alb_controller" {
  role       = aws_iam_role.alb_controller.name
  policy_arn = "arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess"
}

# Additional permissions the ALB controller needs
resource "aws_iam_role_policy" "alb_controller_extra" {
  name = "${var.project_name}-${var.env}-alb-controller-extra"
  role = aws_iam_role.alb_controller.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeVpcs", "ec2:DescribeSubnets", "ec2:DescribeSecurityGroups",
          "ec2:DescribeInstances", "ec2:DescribeInternetGateways",
          "ec2:DescribeAvailabilityZones", "ec2:DescribeAccountAttributes",
          "ec2:DescribeAddresses", "ec2:DescribeTags",
          "ec2:CreateSecurityGroup", "ec2:DeleteSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress", "ec2:RevokeSecurityGroupIngress",
          "cognito-idp:DescribeUserPoolClient",
          "acm:ListCertificates", "acm:DescribeCertificate",
          "iam:CreateServiceLinkedRole",
          "waf-regional:GetWebACL", "waf-regional:GetWebACLForResource",
          "wafv2:GetWebACL", "wafv2:GetWebACLForResource",
          "shield:GetSubscriptionState"
        ]
        Resource = ["*"]
      }
    ]
  })
}

output "role_arn" { value = aws_iam_role.alb_controller.arn }
