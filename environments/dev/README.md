
# Authentication

You will need to define your own mechanism the provide the AWS backend and provider credentials, refer to terraform documentation

# Init

```shell
terraform init -backend-config=./environments/dev/backend.conf
```

# Plan

```shell
terraform plan -var-file=./environments/dev/env.tfvars -var-file=./environments/dev/services.tfvars.json
```

# Apply

```shell
terraform apply -var-file=./environments/dev/env.tfvars -var-file=./environments/dev/services.tfvars.json
```