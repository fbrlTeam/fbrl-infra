# fbrl-infra

`fbrl-backend` 프로젝트의 인프라를 관리하는 레포다. 애플리케이션 코드 자체는
[farmer0010/fbrl-backend](https://github.com/farmer0010/fbrl-backend)에 있고, 여기서는
로컬 개발 환경(docker-compose), Kubernetes RBAC 매니페스트, 배포 문서처럼 인프라와 직접
관련된 파일들을 모아둔다.

## 로컬 개발 환경 실행

```bash
# 전체 서비스 실행 (백그라운드)
docker-compose up -d

# 특정 서비스 로그 확인
docker-compose logs -f [서비스명]

# 전체 서비스 종료
docker-compose down

# 볼륨까지 삭제하고 종료 (데이터 초기화)
docker-compose down -v
```

## 서비스 구성

`docker-compose.yml`은 아래 5개 서비스로 구성되어 있습니다.

| 서비스 | 설명 |
| --- | --- |
| `postgres` | 애플리케이션 기본 데이터베이스 (PostgreSQL 16, `wal_level=logical`로 CDC 지원) |
| `redis` | 캐시 및 분산 락(ShedLock 등)에 사용되는 인메모리 스토어 |
| `kafka` | 이벤트 스트리밍 브로커 (KRaft 모드, 단일 노드) |
| `kafka-connect` | Debezium 기반 CDC 커넥터를 구동하는 Kafka Connect (Outbox 패턴용) |
| `jaeger` | 분산 트레이싱 수집/조회 UI (OTLP 수신 지원) |

## Kubernetes RBAC (`k8s/rbac/`)

`k8s/rbac/`에는 ServiceAccount, Role, RoleBinding 매니페스트가 들어 있다. 다만 아직 실제
K8s 클러스터가 없어서 **적용 전 단계**다. 클러스터가 만들어지면 그때 적용 여부를 다시
검토한다.

## Debezium

`debezium/outbox-connector.json`은 Outbox 패턴 CDC 커넥터 설정 파일이다. 지금은 파일만
보관하는 단계이고, 실제 Kafka Connect에 등록하는 작업은 다음으로 미뤄뒀다.

## 참고 문서

- [docs/DEPLOYMENT.md](./docs/DEPLOYMENT.md) — 배포 관련 문서 (fbrl-backend 레포에서 동기화)
- [docs/ROADMAP.md](./docs/ROADMAP.md) — 인프라 로드맵 (작성 예정)

## 다음 할 일 (TODO)

- [ ] Redis/Kafka 인증 경로 추가 필요 (현재 docker-compose 구성에는 인증이 없음)
- [ ] Kafka 재시도/DLT 토픽 replication factor=1 → 실제 배포 시 조정 필요
- [ ] ShedLock 네임스페이스가 `fbrl-backend`로 하드코딩되어 있음 → staging/prod 환경 분리 필요
