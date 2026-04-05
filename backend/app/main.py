from fastapi import FastAPI, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session
from sqlalchemy import text
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from app.api.routes.auth import router as auth_router
from app.api.routes.sync import router as sync_router
from app.core.config import settings
from app.core.db import get_db
from app.core.limiter import limiter

if not settings.debug and settings.secret_key in ("", "dev-secret"):
    raise RuntimeError(
        "SECRET_KEY must be set to a secure value in .env. "
        "Do not run in production with the default or empty secret key."
    )

app = FastAPI(
    title="Budgy API",
    description="Budget tracker sync API",
    version="1.0.0",
)

app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router)
app.include_router(sync_router)


@app.get("/")
def root():
    return {"message": "Budgy API", "version": "1.0.0"}


@app.get("/health")
def health_check(db: Session = Depends(get_db)):
    try:
        db.execute(text("SELECT 1"))
        return {"status": "healthy", "database": "connected"}
    except Exception as e:
        return JSONResponse(
            status_code=503,
            content={"status": "unhealthy", "database": str(e)},
        )
