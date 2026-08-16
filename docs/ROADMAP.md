# ROADMAP

`fbrl-backend`를 Azure에 올리기까지 인프라를 어떤 순서로 준비할지 정리한 문서다. 아직
Azure 계정도 없는 계획 단계라, 여기 적힌 순서와 조건은 진행 상황에 따라 얼마든지 바뀔 수
있다.

## 단계별 타임라인

| 단계 | 내용 | 상태 | 다음 단계로 넘어가는 조건 |
| --- | --- | --- | --- |
| 1. 지금 완료 | 로컬 `docker-compose` 환경 검증 (postgres/redis/kafka/kafka-connect/jaeger 5개 서비스 기동 확인) | ✅ 완료 | — |
| 2. 다음 | Terraform 계획 문서 작성 → Azure 계정 개설 → VM 생성 + k3s 설치 | 🔜 예정 | 형 MVP 완성 시점 근처에 Azure 계정 개설. 계정 생기는 즉시 `terraform/` 실행 코드 작성 시작 |
| 3. 그 다음 | `k8s/rbac/` 등 로컬 docker-compose 기반 구성을 실제 K8s 매니페스트로 전환, Debezium 커넥터 실등록 | ⏳ 대기 | k3s 클러스터가 뜨고 kubectl 접근이 확인된 후 진행 |
| 4. 병행 | Chaos Mesh로 장애 시나리오(노드/파드 다운, 네트워크 지연 등) 실제 검증 | ⏳ 대기 | 3단계로 K8s 클러스터에 애플리케이션이 배포된 이후, 운영 트래픽 투입 전에 진행 |
| 5. 여유 시 | CI/CD 파이프라인 구성, 모니터링/알림(Grafana 등) 구축 | ⏳ 대기 | 1~3단계가 안정화된 뒤 우선순위에 따라 착수 |

## 참고

- 인프라 요구사항은 [DEPLOYMENT.md](./DEPLOYMENT.md)에 정리되어 있다.
- AKS 같은 관리형 서비스 대신 VM에 k3s를 직접 올리는 쪽으로 무게가 실려 있다. 예산이
  빠듯해서다. 다만 확정은 아니고, Azure 계정을 만든 뒤 실제 비용을 비교해보고 결정한다.
- `k8s/rbac/`에 있는 ServiceAccount, Role, RoleBinding은 K8s Lease API 기반 리더 선출
  (`K8S_LEADER_ELECTION_*`)에 쓰인다. 클러스터가 생기기 전까지는 그대로 적용 전 단계로 둔다.
- Redis/Kafka 인증 경로, Kafka replication factor, ShedLock 네임스페이스 분리처럼 코드
  쪽에 남은 항목들은 [DEPLOYMENT.md](./DEPLOYMENT.md)의 "인프라 팀과 협의 필요한 별도 항목"에
  정리해뒀다. Azure 서비스가 확정되는 2단계 이후에 같이 풀 계획이다.
