#!/bin/bash

echo "Creating virtual environment..."
python3 -m venv .venv

echo "Activating virtual environment..."
source .venv/bin/activate

echo "Upgrading pip..."
python -m pip install --upgrade pip

echo "Installing project dependencies..."
python -m pip install -r requirements.txt

echo "Setup complete."
echo "In VS Code, select the Python kernel from .venv."