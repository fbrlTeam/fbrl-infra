# deployment-evidence/images — 캡처 목록

## 자동 캡처 완료

| 파일명 | 내용 |
|---|---|
| `kafka-connect-status-k3s.png` | k3s 위 Kafka Connect의 `/connectors?expand=status` 응답. `fbrl-outbox-connector`, `fbrl-outbox-connector-demo` 둘 다 `connector.state`/`tasks[0].state` 모두 `RUNNING`인 것을 확인할 수 있음. SSH 로컬 포트포워딩(`localhost:18083` → VM의 kafka-connect ClusterIP:8083) 경유로 Chrome headless 캡처. |

k3s Pod 목록은 텍스트가 더 명확해서 스크린샷 대신 `../10-k3s-pods-status.txt`로 저장함
(`sudo k3s kubectl get pods -o wide` 결과 — `fbrl-backend`/`kafka`/`kafka-connect` 3개 모두
`1/1 Running`).

## 자동 캡처 실패 — Azure 포털 (로그인 필요)

Chrome headless는 별도 프로필이라 로그인 세션이 없어서, Azure 포털 URL을 열면 로그인
리다이렉트 화면에서 멈추고 스크린샷 파일 자체가 생성되지 않았다(타임아웃). Azure 포털은
MFA/디바이스 인증이 걸려있어 자동화로 우회하는 게 애초에 부적절하기도 하다.

**아래 3개는 직접 로그인한 브라우저에서 `Win+Shift+S`로 캡처해서 이 폴더
(`docs/deployment-evidence/images/`)에 넣어주면 된다.** 파일명은 아래 제안대로 맞추면
README 갱신 없이 바로 정리됨:

| 제안 파일명 | 캡처할 화면 | 경로 힌트 |
|---|---|---|
| `azure-portal-postgres-main-overview.png` | Postgres 서버 `fbrl-postgres-main`의 개요(Overview) 화면 | 포털 → 리소스 그룹 `fbrl-dev-rg` → `fbrl-postgres-main` |
| `azure-portal-postgres-active-connections.png` | `fbrl-postgres-main`의 메트릭 — Active Connections 그래프(8→15로 튀는 구간 포함) | 위 리소스 → 왼쪽 메뉴 Monitoring → Metrics → Active Connections 선택 |
| `azure-portal-acr-overview.png` | ACR `fbrlacr`의 개요 화면 + 리포지토리(`fbrl-backend`) 목록이 보이는 화면 | 포털 → `fbrl-dev-rg` → `fbrlacr` → Overview 또는 Repositories |

캡처 후 이 표의 "제안 파일명" 그대로 저장해서 넣어주면 정리 끝.
