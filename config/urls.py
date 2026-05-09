from django.contrib import admin
from django.urls import path
from core.views import post_list, category_list, post_detail, health_check

urlpatterns = [
    path("admin/", admin.site.urls),
    path("health/", health_check),
    path("api/posts/", post_list),
    path("api/posts/<slug:slug>/", post_detail),
    path("api/categories/", category_list),
]
