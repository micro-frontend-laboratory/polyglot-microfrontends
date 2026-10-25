@echo off
docker compose -f "%~dp0..\..\compose.services.yaml" up --build --detach --wait
docker compose -f "%~dp0..\..\compose.microfrontends.yaml" up --build --detach --wait
docker compose -f "%~dp0..\..\compose.backoffices.yaml" up --build --detach --wait
docker compose -f "%~dp0..\..\compose.edge.yaml" up --build --detach --wait
pause
