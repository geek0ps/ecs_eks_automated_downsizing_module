# variables.tf
variable "enable_ecs" {
  type        = bool
  default     = false
  description = "Enable scheduling for ECS clusters"
}

variable "enable_eks" {
  type        = bool
  default     = false
  description = "Enable scheduling for EKS clusters"
}

variable "ecs_cluster_names" {
  type        = list(string)
  default     = []
  description = "List of ECS cluster names to manage"
}

variable "eks_cluster_names" {
  type        = list(string)
  default     = []
  description = "List of EKS cluster names to manage"
}

variable "schedule_scale_down" {
  type        = string
  default     = "cron(30 14 * * ? *)" # 2:30 PM GMT
  description = "Global scale-down schedule"
}

variable "schedule_scale_up" {
  type        = string
  default     = "cron(0 4 * * ? *)" # 4:00 AM GMT
  description = "Global scale-up schedule"
}