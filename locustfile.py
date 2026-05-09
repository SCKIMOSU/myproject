from locust import HttpUser, task, between


class WebUser(HttpUser):
    wait_time = between(2, 5) # 1~3초 → 2~5초 (요청 빈도 낮춤)

    @task(5)
    def view_post_list(self):
        self.client.get("/api/posts/?page=1")

    @task(3)
    def view_health(self):
        self.client.get("/health/")

    @task(1)
    def view_categories(self):
        self.client.get("/api/categories/")
