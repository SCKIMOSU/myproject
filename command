#!/bin/bash
# ============================================================
# Django 1만 동접 서버 — 동작 순서
# 한 줄씩 터미널에 복사해서 실행
# ============================================================


# ★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★
# 1단계: 프로젝트 생성 + 패키지 설치
# ★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★

cd ~
mkdir myproject
cd myproject
python3 -m venv venv
source venv/bin/activate

sudo pip install \
    django==4.2.20 \
    gunicorn==22.0.0 \
    uvicorn[standard]==0.30.0 \
    psycopg==3.2.13 \
    psycopg-binary==3.2.13 \
    django-redis==5.4.0 \
    celery[redis]==5.4.0 \
    whitenoise==6.7.0 \
    python-json-logger==2.0.7 \
    django-health-check==3.18.3 \
    django-cors-headers==4.4.0

pip freeze > requirements.txt

django-admin startproject config .
python manage.py startapp core


# ★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★
# 2단계: 설정 파일 구조 만들기
# ★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★

mkdir config/settings
touch config/settings/__init__.py
mv config/settings.py config/settings/base.py


# ★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★
# 3단계: 설정 파일 작성 (gedit로 하나씩)
# ★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★

# 3-1. base.py 수정
gedit config/settings/base.py
# → "전체 코드 Part 1"의 base.py 내용으로 전체 교체
# → Ctrl+S 저장 후 닫기

# 3-2. development.py 생성
gedit config/settings/development.py
# → "전체 코드 Part 1"의 development.py 내용 붙여넣기 (주석 # 제거!)
# → Ctrl+S 저장 후 닫기

# 3-3. production.py 생성
gedit config/settings/production.py
# → "전체 코드 Part 1"의 production.py 내용 붙여넣기 (주석 # 제거!)
# → Ctrl+S 저장 후 닫기

# 3-4. asgi.py 수정
gedit config/asgi.py
# → "전체 코드 Part 1"의 asgi.py 내용으로 전체 교체 (주석 # 제거!)
# → Ctrl+S 저장 후 닫기

# 3-5. celery.py 생성
gedit config/celery.py
# → "전체 코드 Part 1"의 celery.py 내용 붙여넣기 (주석 # 제거!)
# → Ctrl+S 저장 후 닫기

# 3-6. config/__init__.py 수정
gedit config/__init__.py
# → 아래 2줄만 입력:
#   from .celery import app as celery_app
#   __all__ = ("celery_app",)
# → Ctrl+S 저장 후 닫기

# 3-7. db_router.py 생성
gedit config/db_router.py
# → "전체 코드 Part 1"의 db_router.py 내용 붙여넣기 (주석 # 제거!)
# → Ctrl+S 저장 후 닫기

# 3-8. urls.py 수정
gedit config/urls.py
# → "전체 코드 Part 1"의 urls.py 내용으로 전체 교체 (주석 # 제거!)
# → Ctrl+S 저장 후 닫기


# ★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★
# 4단계: 앱 코드 작성
# ★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★

# 4-1. models.py
gedit core/models.py
# → "전체 코드 Part 2"의 models.py 내용으로 전체 교체
# → Ctrl+S 저장 후 닫기

# 4-2. views.py
gedit core/views.py
# → "전체 코드 Part 2"의 views.py 내용으로 전체 교체
# → Ctrl+S 저장 후 닫기

# 4-3. tasks.py
gedit core/tasks.py
# → "전체 코드 Part 2"의 tasks.py 내용 붙여넣기
# → Ctrl+S 저장 후 닫기

# 4-4. admin.py
gedit core/admin.py
# → "전체 코드 Part 2"의 admin.py 내용으로 전체 교체
# → Ctrl+S 저장 후 닫기


# ★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★
# 5단계: 필수 폴더 생성 + 개발 서버 테스트
# ★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★

mkdir -p static templates media staticfiles

# DB 마이그레이션
DJANGO_SETTINGS_MODULE=config.settings.development python manage.py makemigrations core
DJANGO_SETTINGS_MODULE=config.settings.development python manage.py migrate

