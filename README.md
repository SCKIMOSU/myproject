# Django 1만 동접 프로젝트 — 전체 코드 상세 설명

---

## 파일 구조 전체 맵

```
myproject/
├── manage.py                    ← Django 관리 명령어 실행기
├── gunicorn.conf.py             ← 앱 서버 설정
├── locustfile.py                ← 부하 테스트 시나리오
├── requirements.txt             ← 패키지 목록
├── .env                         ← 환경변수 (비밀번호 등)
├── config/                      ← 프로젝트 설정
│   ├── __init__.py              ← Celery 앱 등록
│   ├── asgi.py                  ← 비동기 서버 진입점
│   ├── celery.py                ← Celery 설정
│   ├── db_router.py             ← 읽기/쓰기 DB 분리
│   ├── urls.py                  ← URL → 뷰 매핑
│   └── settings/
│       ├── __init__.py          ← 빈 파일
│       ├── base.py              ← 공통 설정
│       ├── development.py       ← 개발 환경
│       └── production.py        ← 프로덕션 환경
├── core/                        ← 앱 코드
│   ├── models.py                ← DB 모델
│   ├── views.py                 ← API 뷰
│   ├── tasks.py                 ← 비동기 작업
│   └── admin.py                 ← 관리자 페이지
├── staticfiles/                 ← Nginx가 서빙하는 정적 파일
└── /etc/nginx/nginx.conf        ← Nginx 설정 (시스템 경로)
```

---

## 1. config/settings/base.py — 공통 설정

모든 환경(개발/프로덕션)에서 공유하는 기본 설정입니다.

```python
import os
from pathlib import Path

# ── 경로 설정 ──
# __file__ = config/settings/base.py
# .parent   = config/settings/
# .parent   = config/
# .parent   = myproject/    ← BASE_DIR
BASE_DIR = Path(__file__).resolve().parent.parent.parent
```

**왜 이렇게 하는가**: Django의 모든 경로(정적 파일, 템플릿, DB 파일 등)가 이 BASE_DIR을 기준으로 결정됩니다. `parent`를 3번 호출하는 이유는 settings가 `config/settings/` 폴더 안에 있기 때문입니다.

```python
# ── 보안 키 ──
SECRET_KEY = os.environ.get(
    "DJANGO_SECRET_KEY",
    "임시-개발용-키-프로덕션에서는-반드시-환경변수로-설정"
)
```

**SECRET_KEY의 역할**: 세션 암호화, CSRF 토큰 생성, 비밀번호 해싱에 사용됩니다. 이 키가 노출되면 세션을 위조할 수 있으므로 프로덕션에서는 반드시 환경변수로 관리합니다. `os.environ.get()`은 환경변수가 없으면 두 번째 인자(임시 키)를 사용합니다.

```python
# ── 설치된 앱 ──
INSTALLED_APPS = [
    # Django 기본 앱
    "django.contrib.admin",          # 관리자 페이지
    "django.contrib.auth",           # 사용자 인증 (로그인/로그아웃)
    "django.contrib.contenttypes",   # 모델 타입 관리
    "django.contrib.sessions",       # 세션 관리
    "django.contrib.messages",       # 알림 메시지
    "django.contrib.staticfiles",    # 정적 파일 관리

    # 서드파티 앱
    "corsheaders",                   # 다른 도메인에서 API 호출 허용
    "health_check",                  # /health/ 엔드포인트 제공
    "health_check.db",               # DB 상태 체크
    "health_check.cache",            # 캐시 상태 체크

    # 우리 앱
    "core",                          # 게시판 기능 (모델, 뷰, 태스크)
]
```

**왜 이 순서인가**: Django 기본 → 서드파티 → 우리 앱 순서가 관례입니다. 일부 앱은 다른 앱에 의존하므로 순서가 중요할 수 있습니다.

