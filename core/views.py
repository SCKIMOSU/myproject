from django.core.cache import cache
from django.views.decorators.cache import cache_page
from django.http import JsonResponse
from django.db.models import Count, Prefetch
from .models import Post, Comment, Category


def post_list(request):
    page = int(request.GET.get("page", 1))
    cache_key = f"post_list:page:{page}"

    data = cache.get(cache_key)

    if data is None:
        per_page = 20
        offset = (page - 1) * per_page

        posts = (
            Post.objects
            .select_related("author", "category")
            .prefetch_related("tags")
            .annotate(comment_count=Count("comments"))
            .only("id", "title", "slug", "created_at",
                  "author__username", "category__name")
            .order_by("-created_at")
            [offset:offset + per_page]
        )

        data = [
            {
                "id": post.id,
                "title": post.title,
                "slug": post.slug,
                "author": post.author.username,
                "category": post.category.name,
                "tags": [tag.name for tag in post.tags.all()],
                "comment_count": post.comment_count,
                "created_at": post.created_at.isoformat(),
            }
            for post in posts
        ]

        cache.set(cache_key, data, timeout=300)

    return JsonResponse({"posts": data, "page": page})


@cache_page(60 * 5)
def category_list(request):
    categories = Category.objects.annotate(
        post_count=Count("posts")
    ).values("id", "name", "slug", "post_count")

    return JsonResponse({"categories": list(categories)})


def post_detail(request, slug):
    cache_key = f"post_detail:{slug}"
    data = cache.get(cache_key)

    if data is None:
        post = (
            Post.objects
            .select_related("author", "category")
            .prefetch_related(
                Prefetch(
                    "comments",
                    queryset=Comment.objects
                        .select_related("author")
                        .order_by("-created_at")[:50],
                )
            )
            .get(slug=slug)
        )

        data = {
            "id": post.id,
            "title": post.title,
            "content": post.content,
            "author": post.author.username,
            "category": post.category.name,
            "comments": [
                {
                    "author": c.author.username,
                    "content": c.content,
                    "created_at": c.created_at.isoformat(),
                }
                for c in post.comments.all()
            ],
        }

        cache.set(cache_key, data, timeout=600)

    return JsonResponse(data)


def health_check(request):
    health = {"status": "ok"}

    try:
        from django.db import connection
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
        health["database"] = "ok"
    except Exception as e:
        health["database"] = f"error: {e}"
        health["status"] = "error"

    try:
        cache.set("_health_check", "1", timeout=10)
        if cache.get("_health_check") == "1":
            health["cache"] = "ok"
        else:
            health["cache"] = "error: read failed"
            health["status"] = "error"
    except Exception as e:
        health["cache"] = f"error: {e}"
        health["status"] = "error"

    status_code = 200 if health["status"] == "ok" else 503
    return JsonResponse(health, status=status_code)