# 관리자 계정 생성
DJANGO_SETTINGS_MODULE=config.settings.development python manage.py createsuperuser
# → 이름, 이메일, 비밀번호 입력

# 개발 서버 실행
DJANGO_SETTINGS_MODULE=config.settings.development python manage.py runserver

# ★ 브라우저에서 확인:
#   http://127.0.0.1:8000/health/    → {"status": "ok"}
#   http://127.0.0.1:8000/admin/     → 관리자 페이지
#   http://127.0.0.1:8000/api/posts/ → {"posts": [], "page": 1}
# → 3개 모두 확인 후 Ctrl+C로 종료


# ★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★
# 6단계: Gunicorn 설정 + 테스트
# ★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★

gedit gunicorn.conf.py
# → "전체 코드 Part 3"의 gunicorn.conf.py 내용 붙여넣기 (주석 # 제거!)
# → Ctrl+S 저장 후 닫기

# Gunicorn으로 실행
DJANGO_SETTINGS_MODULE=config.settings.development \
gunicorn config.asgi:application -c gunicorn.conf.py

# ★ 브라우저: http://127.0.0.1:8000/health/ 확인 후 Ctrl+C 종료


# ★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★
# 7단계: Nginx 설치 + 설정
# ★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★

sudo apt update
sudo apt install -y nginx

# 정적 파일 수집
DJANGO_SETTINGS_MODULE=config.settings.development python manage.py collectstatic --noinput

# Nginx 설정
sudo gedit /etc/nginx/nginx.conf
# → "전체 코드 Part 3"의 nginx.conf 내용으로 전체 교체 (주석 # 제거!)
# → ★ location /static/ 의 alias 경로 확인:
#     alias /home/sckimosu/myproject/staticfiles/;
# → Ctrl+S 저장 후 닫기

# 문법 검사 + 시작
sudo nginx -t
sudo systemctl restart nginx

# Gunicorn 실행
DJANGO_SETTINGS_MODULE=config.settings.development \
gunicorn config.asgi:application -c gunicorn.conf.py

# ★ 브라우저: http://localhost/health/ 확인 (포트 없이 = Nginx 경유)
# → {"status": "ok"} 확인 후 Ctrl+C 종료


# ★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★
# 8단계: Redis 설치
# ★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★

sudo apt install -y redis-server
sudo systemctl start redis-server
sudo systemctl enable redis-server

# 확인
redis-cli ping
# → PONG 나오면 성공


# ★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★
# 9단계: PostgreSQL 설치 + DB 생성
# ★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★

sudo apt install -y postgresql postgresql-contrib
sudo systemctl start postgresql
sudo systemctl enable postgresql

# DB + 사용자 생성 (비밀번호는 본인 것으로 변경!)
sudo -u postgres psql << 'SQL'
CREATE DATABASE mydb;
CREATE USER dbuser WITH PASSWORD 'your-secure-password-here';
ALTER ROLE dbuser SET client_encoding TO 'utf8';
ALTER ROLE dbuser SET default_transaction_isolation TO 'read committed';
ALTER ROLE dbuser SET timezone TO 'Asia/Seoul';
GRANT ALL PRIVILEGES ON DATABASE mydb TO dbuser;
ALTER DATABASE mydb OWNER TO dbuser;
SQL

# 확인
sudo -u postgres psql -c "\l"
# → mydb가 목록에 있으면 성공


# ★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★
# 10단계: 환경변수 설정 + 프로덕션 전환
# ★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★

gedit ~/myproject/.env
# → "전체 코드 Part 3"의 .env 내용 붙여넣기 (비밀번호 변경!)
# → Ctrl+S 저장 후 닫기

# 환경변수 로드
set -a && source .env && set +a

# 프로덕션 마이그레이션
DJANGO_SETTINGS_MODULE=config.settings.production python manage.py migrate

# 관리자 계정 생성 (프로덕션 DB용)
DJANGO_SETTINGS_MODULE=config.settings.production python manage.py createsuperuser

# 정적 파일 수집
DJANGO_SETTINGS_MODULE=config.settings.production python manage.py collectstatic --noinput


# ★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★
# 11단계: 프로덕션 서버 실행 + 전체 동작 확인
# ★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★

