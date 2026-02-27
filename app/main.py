import os
from fastapi import FastAPI
from sqlalchemy import create_engine, text
from prometheus_fastapi_instrumentator import Instrumentator


app = FastAPI()

@app.on_event("startup")
async def startup():
    Instrumentator().instrument(app).expose(app)

# Получаем данные из переменных окружения (их передаст Docker/Terraform)
DB_USER = os.getenv("DB_USER", "psqladmin")
DB_PASSWORD = os.getenv("DB_PASSWORD")
DB_HOST = os.getenv("DB_HOST")
DB_NAME = os.getenv("DB_NAME", "fastapi_db")

# Формируем строку подключения
DATABASE_URL = f"postgresql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}/{DB_NAME}"

@app.get("/")
def read_root():
    return {"status": "App is running", "database_host": DB_HOST}

@app.get("/db_check")
def check_db():
    try:
        # Создаем подключение и пробуем выполнить простейший запрос
        engine = create_engine(DATABASE_URL)
        with engine.connect() as connection:
            result = connection.execute(text("SELECT version();"))
            version = result.fetchone()
        return {"status": "Connected", "db_version": version[0]}
    except Exception as e:
        return {"status": "Error", "details": str(e)}