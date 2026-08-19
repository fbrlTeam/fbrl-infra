# k3s-manifests

`docker-compose.yml`의 `kafka`, `kafka-connect`만 k3s로 옮긴 매니페스트다.
Postgres/Redis는 이제 Azure 관리형 서비스라 여기 포함하지 않는다.

## 파일

- `kafka.yaml` — Kafka(KRaft 단일 노드) Deployment + Service + PVC
- `kafka-connect.yaml` — Kafka Connect(Debezium) Deployment + Service
- `postgres-secret.template.yaml` — **템플릿일 뿐, 그대로 apply하지 않는다.**
  실제 Secret은 아래 순서대로 imperative하게 생성한다.

## 배포 순서

```bash
# 1. Postgres 비밀번호를 담은 Secret을 먼저 생성 (평문을 어떤 파일에도 남기지 않음)
kubectl create secret generic kafka-connect-postgres-secret \
  --from-literal=postgres-password='<terraform.tfvars의 postgres_admin_password 값>'

# 2. Kafka, Kafka Connect 배포
kubectl apply -f kafka.yaml
kubectl apply -f kafka-connect.yaml

# 3. Pod 상태 확인
kubectl get pods
```

## Debezium 커넥터 등록

`debezium/outbox-connector-main.json`, `debezium/outbox-connector-demo.json`의
`database.password`는 `${POSTGRES_PASSWORD}` placeholder로 되어 있다. 등록 시점에
Secret에서 실제 값을 읽어와 그 자리만 치환해서 REST API로 보내고, 치환된 결과는
디스크에 저장하지 않는다:

```bash
PGPASS=$(kubectl get secret kafka-connect-postgres-secret -o jsonpath='{.data.postgres-password}' | base64 -d)
sed "s|\${POSTGRES_PASSWORD}|$PGPASS|" outbox-connector-main.json | \
  curl -X POST -H "Content-Type: application/json" --data @- http://kafka-connect:8083/connectors
unset PGPASS
```

## 알려진 제약

- `database.dbname`(`fbrl_db`/`fbrl_demo_db`)이 가리키는 데이터베이스가 Azure
  Postgres 서버에 아직 없다 — Terraform은 서버(인스턴스)만 만들었고 데이터베이스/
  테이블은 `fbrl-backend` 앱이 마이그레이션을 돌려야 생긴다. 그 전까지 커넥터
  등록 자체(REST 요청)는 성공해도 태스크는 연결 실패로 FAILED 상태일 수 있다 —
  로컬 docker-compose 때와 같은 종류의 "당연한 실패"다.
