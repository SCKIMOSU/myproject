import multiprocessing

bind = "0.0.0.0:8000"
workers = 2
worker_class = "uvicorn.workers.UvicornWorker"
worker_connections = 100
max_requests = 1000
max_requests_jitter = 100
timeout = 30
keepalive = 5
graceful_timeout = 30
preload_app = True
accesslog = "-"
errorlog = "-"
loglevel = "info"
access_log_format = '%(h)s %(t)s "%(r)s" %(s)s %(D)s'
