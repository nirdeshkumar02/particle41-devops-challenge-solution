from datetime import datetime, timezone, timedelta

from fastapi import FastAPI, Request

app = FastAPI()

IST = timezone(timedelta(hours=5, minutes=30))


@app.get("/")
async def root(request: Request):
    # Prefer X-Forwarded-For set by the load balancer; fall back to direct client host
    forwarded_for = request.headers.get("x-forwarded-for")
    ip = forwarded_for.split(",")[0].strip() if forwarded_for else request.client.host

    return {
        "timestamp": datetime.now(IST).strftime("%Y-%m-%d %H:%M:%S"),
        "ip": ip,
    }


@app.get("/health")
async def health():
    return {"status": "ok"}
