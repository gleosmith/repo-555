# created by sgtcloudcompose - do not edit
# service_type = "Replicate to Postgres Database"
# service_type = "Consumes the feed as a live stream int postgres table"

variable "postgres" {
    type = object({
      name = string
      vpcId = string
      securityGroupId = string
      sqlHost = string
      sqlPort = number
      sqlTable = string
      sqlDatabase = string
      sqlAutocreate = bool
      sqlUsername = string
      sqlPassword = string
    })
    description = "Input variables for the postgres (Replicate to Postgres Database) service"
}

#  get existing vpc and subnets
# ---------------------

data "aws_vpc" "selected" {
  id = var.postgres.vpcId
}

data "aws_subnets" "selected" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }
}

data "aws_subnet" "selected" {
  for_each = toset(data.aws_subnets.selected.ids)
  id       = each.value
}

data "aws_security_group" "selected" {
  id = var.postgres.securityGroupId
}

# create security group and load balancer
# ---------------------
resource "aws_lb_target_group" "cluster_111" {
  name        = var.postgres.name
  port        = 8083
  protocol    = "TCP"
  target_type = "ip"
  vpc_id      = data.aws_vpc.selected.id
  health_check {
      healthy_threshold = 5
      interval = 30
      unhealthy_threshold = 10
      timeout = 15
  }
}

resource "aws_lb" "cluster_111" {
  name               = var.postgres.name
  internal           = false
  load_balancer_type = "network"
  security_groups    = [data.aws_security_group.selected.id]
  subnets            = [for s in data.aws_subnet.selected : s.id]
  tags = {
    Environment = "production"
  }
}

resource "aws_lb_listener" "cluster_111" {
  load_balancer_arn = aws_lb.cluster_111.arn
  port              = "8083"
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.cluster_111.arn
  }
}

# create ecs cluster
# ---------------------

module "ecs" {

  source = "terraform-aws-modules/ecs/aws"
  cluster_name =  var.postgres.name
  task_exec_iam_role_name = "ecsTaskExecutionRole"

  fargate_capacity_providers = {
    FARGATE = {
      default_capacity_provider_strategy = {
        weight = 50
      }
    }
    FARGATE_SPOT = {
      default_capacity_provider_strategy = {
        weight = 50
      }
    }
  }