```python
# ── 미들웨어 ──
MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",      # 1. 보안 헤더 (맨 위!)
    "whitenoise.middleware.WhiteNoiseMiddleware",          # 2. 정적 파일 서빙
    "corsheaders.middleware.CorsMiddleware",               # 3. CORS 처리
    "django.contrib.sessions.middleware.SessionMiddleware",# 4. 세션 처리
    "django.middleware.common.CommonMiddleware",           # 5. URL 정규화
    "django.middleware.csrf.CsrfViewMiddleware",           # 6. CSRF 보호
    "django.contrib.auth.middleware.AuthenticationMiddleware", # 7. 사용자 인증
    "django.contrib.messages.middleware.MessageMiddleware",    # 8. 메시지
    "django.middleware.clickjacking.XFrameOptionsMiddleware",  # 9. 클릭재킹 방어
]
```

**미들웨어란**: 모든 요청이 뷰에 도달하기 전에 거치는 "검문소"입니다. 위에서 아래로 순서대로 실행됩니다. SecurityMiddleware가 맨 위인 이유는 보안 헤더를 가장 먼저 적용해야 하기 때문입니다.

```
요청 → Security → WhiteNoise → CORS → Session → ... → 뷰
응답 ← Security ← WhiteNoise ← CORS ← Session ← ... ← 뷰
```

```python
ASGI_APPLICATION = "config.asgi.application"
```

**WSGI 대신 ASGI를 쓰는 이유**: ASGI가 비동기 처리를 지원하여 같은 워커로 더 많은 요청을 동시에 처리할 수 있습니다.

```python
STATIC_URL = "/static/"                    # URL 경로
STATIC_ROOT = BASE_DIR / "staticfiles"     # collectstatic 결과 저장 위치
STATICFILES_DIRS = [BASE_DIR / "static"]   # 개발 중 정적 파일 원본 위치
```

**3가지 정적 파일 설정의 차이**:
- `STATIC_URL`: 브라우저에서 접근하는 URL 경로 (예: /static/css/style.css)
- `STATICFILES_DIRS`: 개발 중 원본 파일이 있는 폴더
- `STATIC_ROOT`: `collectstatic` 명령으로 모든 정적 파일을 모아놓는 폴더 (Nginx가 서빙)

---

## 2. config/settings/development.py — 개발 환경

```python
from .base import *  # base.py의 모든 설정을 가져옴

DEBUG = True              # 에러 발생 시 상세 정보 표시 (개발 편의)
ALLOWED_HOSTS = ["*"]     # 모든 호스트에서 접속 허용 (개발용)
```

**`from .base import *`의 의미**: base.py에서 정의한 모든 변수를 이 파일로 가져옵니다. 여기서 같은 이름으로 다시 정의하면 덮어씌워집니다 (override).

```python
DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.sqlite3",  # SQLite 사용
        "NAME": BASE_DIR / "db.sqlite3",          # 파일 1개로 DB 전체
    }
}
```

**왜 개발에서 SQLite를 쓰는가**: 설치가 필요 없고 파일 1개로 동작합니다. PostgreSQL을 설치/설정할 필요 없이 바로 개발할 수 있습니다. 단, 동시 쓰기가 불가능하므로 프로덕션에서는 사용하면 안 됩니다.

```python
CACHES = {
    "default": {
        "BACKEND": "django.core.cache.backends.locmem.LocMemCache",
    }
}
```

**LocMemCache**: Django 프로세스 메모리 안에 캐시를 저장합니다. Redis 없이도 캐시 코드가 동작하므로 개발 중 편리합니다. 서버를 재시작하면 캐시가 사라집니다.

---

## 3. config/settings/production.py — 프로덕션 환경

```python
import os
from .base import *

DEBUG = False
ALLOWED_HOSTS = os.environ.get("ALLOWED_HOSTS", "").split(",")
```

**DEBUG = False가 필수인 이유**: True이면 에러 시 소스 코드, DB 정보, 환경변수가 사용자에게 노출됩니다.

**ALLOWED_HOSTS**: 이 서버에 접속할 수 있는 도메인 목록입니다. `["*"]`이면 아무 도메인에서나 접속 가능 (보안 취약), 프로덕션에서는 실제 도메인만 허용합니다.

