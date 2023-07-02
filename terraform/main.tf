module "slack_notifier" {
  source = "./slack_notifier"
  ORG_NAME = var.ORG_NAME
  TRUSTED_IPS = var.TRUSTED_IPS
    SLACK_WEBHOOK_URL = var.SLACK_WEBHOOK_URL
}
