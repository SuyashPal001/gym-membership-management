.PHONY: run-web run-web-prod

run-web:
	@echo "Starting Flutter web with port 8080..."
	@echo "IMPORTANT: The OAuth callback redirect_uri is hardcoded to localhost:8080"
	flutter run -d chrome --web-port 8080

run-web-prod:
	@echo "Starting Flutter web pointed at https://gymops.fitnearn.com ..."
	@echo "IMPORTANT: The OAuth callback redirect_uri is hardcoded to localhost:8080"
	flutter run -d chrome --web-port 8080 --dart-define=API_BASE_URL=https://gymops.fitnearn.com/api
