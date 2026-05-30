"""
CircleGuard Performance & Stress Tests - Locust
Simulates real usage patterns across 6 microservices via the Istio Ingress Gateway.

GKE Run (via Istio gateway):
  export GATEWAY_HOST=http://<ISTIO_INGRESS_IP>
  locust -f locustfile.py --host $GATEWAY_HOST --users 50 --spawn-rate 5 -t 2m
  locust -f locustfile.py --host $GATEWAY_HOST --headless --users 100 --spawn-rate 10 -t 5m --html report.html

Local Run (direct service ports):
  locust -f locustfile.py --host http://localhost:8087 --users 50 --spawn-rate 5 -t 2m

Get the GKE gateway IP:
  kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
"""

import random
import uuid
import json
from locust import HttpUser, TaskSet, task, between, events
from locust.contrib.fasthttp import FastHttpUser


# ─── Form Service (8086) ────────────────────────────────────────────────────

class FormServiceTasks(TaskSet):
    """Simulates students submitting health surveys."""

    def on_start(self):
        self.anon_id = str(uuid.uuid4())

    @task(5)
    def submit_healthy_survey(self):
        """Most common flow: student reports no symptoms."""
        payload = {
            "anonymousId": self.anon_id,
            "hasFever": False,
            "hasCough": False,
            "responses": {}
        }
        with self.client.post(
            "/api/v1/surveys",
            json=payload,
            catch_response=True,
            name="POST /surveys [healthy]"
        ) as resp:
            if resp.status_code == 200:
                resp.success()
            else:
                resp.failure(f"Expected 200, got {resp.status_code}")

    @task(2)
    def submit_symptomatic_survey(self):
        """Less common: student reports fever/cough – triggers Kafka event."""
        payload = {
            "anonymousId": str(uuid.uuid4()),
            "hasFever": True,
            "hasCough": True,
            "otherSymptoms": "sore throat",
            "responses": {}
        }
        with self.client.post(
            "/api/v1/surveys",
            json=payload,
            catch_response=True,
            name="POST /surveys [symptomatic]"
        ) as resp:
            if resp.status_code == 200:
                resp.success()
            else:
                resp.failure(f"Expected 200, got {resp.status_code}")

    @task(3)
    def get_pending_surveys(self):
        """Admins checking pending certificate validations."""
        with self.client.get(
            "/api/v1/surveys/pending",
            catch_response=True,
            name="GET /surveys/pending"
        ) as resp:
            if resp.status_code in (200, 403):
                resp.success()
            else:
                resp.failure(f"Unexpected status: {resp.status_code}")

    @task(1)
    def get_questionnaires(self):
        """Students fetching the active questionnaire."""
        with self.client.get(
            "/api/v1/questionnaires/active",
            catch_response=True,
            name="GET /questionnaires/active"
        ) as resp:
            if resp.status_code in (200, 404):
                resp.success()
            else:
                resp.failure(f"Unexpected status: {resp.status_code}")


# ─── File Service (8085) ────────────────────────────────────────────────────

class FileServiceTasks(TaskSet):
    """Simulates certificate/document uploads."""

    @task(8)
    def upload_small_pdf(self):
        """Typical certificate upload (~10KB)."""
        fake_pdf = b"%PDF-1.4 " + b"x" * 10_000
        files = {"file": ("certificate.pdf", fake_pdf, "application/pdf")}
        with self.client.post(
            "/api/v1/files/upload",
            files=files,
            catch_response=True,
            name="POST /files/upload [pdf]"
        ) as resp:
            if resp.status_code == 200:
                data = resp.json()
                if "filename" not in data:
                    resp.failure("Missing 'filename' in response")
                else:
                    resp.success()
            else:
                resp.failure(f"Upload failed: {resp.status_code}")

    @task(2)
    def upload_image(self):
        """Image certificate upload (~50KB)."""
        fake_img = bytes([0xFF, 0xD8, 0xFF, 0xE0]) + b"x" * 50_000
        files = {"file": ("photo-id.jpg", fake_img, "image/jpeg")}
        with self.client.post(
            "/api/v1/files/upload",
            files=files,
            catch_response=True,
            name="POST /files/upload [image]"
        ) as resp:
            if resp.status_code == 200:
                resp.success()
            else:
                resp.failure(f"Upload failed: {resp.status_code}")


