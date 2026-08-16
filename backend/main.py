from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from router import router as sessions_router, user_router

app = FastAPI(
    title="ABHAYA Emergency Session Backend API",
    description="Discreet Personal Safety Platform — Emergency Session Orchestration Service",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

# Enable CORS for Flutter web / mobile client requests
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(sessions_router)
app.include_router(user_router)


@app.get("/", tags=["Health Check"])
def health_check():
    return {
        "status": "online",
        "service": "ABHAYA Emergency Session Backend",
        "version": "1.0.0",
        "docs": "/docs",
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
