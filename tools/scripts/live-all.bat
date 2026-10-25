@echo off
docker compose -f "%~dp0..\..\compose.services.yaml" up --build --detach --wait
start "shop-services" docker compose -f "%~dp0..\..\compose.services.yaml" watch
start "shop-microfrontends" docker compose -f "%~dp0..\..\compose.microfrontends.yaml" watch
start "shop-backoffices" docker compose -f "%~dp0..\..\compose.backoffices.yaml" watch
start "shop-edge" docker compose -f "%~dp0..\..\compose.edge.yaml" watch
pause