# --- 터미널 1: Gunicorn (Django 앱 서버) ---
cd ~/myproject
source venv/bin/activate
set -a && source .env && set +a
DJANGO_SETTINGS_MODULE=config.settings.production \
gunicorn config.asgi:application -c gunicorn.conf.py

# --- 터미널 2: Celery 워커 (Ctrl+Alt+T로 새 터미널) ---
cd ~/myproject
source venv/bin/activate
set -a && source .env && set +a
DJANGO_SETTINGS_MODULE=config.settings.production \
celery -A config worker --loglevel=info
# → "celery@... ready." 나오면 성공

# --- 터미널 3: Celery Beat (Ctrl+Alt+T로 새 터미널) ---
cd ~/myproject
source venv/bin/activate
set -a && source .env && set +a
DJANGO_SETTINGS_MODULE=config.settings.production \
celery -A config beat --loglevel=info

# --- 터미널 4: 확인 (Ctrl+Alt+T로 새 터미널) ---
curl http://localhost/health/
# → {"status": "ok", "database": "ok", "cache": "ok"}

curl http://localhost/api/posts/
# → {"posts": [], "page": 1}

# ★ 브라우저:
#   http://localhost/health/    → DB + 캐시 상태 확인
#   http://localhost/api/posts/ → 게시글 목록
#   http://localhost/admin/     → 관리자 페이지


# ★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★
# 12단계: 커널 튜닝
# ★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★

sudo gedit /etc/sysctl.conf
# → 맨 아래에 아래 내용 추가 (주석 없이 값만!):
#
#   fs.file-max = 2097152
#   net.core.somaxconn = 65535
#   net.core.netdev_max_backlog = 65535
#   net.ipv4.tcp_max_syn_backlog = 65535
#   net.ipv4.tcp_tw_reuse = 1
#   net.ipv4.tcp_fin_timeout = 15
#   net.ipv4.ip_local_port_range = 1024 65535
#   net.ipv4.tcp_keepalive_time = 300
#   net.ipv4.tcp_keepalive_intvl = 30
#   net.ipv4.tcp_keepalive_probes = 5
#   net.core.rmem_max = 16777216
#   net.core.wmem_max = 16777216
#   net.ipv4.tcp_rmem = 4096 87380 16777216
#   net.ipv4.tcp_wmem = 4096 87380 16777216
#
# → Ctrl+S 저장 후 닫기

sudo sysctl -p

# 확인
sysctl net.core.somaxconn
# → net.core.somaxconn = 65535


# ★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★
# 13단계: 부하 테스트
# ★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★

# --- 터미널 4에서 계속 ---
cd ~/myproject
source venv/bin/activate
pip install locust

cat > locustfile.py << 'EOF'
from locust import HttpUser, task, between

class WebUser(HttpUser):
    wait_time = between(1, 3)

    @task(5)
    def view_post_list(self):
        self.client.get("/api/posts/?page=1")

    @task(3)
    def view_health(self):
        self.client.get("/health/")

    @task(1)
    def view_categories(self):
        self.client.get("/api/categories/")
EOF

locust -f locustfile.py --host=http://localhost

# ★ 브라우저: http://localhost:8089
# → Number of users: 100
# → Spawn rate: 10
# → Start 클릭
#
# 확인 포인트:
#   - RPS: 40 이상이면 양호
#   - 평균 응답: 100ms 이하면 양호
#   - 실패율: 5% 이하면 양호


# ★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★
# 최종 상태: 실행 중이어야 하는 것들
# ★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★

# 시스템 서비스 (백그라운드):
#   Nginx       → sudo systemctl status nginx
#   PostgreSQL  → sudo systemctl status postgresql
#   Redis       → sudo systemctl status redis-server

# 터미널 1: Gunicorn (Django 앱 서버)
# 터미널 2: Celery 워커
# 터미널 3: Celery Beat
# 터미널 4: Locust 또는 curl 테스트

# ★ 확인 URL:
#   http://localhost/health/       → DB + 캐시 상태
#   http://localhost/api/posts/    → 게시글 목록
#   http://localhost/admin/        → 관리자 페이지
#   http://localhost:8089          → Locust 부하 테스트 화면
