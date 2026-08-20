output "vm_public_ip" {
  description = "VM의 Public IP"
  value       = azurerm_public_ip.main.ip_address
}

output "ssh_command" {
  description = "SSH 접속 명령어 예시"
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.main.ip_address}"
}

output "postgres_main_fqdn" {
  description = "운영용 Postgres Flexible Server 연결 주소 (VNet 내부에서만 resolve됨)"
  value       = azurerm_postgresql_flexible_server.main.fqdn
}

output "postgres_demo_fqdn" {
  description = "데모용 Postgres Flexible Server 연결 주소 (VNet 내부에서만 resolve됨)"
  value       = azurerm_postgresql_flexible_server.demo.fqdn
}

output "redis_hostname" {
  description = "Redis 캐시 호스트명 (Azure Managed Redis)"
  value       = azurerm_managed_redis.main.hostname
}

output "acr_login_server" {
  description = "Azure Container Registry 로그인 서버 주소 (docker login/push 대상)"
  value       = azurerm_container_registry.main.login_server
}
