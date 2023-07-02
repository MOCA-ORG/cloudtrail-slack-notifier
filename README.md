# Monitor CloudTrail and notify Slack of suspicious operations.

# Notification settings
Please add a new function to `terraform/slack_notifier/lambda/filters.js`
If the return value of the function is not null, the text of the return value will be notified to Slack.

# Deploy
```shell
# copy and modify sample.tfbackend
$ cp sample.tfbackend ./terraform/production.tfbackend

# copy and modify sample.tfvars
$ cp sample.tfvars ./terraform/production.tfvars

# change directory
$ cd ./terraform

# init terraform
$ terraform init -reconfigure -backend-config=production.tfbackend

# apply terraform
$ terraform apply
```
