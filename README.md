# 커넥터 라인 증설 · 공통 실행관리 v2

기존 엑셀/단일 HTML 보고서를 **여러 담당자가 동시에 보는 공동 실행관리 화면**으로 확장한 GitHub Pages용 정적 웹앱입니다.

## 핵심 기능
- 원본 엑셀 기준 33개 실행 항목 유지
- 업무 분야 / 공정 / 담당자 / 상태 필터
- 상태: 미착수 / 진행중 / 확인·검토 / 차단·지원필요 / 완료
- 0~100% 진행률, 담당자, 팀, 완료예정일, 우선순위 수정
- 항목별 짧은 메모 오버레이
- 수정자·수정시간·변경 전/후 값 로그
- Supabase Realtime으로 다른 PC/모바일에 변경사항 동기화
- Supabase 미설정 시 LocalStorage 데모모드로 동작

## 권장 구조
`GitHub Pages (정적 UI) → Supabase Auth → PostgreSQL + RLS → Realtime`

GitHub Pages에는 서버와 DB가 없으므로 공용 저장은 외부 DB가 필요합니다. 이 프로젝트는 Supabase를 기본안으로 사용합니다. 브라우저에 들어가는 publishable/anon key는 공개용이며, 실제 접근권한은 RLS 정책으로 제한합니다.

## 설치
1. Supabase 프로젝트 생성
2. SQL Editor에서 `supabase/schema.sql` 실행
3. 이어서 `supabase/seed.sql` 실행
4. Authentication > Users에서 현장 담당자 이메일 계정 생성
5. `config.js`에 Project URL과 Publishable/Anon Key 입력
6. 이 폴더 전체를 GitHub `royv` 저장소 main 브랜치에 업로드
7. Settings > Pages > Source를 **GitHub Actions**로 설정

## 파일 구조
```text
index.html
config.js
assets/
  app.css
  app.js
  images/        # 기존 페이지의 제품 사진 40개
data/tasks.json  # 엑셀 기반 원본/오프라인 데이터
supabase/
  schema.sql     # 테이블, 로그 trigger, RLS, Realtime
  seed.sql       # 33개 실행 항목 초기값
.github/workflows/deploy.yml
```

## 운영 권장사항
- 일반 담당자: 상태/진행률/담당/메모 수정
- 관리자: Supabase Dashboard에서 사용자 계정 추가/삭제
- 더 엄격한 권한이 필요하면 `profiles.role`을 추가해 관리자/일반 사용자 RLS를 분리
- 완료된 항목도 삭제하지 말고 상태만 완료로 유지해 로그 추적성을 보존

## 기존 데이터와의 관계
엑셀 4개 시트(SMWORLD, Roy, 공정별 필요부품, 총 필요량) 및 기존 HTML의 실행 분류 데이터를 기준으로 초기 데이터를 만들었습니다. 원본 엑셀 자체는 변경하지 않습니다.
