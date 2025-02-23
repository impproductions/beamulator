#!/bin/bash

# set venv
python3 -m venv venv
source venv/bin/activate

# install dependencies
pip install -r requirements.txt

uvicorn app:app --reload
