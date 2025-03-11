#!/bin/bash

docker build -t beamulator-example-todo .

docker run -p 8000:8000 beamulator-example-todo