from fastapi import FastAPI

# Создаем экземпляр приложения. 
# Это "ядро", через которое проходят все запросы.
app = FastAPI()

# Декоратор определяет: 
# 1. Метод (GET)
# 2. Путь ("/")
@app.get("/")
async def root():
    """
    Базовый эндпоинт для проверки работоспособности.
    Возвращает JSON-ответ автоматически.
    """
    return {
        "message": "DevOps Project v1",
        "status": "running"
    }