# ─── Dashboard Service (8084) ───────────────────────────────────────────────

class DashboardServiceTasks(TaskSet):
    """Simulates admin/public dashboard queries."""

    @task(5)
    def get_health_board(self):
        with self.client.get(
            "/api/v1/analytics/health-board",
            catch_response=True,
            name="GET /analytics/health-board"
        ) as resp:
            if resp.status_code in (200, 503):
                resp.success()
            else:
                resp.failure(f"Status: {resp.status_code}")

    @task(3)
    def get_time_series(self):
        period = random.choice(["hourly", "daily"])
        limit = random.choice([12, 24, 48])
        with self.client.get(
            f"/api/v1/analytics/time-series?period={period}&limit={limit}",
            catch_response=True,
            name="GET /analytics/time-series"
        ) as resp:
            if resp.status_code == 200:
                resp.success()
            else:
                resp.failure(f"Status: {resp.status_code}")

    @task(2)
    def get_department_stats(self):
        dept = random.choice(["CS", "MATH", "ENG", "BIO", "MED"])
        with self.client.get(
            f"/api/v1/analytics/department/{dept}",
            catch_response=True,
            name="GET /analytics/department/{dept}"
        ) as resp:
            if resp.status_code == 200:
                resp.success()
            else:
                resp.failure(f"Status: {resp.status_code}")

    @task(1)
    def get_entry_trends(self):
        location_id = str(uuid.uuid4())
        with self.client.get(
            f"/api/v1/analytics/trends/{location_id}",
            catch_response=True,
            name="GET /analytics/trends/{id}"
        ) as resp:
            if resp.status_code == 200:
                resp.success()
            else:
                resp.failure(f"Status: {resp.status_code}")


# ─── Auth Service (8180) ────────────────────────────────────────────────────

class AuthServiceTasks(TaskSet):
    """Simulates login and visitor handoff flows."""

    @task(4)
    def visitor_handoff(self):
        """Visitor generating anonymous token."""
        payload = {"anonymousId": str(uuid.uuid4())}
        with self.client.post(
            "/api/v1/auth/visitor/handoff",
            json=payload,
            catch_response=True,
            name="POST /auth/visitor/handoff"
        ) as resp:
            if resp.status_code == 200:
                resp.success()
            else:
                resp.failure(f"Handoff failed: {resp.status_code}")

    @task(6)
    def login_invalid(self):
        """Simulates load from failed login attempts."""
        payload = {"username": f"user{random.randint(1,10000)}", "password": "wrong"}
        with self.client.post(
            "/api/v1/auth/login",
            json=payload,
            catch_response=True,
            name="POST /auth/login [invalid]"
        ) as resp:
            if resp.status_code in (200, 401):
                resp.success()
            else:
                resp.failure(f"Unexpected status: {resp.status_code}")


# ─── User classes (configure target host per run) ───────────────────────────

class FormServiceUser(HttpUser):
    """Targets form-service at port 8086."""
    host = "http://localhost:8086"
    tasks = [FormServiceTasks]
    wait_time = between(0.5, 2)


class FileServiceUser(HttpUser):
    """Targets file-service at port 8085."""
    host = "http://localhost:8085"
    tasks = [FileServiceTasks]
    wait_time = between(1, 3)


class DashboardUser(HttpUser):
    """Targets dashboard-service at port 8084."""
    host = "http://localhost:8084"
    tasks = [DashboardServiceTasks]
    wait_time = between(0.5, 1.5)


class AuthUser(HttpUser):
    """Targets auth-service at port 8180."""
    host = "http://localhost:8180"
    tasks = [AuthServiceTasks]
    wait_time = between(0.5, 2)