```python
DATABASES = {
    "default": {                                    # Primary (쓰기용)
        "ENGINE": "django.db.backends.postgresql",
        "NAME": os.environ.get("DB_NAME", "mydb"),
        "USER": os.environ.get("DB_USER", "dbuser"),
        "PASSWORD": os.environ.get("DB_PASSWORD"),  # 환경변수에서 읽기
        "HOST": os.environ.get("DB_HOST", "localhost"),
        "PORT": os.environ.get("DB_PORT", "5432"),
        "CONN_MAX_AGE": 600,         # 커넥션을 10분간 재사용
        "CONN_HEALTH_CHECKS": True,  # 재사용 전 커넥션 상태 확인
    },
    "replica": {                     # Replica (읽기용)
        # ... (같은 구조, 다른 호스트/유저)
    },
}
DATABASE_ROUTERS = ["config.db_router.ReadReplicaRouter"]
```

**CONN_MAX_AGE = 600**: 기본값(0)이면 매 요청마다 DB 연결을 새로 만들고 끊습니다. 600이면 10분간 같은 연결을 재사용하여 연결 생성 오버헤드를 줄입니다.

**DATABASE_ROUTERS**: 읽기는 replica로, 쓰기는 default로 자동 라우팅하는 클래스를 지정합니다.

```python
CACHES = {
    "default": {
        "BACKEND": "django.core.cache.backends.redis.RedisCache",
        "LOCATION": os.environ.get("REDIS_URL", "redis://localhost:6379/0"),
        "OPTIONS": {
            "pool_class": "redis.ConnectionPool",
            "max_connections": 50,   # Redis 커넥션 풀 크기
        },
        "KEY_PREFIX": "dj",          # 키 충돌 방지 접두사
        "TIMEOUT": 300,              # 기본 캐시 만료 시간 (5분)
    }
}
```

**KEY_PREFIX = "dj"**: Redis를 다른 용도(세션, Celery)와 함께 쓸 때 키가 겹치지 않도록 접두사를 붙입니다. 예: `dj:post_list:page:1`

```python
SESSION_ENGINE = "django.contrib.sessions.backends.cache"
SESSION_CACHE_ALIAS = "default"
```

**세션을 Redis에 저장하는 이유**: Django 서버가 여러 대일 때, 어떤 서버로 가도 같은 Redis에서 세션을 읽으므로 로그인 상태가 유지됩니다. 기본값(DB 저장)이면 로그인할 때마다 DB 쿼리가 발생합니다.

---

## 4. config/__init__.py — Celery 등록

```python
from .celery import app as celery_app
__all__ = ("celery_app",)
```

**이 2줄의 역할**: Django가 시작될 때 Celery 앱도 함께 초기화됩니다. 이것이 없으면 `@shared_task`로 정의한 비동기 작업이 자동으로 발견되지 않습니다.

---

## 5. config/asgi.py — 비동기 서버 진입점

```python
import os
from django.core.asgi import get_asgi_application

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings.production")
application = get_asgi_application()
```

**이 파일의 역할**: Gunicorn이 `config.asgi:application`을 참조하여 Django 앱을 로드합니다. WSGI(wsgi.py) 대신 ASGI를 사용하면 비동기 처리가 가능합니다.

**실행 흐름**:
```
Gunicorn 시작
  → config.asgi 모듈 로드
  → os.environ에 DJANGO_SETTINGS_MODULE 설정
  → get_asgi_application()이 Django 앱 초기화
  → Uvicorn 워커가 이 application으로 요청 처리
```

---

## 6. config/celery.py — Celery 설정

```python
import os
from celery import Celery

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings.production")

app = Celery("config")
app.config_from_object("django.conf:settings", namespace="CELERY")
app.autodiscover_tasks()
```

**한 줄씩 설명**:
- `Celery("config")`: "config"라는 이름의 Celery 앱을 생성합니다.
- `config_from_object(...)`: Django settings에서 `CELERY_`로 시작하는 설정을 자동으로 읽습니다 (예: `CELERY_BROKER_URL`).
- `autodiscover_tasks()`: 모든 앱의 `tasks.py`를 자동으로 찾아서 등록합니다. 우리 프로젝트에서는 `core/tasks.py`를 찾습니다.

---

## 7. config/db_router.py — 읽기/쓰기 분리

