# app/api/routes/health.py

import os
from fastapi import APIRouter, Response, status
from app.services.db_service import DatabaseService

router = APIRouter()

@router.get("/health")
def health(response: Response):
    db_up = DatabaseService.is_healthy()
    
    payload = {
        "status": "healthy" if db_up else "unhealthy",
        "service": "crypto-market-server",
        "version": os.getenv("APP_VERSION", "1.0.0"),
        "checks": {
            "database": {
                "status": "connected" if db_up else "disconnected"
            }
        }
    }
    
    if not db_up:
        response.status_code = status.HTTP_503_SERVICE_UNAVAILABLE
    else:
        response.status_code = status.HTTP_200_OK
        
    return payload

@router.get("/simulate-500")
def simulate_incident():
    # Intentional 500 endpoint for Craon SRE Incident drill and CloudWatch alarm testing
    raise RuntimeError("Simulated 500 Server Error for Craon DevOps Assignment Part 6")