  services = {
      
    cluster_111 = {
      name = "cluster_111"
      cpu    = 1024
      memory = 4096

      # Container definition(s)
      container_definitions = {

        resolver = {
          cpu       = 256
          memory    = 512
          essential = true
          image     = "docker/ecs-searchdomain-sidecar:1.0"
          memory_reservation = 50
        }

        cluster_111 = {
          cpu       = 512
          memory    = 1024
          essential = true
          image     = "726885752981.dkr.ecr.eu-west-1.amazonaws.com/sanlam/hackathon/connect-jdbc"
          port_mappings = [
            {
              name          = "cluster_111"
              containerPort = 8083
              protocol      = "tcp"
            }
          ]

          dependencies = [{
            containerName = "resolver"
            condition     = "START"
          }]

          environment = [
            {
              name: "CONNECT_BOOTSTRAP_SERVERS"
              value:  "kafka:9092"
            },
            {
              name =  "CONNECT_REST_PORT"
              value =  8083
            },
            {
               name = "CONNECT_GROUP_ID"
               value =  "connect"
            },
            {
              name =  "KAFKA_CREATE_TOPICS"
              value =  "true"
            },
            {
              name =  "CONNECT_CONFIG_STORAGE_REPLICATION_FACTOR"
              value = "1"
            },
            {
              name =  "CONNECT_OFFSET_STORAGE_REPLICATION_FACTOR"
              value =  "1"
            },
            {
              name =  "CONNECT_STATUS_STORAGE_REPLICATION_FACTOR"
              value =  "1"
            },
            {
              name =  "KAFKA_CONFLUENT_TOPIC_REPLICATION_FACTOR"
              value =  "1"
            },
            {
              name =  "CONNECT_CONFIG_STORAGE_TOPIC"
              value =  "connect-config"
            },
            {
              name =  "CONNECT_OFFSET_STORAGE_TOPIC"
              value =  "connect-offsets"
            },
            {
              name =  "CONNECT_STATUS_STORAGE_TOPIC"
              value =  "connect-status"
            },
            {
              name =  "CONNECT_KEY_CONVERTER"
              value =  "org.apache.kafka.connect.json.JsonConverter"
            },
            {
              name =  "CONNECT_VALUE_CONVERTER"
              value =  "org.apache.kafka.connect.json.JsonConverter"
            },
            {
              name =  "CONNECT_INTERNAL_KEY_CONVERTER"
              value =  "org.apache.kafka.connect.json.JsonConverter"
            },
            {
              name =  "CONNECT_INTERNAL_VALUE_CONVERTER"
              value =  "org.apache.kafka.connect.json.JsonConverter"
            },
            {
              name =  "CONNECT_REST_ADVERTISED_HOST_NAME"
              value = "localhost"
            },
            {
              name =  "CONNECT_PLUGIN_PATH"
              value =  "/usr/share/java,/usr/share/confluent-hub-components"
            },
            {
              name =  "CONNECT_SECURITY_PROTOCOL"
              value =  "SASL_SSL"
            },
            {
              name =  "CONNECT_SASL_MECHANISM"
              value =  "SCRAM-SHA-256"
            },
            {
              name =  "CONNECT_SASL_JAAS_CONFIG"
              value =  "org.apache.kafka.common.security.scram.ScramLoginModule required username=\"kafkaclient\" password=\"password\";"
            },
            {
              name =  "CONNECT_SSL_TRUSTSTORE_LOCATION"
              value =  "/etc/confluent/truststore.jks"
            },
            {
              name =  "CONNECT_SSL_TRUSTSTORE_PASSWORD"
              value =  "confluent"
            },
            {
              name =  "CONNECT_SASL_ENABLED_MECHANISMS"
              value =  "SCRAM-SHA-256"
            },
            {
              name =  "CONNECT_CONSUMER_SASL_MECHANISM"
              value = "SCRAM-SHA-256"
            },
            {
              name =  "CONNECT_CONSUMER_SECURITY_PROTOCOL"
              value =  "SASL_SSL"
            },
            {
              name =  "CONNECT_CONSUMER_SASL_JAAS_CONFIG"
              value =  "org.apache.kafka.common.security.scram.ScramLoginModule required username=\"kafkaclient\" password=\"password\";"
            },
            {
              name =  "CONNECT_CONSUMER_SSL_TRUSTSTORE_LOCATION"
              value =  "/etc/confluent/truststore.jks"
            },
            {
              name =  "CONNECT_CONSUMER_SSL_TRUSTSTORE_PASSWORD"
              value =  "confluent"
            },
            {
              name =  "CONNECT_CONSUMER_SASL_ENABLED_MECHANISMS"
              value =  "SCRAM-SHA-256"
            },
            {
              name =  "CONNECT_PRODUCER_SECURITY_PROTOCOL"
              value =  "SASL_SSL"
            },
            {
              name =  "CONNECT_PRODUCER_SASL_JAAS_CONFIG"
              value =  "org.apache.kafka.common.security.scram.ScramLoginModule required username=\"kafkaclient\" password=\"password\";"
            },
            {
              name =  "CONNECT_PRODUCER_SSL_TRUSTSTORE_LOCATION"
              value =  "/etc/confluent/truststore.jks"
            },
            {
              name =  "CONNECT_PRODUCER_SSL_TRUSTSTORE_PASSWORD"
              value =  "confluent"
            },
            {
              name =  "CONNECT_PRODUCER_SASL_ENABLED_MECHANISMS"
              value =  "SCRAM-SHA-256"
            },
            {
              name =  "CONNECTOR_NAME"
              value = var.postgres.name
            },
            {
              name =  "JDBC_CONNECTOR_CLASS"
              value = "io.confluent.connect.jdbc.JdbcSinkConnector"
            },
            {
              name =  "JDBC_AUTO_CREATE"
              value =  var.postgres.sqlAutocreate
            },
            {
              name =  "JDBC_TABLE_NAME"
              value = var.postgres.sqlTable
            },
            {
              name =  "JDBC_USER"
              value =  var.postgres.sqlUsername
            },
            {
              name =  "JDBC_PASSWORD"
              value =  var.postgres.sqlPassword
            },
            {
              name =  "JDBC_HOST"
              value =  var.postgres.sqlHost
            },
            {
              name =  "JDBC_DATABASE"
              value =  var.postgres.sqlDatabase
            },
            {
              name =  "JDBC_SCHEME"
              value =  "postgresql"
            },
            {
              name =  "JDBC_PORT"
              value =  var.postgres.sqlPort
            },
            {
              name =  "JDBC_TOPIC"
              value =  ""
            },
            {
              name =  "CONNECTOR_EXTRA_TABLE_NAME_FORMAT"
              value =  var.postgres.sqlTable
            },
            {
              name =  "CONNECTOR_EXTRA_SSL_MODE"
              value =  "prefer"
            }
          ]

          log_configuration = {
            logDriver = "awslogs",
            options = {
              awslogs-group = "/docker-compose/${var.postgres.name}"
              awslogs-region = "eu-west-1"
              awslogs-stream-prefix = var.postgres.name
            }
          }
          memory_reservation = 100
        }
      }

      load_balancer = {
        service = {
          target_group_arn = aws_lb_target_group.cluster_111.arn
          container_name   = "cluster_111"
          container_port   = 8083
        }
      }

      subnet_ids = [for s in data.aws_subnet.selected : s.id]
      security_group_rules = {
        alb_ingress_3000 = {
          type                     = "ingress"
          from_port                = 8083
          to_port                  = 8083
          protocol                 = "tcp"
          description              = "Kafka Connect Port"
          source_security_group_id = data.aws_security_group.selected.id
        }
        egress_all = {
          type        = "egress"
          from_port   = 0
          to_port     = 0
          protocol    = "-1"
          cidr_blocks = ["0.0.0.0/0"]
        }
      }
    }
  }

  tags = {
    Environment = "Development"
    Project     = "Example"
  }
}