```python
class ReadReplicaRouter:
    def db_for_read(self, model, **hints):
        return "replica"        # 모든 SELECT → replica DB

    def db_for_write(self, model, **hints):
        return "default"        # 모든 INSERT/UPDATE/DELETE → primary DB

    def allow_relation(self, obj1, obj2, **hints):
        return True             # 두 DB 간의 관계(FK) 허용

    def allow_migrate(self, db, app_label, model_name=None, **hints):
        return db == "default"  # 마이그레이션은 primary에서만
```

**Django가 이 라우터를 사용하는 방식**:
```python
Post.objects.all()              # db_for_read() 호출 → "replica"
Post.objects.create(title=...)  # db_for_write() 호출 → "default"
post.save()                     # db_for_write() 호출 → "default"
```

**allow_migrate가 "default"만 반환하는 이유**: 테이블 생성/변경(마이그레이션)은 Primary에서만 실행하고, Replica는 Primary의 변경사항을 자동으로 복제받습니다.

---

## 8. config/urls.py — URL 라우팅

```python
from django.contrib import admin
from django.urls import path
from core.views import post_list, category_list, post_detail, health_check

urlpatterns = [
    path("admin/", admin.site.urls),                   # /admin/
    path("health/", health_check),                      # /health/
    path("api/posts/", post_list),                      # /api/posts/
    path("api/posts/<slug:slug>/", post_detail),        # /api/posts/hello-world/
    path("api/categories/", category_list),             # /api/categories/
]
```

**`<slug:slug>`의 의미**: URL에서 문자열을 변수로 받습니다. 예: `/api/posts/hello-world/` → `slug="hello-world"`가 `post_detail(request, slug)` 함수에 전달됩니다.

---

## 9. core/models.py — DB 모델

```python
class Post(models.Model):
    title = models.CharField(max_length=200)          # 문자열 (최대 200자)
    slug = models.SlugField(unique=True)               # URL용 문자열 (고유)
    content = models.TextField()                       # 긴 텍스트
    author = models.ForeignKey(User, on_delete=models.CASCADE)  # FK → User
    category = models.ForeignKey(
        Category, on_delete=models.CASCADE, related_name="posts"
    )                                                  # FK → Category
    tags = models.ManyToManyField(Tag, blank=True)     # M2M → Tag
    view_count = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)  # 생성 시 자동 기록
    updated_at = models.DateTimeField(auto_now=True)      # 수정 시 자동 갱신
```

**각 필드 타입과 DB 컬럼 매핑**:

| Django 필드 | PostgreSQL 컬럼 | 설명 |
|-------------|----------------|------|
| CharField(max_length=200) | VARCHAR(200) | 짧은 문자열 |
| TextField() | TEXT | 긴 문자열 (제한 없음) |
| SlugField(unique=True) | VARCHAR(50) UNIQUE | URL용 문자열 |
| ForeignKey | INTEGER + FK 제약 | 다른 테이블 참조 |
| ManyToManyField | 중간 테이블 자동 생성 | N:M 관계 |
| auto_now_add=True | TIMESTAMP DEFAULT NOW() | 생성 시 자동 |

**on_delete=CASCADE**: 참조된 객체(User)가 삭제되면 이 객체(Post)도 함께 삭제됩니다.

**related_name="posts"**: Category에서 역참조할 때 사용합니다: `category.posts.all()` → 이 카테고리의 모든 게시글

---

## 10. core/views.py — API 뷰

### post_list: 캐시 + N+1 제거의 실전 적용

```python
def post_list(request):
    page = int(request.GET.get("page", 1))    # ?page=2 → page=2
    cache_key = f"post_list:page:{page}"       # 페이지별 캐시 키

    data = cache.get(cache_key)                # ① Redis에서 캐시 확인

    if data is None:                            # ② 캐시 미스
        per_page = 20
        offset = (page - 1) * per_page          # 페이지 2 → offset 20

        posts = (
            Post.objects
            .select_related("author", "category")   # FK를 JOIN으로
            .prefetch_related("tags")                # M2M을 IN절로
            .annotate(comment_count=Count("comments"))  # 댓글 수 집계
            .only("id", "title", "slug", "created_at",  # 필요한 컬럼만
                  "author__username", "category__name")
            .order_by("-created_at")                 # 최신순 정렬
            [offset:offset + per_page]               # 슬라이싱 = LIMIT/OFFSET
        )
```

