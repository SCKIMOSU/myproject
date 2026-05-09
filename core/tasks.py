from celery import shared_task
from django.core.mail import send_mail
from django.core.cache import cache


@shared_task(
    bind=True,
    max_retries=3,
    default_retry_delay=60,
)
def send_notification_email(self, subject, recipient_list):
    try:
        send_mail(
            subject=subject,
            message="새 게시글이 등록되었습니다.",
            from_email="noreply@example.com",
            recipient_list=recipient_list,
        )
    except Exception as exc:
        raise self.retry(exc=exc)


@shared_task
def update_post_view_count(post_id):
    cache_key = f"view_count:{post_id}"
    new_count = cache.incr(cache_key)

    if new_count % 100 == 0:
        from core.models import Post
        Post.objects.filter(pk=post_id).update(view_count=new_count)
