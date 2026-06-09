"""
CircleGuard Multi-Cloud Performance Comparison
===============================================
Single-endpoint locustfile for comparing GCP prod vs DigitalOcean prod latency.

Targets auth-service via kubectl port-forward (port 8180 on both clouds).
Endpoints chosen because they always return 200/401 (no Kafka/external deps needed).

Usage:
  # GCP prod (port-forward running on :8180)
  locust -f locustfile_comparison.py --host http://localhost:8180 \
         --headless -u 50 -r 5 --run-time 2m \
         --html tests/performance/results-gcp-prod.html \
         --csv tests/performance/results-gcp-prod

  # DO prod (port-forward running on :8180)
  locust -f locustfile_comparison.py --host http://localhost:8180 \
         --headless -u 50 -r 5 --run-time 2m \
         --html tests/performance/results-do-prod.html \
         --csv tests/performance/results-do-prod

Port-forward commands:
  GCP: KUBECONFIG=~/.kube/circleguard-prod \
       kubectl port-forward -n circleguard-production svc/auth-service 8180:8180
  DO:  KUBECONFIG=~/.kube/circleguard-do-prod \
       kubectl port-forward -n circleguard-do-prod svc/auth-service 8180:8180
"""

import random
import uuid
from locust import HttpUser, task, between, events


class AuthServiceUser(HttpUser):
    """
    Simulates concurrent auth requests against a single auth-service instance.
    Uses login (DB read + bcrypt/JWT) and visitor handoff (UUID token gen).
    Both endpoints always return 200 or 401 — never timeout-fail due to missing deps.
    """
    wait_time = between(0.5, 2.0)

    @task(6)
    def login_attempt(self):
        """POST /api/v1/auth/login — exercises DB read + credential check."""
        payload = {
            "username": f"user{random.randint(1, 10000)}",
            "password": "testpassword"
        }
        with self.client.post(
            "/api/v1/auth/login",
            json=payload,
            catch_response=True,
            name="POST /auth/login"
        ) as resp:
            if resp.status_code in (200, 401, 403):
                resp.success()
            else:
                resp.failure(f"Unexpected {resp.status_code}")

    @task(4)
    def visitor_handoff(self):
        """POST /api/v1/auth/visitor/handoff — generates anonymous session token."""
        payload = {"anonymousId": str(uuid.uuid4())}
        with self.client.post(
            "/api/v1/auth/visitor/handoff",
            json=payload,
            catch_response=True,
            name="POST /auth/visitor/handoff"
        ) as resp:
            if resp.status_code in (200, 201, 401, 403):
                resp.success()
            else:
                resp.failure(f"Unexpected {resp.status_code}")


@events.quitting.add_listener
def on_quitting(environment, **kwargs):
    if environment.stats.total.fail_ratio > 0.20:
        environment.process_exit_code = 1
