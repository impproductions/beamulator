#!/bin/bash

# You only need this to run the app locally with a single command.
# Don't bother, use the containerized version

# set venv
python3 -m venv venv
source venv/bin/activate

# install dependencies
pip install -r requirements.txt

uvicorn app:app --reload
