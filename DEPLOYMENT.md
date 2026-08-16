# DEPLOYMENT

이 문서(특히 아래 표)는 배포 담당자에게 그대로 전달 가능한 계약입니다. 여기 없는 값은 애플리케이션 기본값(로컬 개발 기준)이 그대로 쓰인다는 뜻이며, 프로덕션에서 그게 맞는지는 이 표를 기준으로 판단하면 됩니다.

배포 대상 클라우드(Azure)의 구체적인 서비스 구성은 인프라 팀과 아직 미정이지만, 애플리케이션 쪽은 어떤 배포 방식이든 **환경변수 주입만으로 동작**하도록 맞춰져 있습니다. 이 문서는 배포 준비도 감사(설정 외부화 전수 조사, loud/silent 판정 기준 명시본)의 카테고리 1-4("체크리스트 문서 부재")를 채우기 위해 작성됐습니다.

## 환경변수 표기 규칙 확인

Spring Boot의 환경변수 relaxed binding은 `.`과 `-` 둘 다 단어 경계로 보고 `_`로 치환합니다. 예: `k8s.leader-election.namespace` → `K8S_LEADER_ELECTION_NAMESPACE`. 이 문서 작성 중 이 매핑 규칙을 실제로 스파이크 테스트로 검증했습니다(`K8S_LEADER_ELECTION_NAMESPACE`, `K8S_LEADERELECTION_NAMESPACE` 둘 다 정상 매핑되는 것까지 확인 — Boot가 두 형태 모두 별칭으로 인식). 아래 표는 Spring 공식 문서가 권장하는 표준 표기(하이픈→언더스코어)를 사용합니다.

## "loud" / "silent" 판정 기준

배포 준비도 감사 2차본에서 정의한 기준을 그대로 씁니다 — 이 값을 프로덕션에서 안 건드리고 배포했을 때:

- **loud**: 앱이 기동에 실패해 그 자리에서 드러남(배포가 막힘, 알아채기 쉬움)
- **silent**: 앱은 정상 기동하고, 잘못된 동작이 조용히 누적됨(알아채기 어려움 — 더 위험)
- **N/A**: 값이 틀려도 앱 동작 자체엔 영향 없음(업무 정책값이거나, 조건부로 비활성화된 기능)

## 필수 환경변수 체크리스트

