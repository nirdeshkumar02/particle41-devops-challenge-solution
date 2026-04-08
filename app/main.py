from datetime import datetime, timezone, timedelta

from fastapi import FastAPI, Request

app = FastAPI()

IST = timezone(timedelta(hours=5, minutes=30))


@app.get("/")
async def root(request: Request) -> dict:
    """Return the current IST timestamp and the visitor's IP address.

    The IP is extracted from the X-Forwarded-For header (set by the ALB)
    so the real client IP is returned rather than the ALB's address.
    Falls back to the direct connection address if the header is absent.
    """
    forwarded_for = request.headers.get("x-forwarded-for")
    ip: str = forwarded_for.split(",")[0].strip() if forwarded_for else request.client.host

    return {
        "timestamp": datetime.now(IST).isoformat(),
        "ip": ip,
    }


@app.get("/health")
async def health() -> dict:
    """Health check endpoint used by the ALB target group and container HEALTHCHECK."""
    return {"status": "ok"}
