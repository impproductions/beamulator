import asyncio
import time
from fastapi import FastAPI, HTTPException
from fastapi.staticfiles import StaticFiles
from fastapi.responses import JSONResponse, FileResponse
from pydantic import BaseModel
from typing import List
import uuid

app = FastAPI()

# Mount static files (HTML & CSS)
app.mount("/static", StaticFiles(directory="static"), name="static")

# In-memory task storage
tasks = []

# Task model
class Task(BaseModel):
    id: str
    title: str
    completed: bool = False

# Serve the main HTML file
@app.get("/")
async def serve_ui():
    return FileResponse("static/index.html")

# Get all tasks
@app.get("/tasks", response_model=List[Task])
async def get_tasks():
    return tasks

# Add a task
@app.post("/tasks", response_model=Task)
async def add_task(task: Task):
    task.id = str(uuid.uuid4())  # Generate unique ID
    tasks.append(task)
    return task

# Update a task
@app.put("/tasks/{task_id}", response_model=Task)
async def update_task(task_id: str, updated_task: Task):
    for task in tasks:
        if task.id == task_id:
            task.title = updated_task.title
            task.completed = updated_task.completed
            await asyncio.sleep(0.5)
            return task
    raise HTTPException(status_code=404, detail="Task not found")
    

# Delete a task
@app.delete("/tasks/{task_id}")
async def delete_task(task_id: str):
    global tasks
    tasks = [task for task in tasks if task.id != task_id]
    return JSONResponse(content={"message": "Task deleted"})
