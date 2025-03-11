#!/bin/bash

docker build -t example-todo-multi .

docker run -p 8080:8080 example-todo-multi