resource "aws_elasticsearch_domain" "es" {
  domain_name           = "appsync-audit-log"
  elasticsearch_version = "OpenSearch_1.0"

  advanced_options = {
    "indices.fielddata.cache.size" = ""
    "rest.action.multi.allow_explicit_index" = "true"
  }

  cluster_config {
    instance_type = "m3.medium.elasticsearch"
    instance_count = 1
    dedicated_master_enabled = false
    zone_awareness_enabled = false
  }

  ebs_options {
    ebs_enabled = true
    volume_size = 10
    volume_type = "gp2"
  }
}

resource "aws_elasticsearch_domain_policy" "es" {
  domain_name = aws_elasticsearch_domain.es.domain_name

  access_policies = <<POLICIES
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "es:ESHttpDelete",
        "es:ESHttpHead",
        "es:ESHttpGet",
        "es:ESHttpPost",
        "es:ESHttpPut"
      ],
      "Principal": {
        "AWS": [
          "${aws_iam_role.AppSyncESServiceRole.arn}"
        ]
      },
      "Effect": "Allow",
      "Resource": "${aws_elasticsearch_domain.es.arn}/*"
    }
  ]
}
POLICIES
}