**QuerySet 체인의 실행 순서**:
```sql
-- 위 코드가 생성하는 SQL (대략적)
SELECT post.id, post.title, post.slug, post.created_at,
       user.username, category.name,
       COUNT(comment.id) AS comment_count
FROM post
JOIN user ON post.author_id = user.id           -- select_related
JOIN category ON post.category_id = category.id -- select_related
LEFT JOIN comment ON comment.post_id = post.id  -- annotate
GROUP BY post.id
ORDER BY post.created_at DESC
LIMIT 20 OFFSET 0;

-- prefetch_related는 별도 쿼리:
SELECT * FROM tag
JOIN post_tags ON tag.id = post_tags.tag_id
WHERE post_tags.post_id IN (1, 2, 3, ..., 20);
```

**select_related vs prefetch_related**:
- `select_related`: SQL JOIN을 사용, FK(1:N) 관계에 적합. 쿼리 1번.
- `prefetch_related`: 별도 쿼리 + Python에서 조합, M2M 관계에 적합. 쿼리 2번.
- 둘 다 안 쓰면: 게시글 20개 × (author + category + tags) = 쿼리 61번 이상.

```python
        data = [
            {
                "id": post.id,
                "title": post.title,
                # ...
                "tags": [tag.name for tag in post.tags.all()],  # 추가 쿼리 없음!
            }
            for post in posts
        ]

        cache.set(cache_key, data, timeout=300)  # ③ Redis에 5분간 저장

    return JsonResponse({"posts": data, "page": page})  # ④ JSON 응답
```

**`post.tags.all()`이 추가 쿼리를 안 하는 이유**: `prefetch_related("tags")`로 미리 가져왔기 때문입니다. prefetch 없이 호출하면 게시글마다 쿼리가 발생합니다.

### health_check: 서버 상태 확인

```python
def health_check(request):
    health = {"status": "ok"}

    # DB 체크
    try:
        from django.db import connection
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")     # 가장 가벼운 쿼리
        health["database"] = "ok"
    except Exception as e:
        health["database"] = f"error: {e}"
        health["status"] = "error"

    # 캐시 체크
    try:
        cache.set("_health_check", "1", timeout=10)  # 쓰기 테스트
        if cache.get("_health_check") == "1":         # 읽기 테스트
            health["cache"] = "ok"
    except Exception as e:
        health["cache"] = f"error: {e}"
        health["status"] = "error"

    status_code = 200 if health["status"] == "ok" else 503
    return JsonResponse(health, status=status_code)
```

**503 상태 코드**: "Service Unavailable" — DB나 Redis가 다운되면 503을 반환하여, Nginx 헬스체크가 이 서버를 로드 밸런싱에서 제외합니다.

---

## 11. core/tasks.py — Celery 비동기 작업

```python
@shared_task(
    bind=True,              # self 파라미터 사용 가능
    max_retries=3,          # 최대 3번 재시도
    default_retry_delay=60, # 재시도 간격 60초
)
def send_notification_email(self, subject, recipient_list):
    try:
        send_mail(subject=subject, ...)
    except Exception as exc:
        raise self.retry(exc=exc)   # 실패 → 60초 후 재시도
```

**데코레이터 옵션 설명**:
- `@shared_task`: Celery 앱에 등록되는 비동기 작업으로 만듦
- `bind=True`: 함수의 첫 번째 인자로 `self`(작업 인스턴스)를 받음 → `self.retry()` 사용 가능
- `max_retries=3`: 3번 실패하면 포기 (무한 재시도 방지)
- `default_retry_delay=60`: 실패 후 60초 대기 후 재시도

**호출 방법**:
```python
# 동기 호출 (Celery 안 거침, 3초 대기)
send_notification_email("제목", ["user@example.com"])

# 비동기 호출 (Celery에 전달, 즉시 반환)
send_notification_email.delay("제목", ["user@example.com"])

# 5분 후 실행
send_notification_email.apply_async(
    args=["제목", ["user@example.com"]],
    countdown=300,
)
```

