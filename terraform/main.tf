# state 파일은 지금 당장은 로컬(terraform.tfstate)로 둔다.
# 팀 프로젝트로 확장되면 azurerm backend(Storage Account)로 전환 예정.
# (Storage Account 자체는 순환 의존성 때문에 Terraform 밖에서 수동으로 먼저 만들어야 함 — terraform/README.md 참고)

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.0.0, < 5.0.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# 1. 리소스 그룹 — 이 프로젝트의 모든 리소스를 묶는 컨테이너
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
}

# 2. 네트워크 — VM 하나 들어갈 최소 구성
resource "azurerm_virtual_network" "main" {
  name                = "${var.vm_name}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_subnet" "main" {
  name                 = "${var.vm_name}-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

# 3. 네트워크 보안 그룹 — 22(SSH), 6443(k3s API)만 관리자 IP에게 허용, 나머지는
#    Azure NSG 기본 규칙(AllowVnetInBound 등 이후 우선순위 65500의 DenyAllInBound)으로 차단된다.
resource "azurerm_network_security_group" "main" {
  name                = "${var.vm_name}-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "AllowSSHFromAdmin"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.admin_ip
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowK3sApiFromAdmin"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "6443"
    source_address_prefix      = var.admin_ip
    destination_address_prefix = "*"
  }
}

# 4. Public IP + NIC
resource "azurerm_public_ip" "main" {
  name                = "${var.vm_name}-pip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "main" {
  name                = "${var.vm_name}-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.main.id
  }
}

resource "azurerm_network_interface_security_group_association" "main" {
  network_interface_id      = azurerm_network_interface.main.id
  network_security_group_id = azurerm_network_security_group.main.id
}

# 5. Linux VM (k3s 노드) — B2ms, SSH 키 인증만 허용(비밀번호 인증 비활성화)
resource "azurerm_linux_virtual_machine" "main" {
  name                = var.vm_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  size                = var.vm_size
  admin_username      = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.main.id,
  ]

  disable_password_authentication = true

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_key_path)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  # Ubuntu 24.04 LTS (Noble Numbat) — 이 글 작성 시점 최신 LTS
  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}

# 6. Postgres/Redis — VM에는 Kafka+Kafka Connect만 남기고, 관리형 서비스로 이전
#
# Postgres Flexible Server의 방화벽 규칙은 "퍼블릭 IP" 기준으로만 필터링할 수 있고
# VM의 프라이빗 IP는 애초에 대상이 될 수 없다. "공인 인터넷 전체에 열지 말 것"을
# 문자 그대로 만족시키려면 VNet 통합(private access)이 맞는 방법이라 그렇게 구현했다
# — 이러면 퍼블릭 엔드포인트 자체가 없어져서 VNet 안(=이 VM)에서만 접근 가능해진다.
# 별도 위임 서브넷(delegated subnet)과 Private DNS Zone이 필요하다.

resource "azurerm_subnet" "postgres" {
  name                 = "${var.vm_name}-postgres-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]

  delegation {
    name = "postgres-flexible-server-delegation"

    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_private_dns_zone" "postgres" {
  name                = "fbrl.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  name                  = "${var.vm_name}-postgres-dns-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.postgres.name
  virtual_network_id    = azurerm_virtual_network.main.id
}

# 운영용 Postgres
resource "azurerm_postgresql_flexible_server" "main" {
  name                = "fbrl-postgres-main"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  version    = "16"
  sku_name   = "B_Standard_B1ms" # 가장 저렴한 Burstable 티어
  storage_mb = 32768             # Flexible Server 최소 스토리지

  administrator_login    = var.postgres_admin_username
  administrator_password = var.postgres_admin_password

  delegated_subnet_id           = azurerm_subnet.postgres.id
  private_dns_zone_id           = azurerm_private_dns_zone.postgres.id
  public_network_access_enabled = false # VNet 통합과 퍼블릭 액세스는 동시에 켤 수 없음

  zone = null

  depends_on = [azurerm_private_dns_zone_virtual_network_link.postgres]
}

resource "azurerm_postgresql_flexible_server_configuration" "main_wal_level" {
  name      = "wal_level"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "logical" # Debezium CDC 때문에 필수
}

# 데모용 Postgres
resource "azurerm_postgresql_flexible_server" "demo" {
  name                = "fbrl-postgres-demo"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  version    = "16"
  sku_name   = "B_Standard_B1ms"
  storage_mb = 32768

  administrator_login    = var.postgres_admin_username
  administrator_password = var.postgres_admin_password

  delegated_subnet_id           = azurerm_subnet.postgres.id
  private_dns_zone_id           = azurerm_private_dns_zone.postgres.id
  public_network_access_enabled = false

  zone = null

  depends_on = [azurerm_private_dns_zone_virtual_network_link.postgres]
}

resource "azurerm_postgresql_flexible_server_configuration" "demo_wal_level" {
  name      = "wal_level"
  server_id = azurerm_postgresql_flexible_server.demo.id
  value     = "logical"
}

# Redis — 구형 Azure Cache for Redis(azurerm_redis_cache, Basic/Standard/Premium)는
# 이 구독에서 단종되어("Azure Cache for Redis is retiring") 생성이 아예 거부된다.
# azurerm_redis_enterprise_cluster도 v5.0에서 제거 예정인 deprecated 리소스라
# 최신 대체 리소스인 azurerm_managed_redis(Azure Managed Redis)를 쓴다.
# 가장 저렴한 SKU인 Balanced_B0 사용 — 구형 Basic C0보다 월 비용이 더 높을 수 있음
# (정확한 가격은 별도 확인 필요).
resource "azurerm_managed_redis" "main" {
  name                = "fbrl-redis"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  sku_name                  = "Balanced_B0"
  high_availability_enabled = false # 비용 최소화 목적, dev 환경이라 이중화 불필요

  # 기본값은 access key 인증이 꺼져있고 Azure AD 인증만 허용됨 — 앱(SPRING_DATA_REDIS_PASSWORD)이
  # 쓰는 비밀번호 방식이 동작하려면 명시적으로 켜야 한다.
  default_database {
    access_keys_authentication_enabled = true
  }
}

# Azure Container Registry — 백엔드 컨테이너 이미지를 정식으로 올려서 k3s가 pull해가게 하기 위함.
# Basic(가장 저렴한 티어), admin 계정 활성화(학습 목적이라 서비스 프린시펄 대신 이 방식으로 충분).
resource "azurerm_container_registry" "main" {
  name                = "fbrlacr"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"
  admin_enabled       = true
}
