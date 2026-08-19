variable "location" {
  description = "리소스를 배포할 Azure 리전"
  type        = string
  default     = "Korea Central"
}

variable "resource_group_name" {
  description = "리소스 그룹 이름"
  type        = string
  default     = "fbrl-dev-rg"
}

variable "vm_name" {
  description = "k3s 노드로 쓸 VM 이름"
  type        = string
  default     = "fbrl-k3s-vm"
}

variable "admin_username" {
  description = "VM 관리자 계정 사용자명"
  type        = string
  default     = "fbrladmin"
}

variable "admin_ip" {
  description = <<-EOT
    SSH(22)/k3s API(6443) 접근을 허용할 관리자 IP.
    CIDR 표기(예: "1.2.3.4/32")로 넣는다. 실행 전 반드시 실제 IP로 채워야 한다.
    ("내 IP는 뭐지"는 https://ifconfig.me 등으로 확인)
  EOT
  type        = string
  default     = "TBD"

  validation {
    condition     = can(cidrhost(var.admin_ip, 0))
    error_message = "admin_ip를 실제 CIDR 값(예: \"1.2.3.4/32\")으로 채워야 합니다. 지금은 \"TBD\" 상태입니다."
  }
}

variable "ssh_public_key_path" {
  description = "VM에 등록할 SSH 공개키 경로 (비밀번호 인증은 비활성화되어 있음)"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "vm_size" {
  description = <<-EOT
    VM 스펙. B2ms(2 vCPU, 8GB RAM)를 기본값으로 둔다 — terraform/README.md 기준
    postgres/redis/kafka/kafka-connect/jaeger를 한 노드에 올릴 때의 절충안으로
    가장 유력한 후보. 예산에 따라 B2s(저렴, 메모리 빠듯) 또는 B4ms(여유, 고비용)로
    조정 가능.
  EOT
  type        = string
  default     = "Standard_B2ms"
}

variable "postgres_admin_username" {
  description = "Postgres Flexible Server(운영/데모 공통) 관리자 계정명"
  type        = string
}

variable "postgres_admin_password" {
  description = <<-EOT
    Postgres Flexible Server(운영/데모 공통) 관리자 비밀번호.
    기본값을 두지 않는다 — terraform.tfvars에 직접 채워 넣어야 하고,
    그 파일은 .gitignore(*.tfvars)로 커밋 대상에서 빠져 있다.
  EOT
  type        = string
  sensitive   = true
}