**`.delay()`가 호출되면 일어나는 일**:
```
views.py에서 .delay() 호출
  → 작업 메시지가 Redis(브로커)에 저장
  → views.py는 즉시 다음 코드 실행 (사용자에게 응답)
  → Celery 워커가 Redis에서 메시지를 꺼냄
  → 워커가 send_mail() 실행 (백그라운드)
  → 실패하면 60초 후 재시도 (최대 3번)
```

---

## 12. gunicorn.conf.py — 앱 서버 설정

```python
import multiprocessing

bind = "0.0.0.0:8000"                          # 모든 IP에서 8000 포트로 수신
workers = 2                                     # 워커 프로세스 수 (노트북용)
worker_class = "uvicorn.workers.UvicornWorker"  # 비동기 ASGI 워커
worker_connections = 100                         # 워커당 동시 연결 수
max_requests = 1000           # 1000번 처리 후 워커 재시작 (메모리 누수 방지)
max_requests_jitter = 100     # 랜덤 오차 (동시 재시작 방지)
timeout = 30                  # 30초 안에 응답 못 하면 강제 종료
keepalive = 5                 # Nginx와의 연결 유지 시간
preload_app = True            # 마스터에서 앱 미리 로드 (메모리 공유)
```

**Gunicorn 프로세스 구조**:
```
Gunicorn Master (PID 1000)          ← 트래픽 처리 안 함, 워커만 관리
  ├── Uvicorn Worker 1 (PID 1001)   ← 실제 요청 처리
  └── Uvicorn Worker 2 (PID 1002)   ← 실제 요청 처리
```

**preload_app = True**: Master가 Django 앱을 한 번 로드하고, 워커들이 이 메모리를 공유(Copy-on-Write)합니다. 워커별로 각각 로드하는 것보다 메모리를 절약합니다.

**max_requests = 1000**: Python은 메모리 누수가 발생할 수 있습니다. 1000번 요청을 처리한 워커를 자동으로 재시작하면 메모리가 깨끗해집니다. `jitter=100`은 900~1100 사이 랜덤 값으로 재시작 시점을 분산시켜, 모든 워커가 동시에 재시작하는 것을 방지합니다.

---

## 13. nginx.conf — 리버스 프록시

```nginx
worker_processes 2;             # Nginx 워커 수
worker_rlimit_nofile 4096;      # 워커당 열 수 있는 파일 수

events {
    worker_connections 512;      # 워커당 동시 연결 수
    use epoll;                   # Linux 고성능 이벤트 모델
    multi_accept on;             # 한 번에 여러 연결 수락
}
```

**epoll**: Linux에서 네트워크 이벤트를 감지하는 가장 효율적인 방법입니다. 기본 `select`는 연결이 늘어나면 O(n)으로 느려지지만, epoll은 O(1)입니다.

```nginx
upstream django_backend {
    server 127.0.0.1:8000;    # Django 서버 주소
    keepalive 16;              # 연결 재사용 풀
}
```

**upstream**: Nginx가 요청을 전달할 백엔드 서버 그룹입니다. 서버가 여러 대이면 여기에 나열하고 `least_conn;`을 추가하면 로드 밸런싱됩니다.

**keepalive 16**: Nginx ↔ Django 사이의 TCP 연결을 16개까지 유지합니다. 매 요청마다 새 연결을 만들면 TCP 핸드셰이크(3-way)가 반복되어 느립니다.

```nginx
location /static/ {
    alias /home/sckimosu/myproject/staticfiles/;
    expires 30d;
    add_header Cache-Control "public, immutable";
    access_log off;
}
```

**이 설정이 성능에 미치는 영향**: `/static/`으로 시작하는 요청은 Django까지 전달하지 않고 Nginx가 직접 파일을 보냅니다. `expires 30d`는 브라우저가 30일간 이 파일을 캐시하여 서버에 재요청하지 않습니다. `access_log off`는 정적 파일 로그를 남기지 않아 디스크 I/O를 절약합니다.

