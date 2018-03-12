variable "name" {
}

variable "environment" {
}

variable "vpc_id" {}

variable "zone_id" {}

variable "cache_identifier" {}

variable "subnet_ids" {}

variable "maintenance_window" {
  description = "Time window for maintenance."
  default     = "Mon:01:00-Mon:02:00"
}

variable "security_groups" {
  description = "A list of security group IDs"
  type        = "list"
}

variable "desired_clusters" {
  default = "1"
}

variable "instance_type" {
  default = "cache.t2.small"
}

variable "engine_version" {
  default = "1.4.34"
}

variable "dns_name" {
  default= ""
}

variable "alarm_cpu_threshold_percent" {
  default = "75"
}

variable "alarm_memory_threshold_bytes" {
  # 10MB
  default = "10000000"
}


resource "aws_security_group" "memcached" {
  vpc_id = "${var.vpc_id}"
  name        = "${var.name}-memcache-cluster"
  description = "Allows traffic to memcache from other security groups"

  tags {
    Name        = "${var.name}-memcached-group"
    Service     = "${var.name}"
    Environment = "${var.environment}"
  }

  ingress {
    from_port       = 11211
    to_port         = 11211
    protocol        = "TCP"
    security_groups = ["${var.security_groups}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

}

#
resource "aws_elasticache_subnet_group" "memached" {
  name        = "${var.name}"
  description = "Memcache cluster subnet group"
  subnet_ids  = ["${split(",", var.subnet_ids)}"]
}

# ElastiCache resources
#
resource "aws_elasticache_cluster" "memcached" {
  lifecycle {
    create_before_destroy = true
  }

  cluster_id             = "${format("%.16s-%.4s", lower(var.cache_identifier), md5(var.instance_type))}"
  engine                 = "memcached"
  engine_version         = "${var.engine_version}"
  node_type              = "${var.instance_type}"
  num_cache_nodes        = "${var.desired_clusters}"
  az_mode                = "${var.desired_clusters == 1 ? "single-az" : "cross-az"}"
  subnet_group_name      = "${aws_elasticache_subnet_group.memached.name}"
  security_group_ids     = ["${aws_security_group.memcached.id}"]
  maintenance_window     = "${var.maintenance_window}"
  port                   = "11211"

  tags {
    Name        = "${var.name}-memcached"
    Service     = "${var.name}"
    Environment = "${var.environment}"
  }
}

#
# CloudWatch resources
#
resource "aws_cloudwatch_metric_alarm" "cache_cpu" {
  alarm_name          = "alarm${var.environment}MemcachedCacheClusterCPUUtilization"
  alarm_description   = "Memcached cluster CPU utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"

  threshold = "${var.alarm_cpu_threshold_percent}"

  dimensions {
    CacheClusterId = "${aws_elasticache_cluster.memcached.id}"
  }

}

resource "aws_cloudwatch_metric_alarm" "cache_memory" {
  alarm_name          = "alarm${var.environment}MemcachedCacheClusterFreeableMemory"
  alarm_description   = "Memcached cluster freeable memory"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "FreeableMemory"
  namespace           = "AWS/ElastiCache"
  period              = "60"
  statistic           = "Average"

  threshold = "${var.alarm_memory_threshold_bytes}"

  dimensions {
    CacheClusterId = "${aws_elasticache_cluster.memcached.id}"
  }

}

resource "aws_route53_record" "main" {
  zone_id = "${var.zone_id}"
  name    = "${coalesce(var.dns_name, var.name)}"
  type    = "CNAME"
  ttl     = 300
  records = ["${aws_elasticache_cluster.memcached.cluster_address}"]
}


output "id" {
  value = "${aws_elasticache_cluster.memcached.id}"
}

output "cache_security_group_id" {
  value = "${aws_security_group.memcached.id}"
}

output "port" {
  value = "11211"
}

output "configuration_endpoint" {
  value = "${aws_elasticache_cluster.memcached.configuration_endpoint}"
}

output "endpoint" {
  value = "${aws_elasticache_cluster.memcached.cluster_address}"
}