# PROGRESS

fbrl-infra 작업 일지. 날짜별로 뭘 했는지, 왜 그렇게 했는지, 캡처 화면을 기록한다.
형식은 farmer0010/fbrl-backend의 PROGRESS.md를 참고했다.

## 2026-08-17

- fbrl-infra 레포를 fbrlTeam 오가니제이션으로 이전함
- 로컬 docker-compose 환경(postgres/redis/kafka/kafka-connect/jaeger) 검증 완료
- docs/ROADMAP.md, terraform/README.md 작성

### Debezium 커넥터 등록 테스트

커넥터를 등록하고 상태를 확인했다.

```
$ curl -X POST -H "Content-Type: application/json" \
    --data @debezium/outbox-connector.json \
    http://localhost:8083/connectors

{"name":"fbrl-outbox-connector","config":{"connector.class":"io.debezium.connector.postgresql.PostgresConnector","database.hostname":"postgres","database.port":"5432","database.user":"fbrl_user","database.password":"fbrlpassword","database.dbname":"fbrl_db","topic.prefix":"fbrl","table.include.list":"public.outbox_event","plugin.name":"pgoutput","slot.name":"fbrl_outbox_slot","publication.autocreate.mode":"filtered","tombstones.on.delete":"false","key.converter":"org.apache.kafka.connect.storage.StringConverter","value.converter":"org.apache.kafka.connect.storage.StringConverter","transforms":"outbox","transforms.outbox.type":"io.debezium.transforms.outbox.EventRouter","transforms.outbox.table.field.event.id":"id","transforms.outbox.route.by.field":"aggregate_type","transforms.outbox.table.field.event.key":"aggregate_id","transforms.outbox.table.field.event.type":"event_type","transforms.outbox.table.field.event.payload":"payload","transforms.outbox.route.topic.replacement":"transfer-events","transforms.outbox.table.fields.additional.placement":"trace_id:header:trace_id,span_id:header:span_id","name":"fbrl-outbox-connector"},"tasks":[],"type":"source"}
HTTP_STATUS:201
```

```
$ curl http://localhost:8083/connectors/fbrl-outbox-connector/status

{"name":"fbrl-outbox-connector","connector":{"state":"RUNNING","worker_id":"172.19.0.6:8083"},"tasks":[{"id":0,"state":"FAILED","worker_id":"172.19.0.6:8083","trace":"org.apache.kafka.connect.errors.ConnectException: Unable to create filtered publication dbz_publication for \n\t...\nCaused by: io.debezium.DebeziumException: No table filters found for filtered publication dbz_publication\n\t..."}],"type":"source"}
HTTP_STATUS:200
```

커넥터 자체 등록(REST API 요청)은 `201 Created`로 성공했지만, 실제 태스크는 `FAILED` 상태다.
에러 메시지는 `table.include.list`(`public.outbox_event`)에 해당하는 테이블을 찾을 수 없어
filtered publication을 만들 수 없다는 내용이다. `docker exec fbrl-postgres psql -U fbrl_user
-d fbrl_db -c "\dt"`로 직접 확인해보니 `fbrl_db`에 테이블이 하나도 없었다 — 이 레포에는
인프라 설정만 있고 `fbrl-backend`의 애플리케이션 코드(스키마 마이그레이션 포함)가 없으니
`outbox_event` 테이블이 애초에 만들어질 수 없는 상황이다. 즉 Debezium 설정 자체의 문제라기보다
로컬에 백엔드 앱을 띄워 마이그레이션을 돌리기 전까지는 당연히 나는 실패다.

스크린샷: ![Jaeger UI](images/jaeger-ui-check.png), ![Kafka Connect 상태](images/kafka-connect-status.png)

## 2026-08-19

### 장애 대응 카오스 테스트 3종 요약

`fbrl-backend`를 로컬에 clone해서 실제로 띄운 뒤, 인프라/애플리케이션 장애 시나리오 3개를
검증했다. 상세 로그와 SQL 결과는 `docs/chaos-evidence/`(gitignore 대상, 로컬 전용) 아래
시나리오별 폴더에 남겨뒀다.

- **시나리오 1 — Kafka 다운 (`chaos-evidence/scenario1-kafka-down/`)**: Kafka 브로커를
  `docker stop`으로 강제 종료했다가 복구. 브로커 자체는 22초 만에 healthy로 돌아오지만,
  Kafka Connect 커넥터가 다시 `RUNNING`이 되기까지는 리밸런스 지연(`rebalance delay:
  300000`, 기본 5분) 때문에 **5분 14초**가 걸렸다. 브로커 복구와 CDC 파이프라인 정상화
  사이에 체감 갭이 크다는 게 핵심 발견.
- **시나리오 2 — Saga 보상 트랜잭션 (`chaos-evidence/scenario2-saga-compensation/`)**: 실제
  `/api/v1/transfers` API는 원자적 트랜잭션이라 "출금 성공, 입금 실패" 상황 자체가 재현이
  안 됐다. `TransferSagaOrchestrator`(별도로 존재하지만 어떤 컨트롤러에도 안 붙어있는 코드)를
  직접 호출하는 임시 통합 테스트로 검증한 결과, **실제 버그를 발견**했다 —
  `sagaStateWriter.save(saga)` 호출 시 반환값(갱신된 id)을 버리고 원래 객체를 계속 써서,
  두 번째 저장부터 매번 INSERT를 시도해 `saga_id` unique 제약 위반으로 크래시한다. 그
  결과 출금은 실제로 커밋되는데 보상 트랜잭션은 시도조차 못 해보고 죽는다. 테스트 코드는
  백업만 해두고 실제 수정은 하지 않음(백엔드팀 소관).
- **시나리오 3 — EOD 배치 강제종료 후 재개 (`chaos-evidence/scenario3-eod-batch/`)**: 계좌
  5000개로 배치를 돌리다 4000건(80%) 처리 시점에 프로세스를 `kill -9`. 단순 재시작은
  `JobExecutionAlreadyRunningException`으로 막혔고, Spring Batch 공식 API인
  `JobOperator.abandon()`도 `STARTED` 상태 실행은 회수 못 해서 거부됐다. **운영자가 DB에
  직접 들어가 orphaned 실행을 `FAILED`로 수동 UPDATE해야만 재개 가능** — 그 후 재시작하니
  나머지 1000건만 이어서 처리하고(처음부터 다시 안 돎) 9초 만에 완료. 최종적으로
  `eod_snapshots` 5000건, 계좌당 중복 0건, 누락 0건으로 확인.