```nginx
location /api/ {
    limit_req zone=api burst=20 nodelay;  # Rate Limiting
    proxy_pass http://django_backend;      # Django로 전달
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_buffering on;                    # 응답 버퍼링
}
```

**limit_req**: IP당 초당 30개 요청까지 허용하고, 순간적으로 20개까지 초과(burst)를 허용합니다. 이를 넘으면 503 에러를 반환합니다. DDoS 방어의 첫 번째 방어선입니다.

**proxy_set_header X-Real-IP**: Nginx가 중간에 있으므로 Django는 클라이언트 IP 대신 Nginx IP(127.0.0.1)를 보게 됩니다. 이 헤더로 실제 클라이언트 IP를 전달합니다.

**proxy_buffering on**: Nginx가 Django의 응답을 먼저 전부 받고, 클라이언트에게 전송합니다. Django 워커가 느린 클라이언트에 묶이지 않고 빨리 해제됩니다.

---

## 14. locustfile.py — 부하 테스트

```python
from locust import HttpUser, task, between

class WebUser(HttpUser):
    wait_time = between(2, 5)       # 요청 사이 2~5초 대기

    @task(5)                         # 가중치 5 (전체의 5/9 ≈ 56%)
    def view_post_list(self):
        self.client.get("/api/posts/?page=1")

    @task(3)                         # 가중치 3 (전체의 3/9 ≈ 33%)
    def view_health(self):
        self.client.get("/health/")

    @task(1)                         # 가중치 1 (전체의 1/9 ≈ 11%)
    def view_categories(self):
        self.client.get("/api/categories/")
```

**@task(n)의 가중치**: 숫자가 클수록 자주 호출됩니다. 5:3:1이면 post_list가 56%, health가 33%, categories가 11% 비율로 호출됩니다. 실제 서비스의 트래픽 패턴을 모사한 것입니다.

**Locust가 30유저로 실행되면**: 30명의 가짜 사용자가 각각 2~5초 간격으로 위 3개 URL 중 하나를 랜덤(가중치 기반)으로 호출합니다.

---

## 15. .env — 환경변수

```bash
DJANGO_SECRET_KEY=a1b2c3d4e5...    # 세션 암호화 키
DB_PASSWORD=your-secure-password    # DB 비밀번호
REDIS_URL=redis://localhost:6379/0  # Redis 주소
```

**환경변수를 쓰는 이유**:
1. 코드에 비밀번호를 안 넣으므로 Git에 올려도 안전
2. 같은 코드를 개발/프로덕션에서 다른 설정으로 실행 가능
3. 서버별로 .env만 다르게 두면 됨

**`set -a && source .env && set +a`의 의미**:
- `set -a`: 이후 정의되는 변수를 환경변수로 자동 export
- `source .env`: .env 파일의 내용을 현재 셸에 로드
- `set +a`: 자동 export 해제

---

## 전체 요청 흐름 — 코드 레벨

```
사용자: GET http://localhost/api/posts/?page=1

① Nginx (nginx.conf)
   location /api/ 매칭 → limit_req 확인 → proxy_pass http://django_backend

② Gunicorn (gunicorn.conf.py)
   비어있는 Uvicorn 워커에 요청 할당

③ Django URL 라우팅 (config/urls.py)
   path("api/posts/", post_list) 매칭 → post_list 함수 호출

④ Django 뷰 (core/views.py → post_list)
   cache.get("post_list:page:1") → Redis 확인

⑤-A 캐시 히트 (Redis에 데이터 있음)
   → 0.1ms만에 데이터 반환 → JsonResponse 생성

⑤-B 캐시 미스 (Redis에 데이터 없음)
   → DB 라우터 (config/db_router.py)
   → db_for_read() → "replica" 반환
   → PostgreSQL replica에서 SELECT 쿼리 실행 (10~50ms)
   → cache.set()으로 Redis에 5분간 저장
   → JsonResponse 생성

⑥ 응답 역순 전달
   Django → Gunicorn → Nginx(버퍼링) → 사용자 브라우저

결과: {"posts": [...], "page": 1}
```