| 환경변수명 | 대응 Spring 프로퍼티 | 기본값(로컬) | 필수 여부(프로덕션) | 실패 시 동작 | 설명 |
|---|---|---|---|---|---|
| `SPRING_DATASOURCE_URL` | `spring.datasource.url` | `jdbc:postgresql://localhost:5432/fbrl_db` | **필수** | loud | HikariCP가 기동 시 커넥션 풀 초기화 과정에서 실제 연결을 시도 — 실패하면 애플리케이션 컨텍스트 자체가 뜨지 않음 |
| `SPRING_DATASOURCE_USERNAME` | `spring.datasource.username` | `fbrl_user` | **필수** | loud | 상동 |
| `SPRING_DATASOURCE_PASSWORD` | `spring.datasource.password` | `fbrlpassword` | **필수** | loud | 로컬 기본값은 docker-compose 시드값과 동일한 더미 — 프로덕션에서 반드시 실제 값으로 교체. 안 바꾸면 인증 실패로 기동 자체가 안 됨(loud) |
| `SPRING_JPA_HIBERNATE_DDL_AUTO` | `spring.jpa.hibernate.ddl-auto` | `validate`(2026-08-16 이번 변경으로 기본값 자체가 안전해짐) | 프로덕션 필수 아님 | (이번 수정 전) silent → (이번 수정 후) 안전 | 예전엔 기본값이 `update`라 안 건드려도 매 기동마다 조용히 스키마를 변경하는 것이 Critical 리스크였음. 기본값을 `validate`로 바꿔 프로덕션에서 이 값을 아예 신경 쓰지 않아도 스키마를 건드리지 않도록 함. **`update`로 절대 덮어쓰지 말 것**(마이그레이션 도구 도입 전까지) |
| `SPRING_DATA_REDIS_HOST` | `spring.data.redis.host` | `localhost` | **필수** | loud로 추정(미검증) | Redisson이 기동 시 실제 연결을 시도하는 것으로 일반적으로 알려져 있음. 이 코드베이스에서 직접 재현 검증한 것은 아님 |
| `SPRING_DATA_REDIS_PORT` | `spring.data.redis.port` | `6379` | **필수** | loud로 추정(미검증) | 상동 |
| `SPRING_KAFKA_BOOTSTRAP_SERVERS` | `spring.kafka.bootstrap-servers` | `localhost:9092` | **필수** | **미확정(loud/silent 둘 다 가능성 있음)** | Kafka Producer는 일반적으로 lazy 연결이라, 이 값이 틀리거나 없어도 앱이 정상 기동하고 이벤트 발행만 조용히 실패할 가능성이 있음(미검증). **배포 후 반드시 실제 이체 1건을 발행해 `transfer-events` 토픽 수신을 직접 확인할 것.** |
| `MANAGEMENT_OPENTELEMETRY_TRACING_EXPORT_OTLP_ENDPOINT` | `management.opentelemetry.tracing.export.otlp.endpoint` | `http://localhost:4318/v1/traces`(로컬 Jaeger) | 인프라 협의 대기 중 | silent | 배포 환경 OTLP Collector 엔드포인트가 아직 미정(PROGRESS.md에 이미 기록된 상태 그대로) — 안 바꾸면 트레이스 export만 조용히 실패, 앱 기능에는 영향 없음 |
| `APPROVAL_THRESHOLD` | `approval.threshold` | `10000000` | 필수 아님(업무 정책값) | N/A | Maker-Checker 승인이 필요해지는 금액 기준. 값이 틀려도 앱은 정상 동작, 업무 정책만 달라짐 |
| `FRAUD_THRESHOLD` | `fraud.threshold` | `50000000` | 필수 아님(업무 정책값) | N/A | 이상거래 탐지 임계치. 상동 |
| `EOD_BATCH_CRON` | `eod.batch.cron` | `"0 0 2 * * *"` | 필수 아님 | N/A | EOD 정산 배치 트리거 시각. 스테이징/프로덕션에서 다른 시각이 필요하면 이 값만 바꾸면 됨 |
| `RECONCILIATION_BATCH_CRON` | `reconciliation.batch.cron` | `"0 0 3 * * *"` | 필수 아님 | N/A | 정산 대사 배치 트리거 시각. EOD 이후 시각으로 유지할 것 |
| `K8S_LEADER_ELECTION_ENABLED` | `k8s.leader-election.enabled` | `false` | 필수 아님 | N/A | **Azure로 갈 경우 기본값 `false` 유지 권장** — K8s Lease API 기반 리더 선출은 실제 K8s 클러스터 환경(kind/AKS 등)이 전제. Azure 배포 대상이 확정되지 않은 현재는 건드리지 말 것 |
| `K8S_LEADER_ELECTION_NAMESPACE` | `k8s.leader-election.namespace` | `default` | 필수 아님 | N/A(`enabled=false`면 미사용) | `ENABLED=true`로 켤 때만 의미 있음 |
| `K8S_LEADER_ELECTION_LEASE_NAME` | `k8s.leader-election.lease-name` | `eod-settlement-leader` | 필수 아님 | N/A(`enabled=false`면 미사용) | 상동 |
| `K8S_LEADER_ELECTION_LEASE_DURATION_SECONDS` | `k8s.leader-election.lease-duration-seconds` | `15` | 필수 아님 | N/A(`enabled=false`면 미사용) | 상동 |
| `K8S_LEADER_ELECTION_RENEW_DEADLINE_SECONDS` | `k8s.leader-election.renew-deadline-seconds` | `10` | 필수 아님 | N/A(`enabled=false`면 미사용) | 상동 |
| `K8S_LEADER_ELECTION_RETRY_PERIOD_SECONDS` | `k8s.leader-election.retry-period-seconds` | `2` | 필수 아님 | N/A(`enabled=false`면 미사용) | 상동 |

## 인프라 팀과 협의 필요한 별도 항목

아래는 코드 수정 없이, 배포 준비도 감사에서 확인된 사실만 그대로 옮긴 목록입니다.

- **Redis/Kafka 인증 경로 부재** — `RedissonConfig`/`KafkaProducerConfig`에 password/SASL 설정 필드 자체가 없음. Azure Cache for Redis, Event Hubs(또는 Azure 상의 Kafka 호환 서비스) 등 실제 대상이 정해지면 인증 설정 코드를 추가해야 함.
- **Kafka 재시도/DLT 토픽 replication factor=1** — 단일 장애점. 실제 브로커 구성(파티션/복제본 수)이 정해지면 그에 맞게 조정 필요.
- **ShedLock 네임스페이스 하드코딩** — `ENVIRONMENT="fbrl-backend"`로 고정돼 있어, staging/prod가 같은 Redis를 공유하면 분산 락 키가 충돌할 수 있음. 환경별로 분리 필요.
