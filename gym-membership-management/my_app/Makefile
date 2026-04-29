.PHONY: run-web run-web-prod build-release

run-web:
	@echo "Starting Flutter web with port 8080..."
	@echo "IMPORTANT: The OAuth callback redirect_uri is hardcoded to localhost:8080"
	flutter run -d chrome --web-port 8080

build-release:
	@echo "Building signed release AAB..."
	@echo "Reading secrets from secrets.json (gitignored)"
	flutter build appbundle --release --dart-define=API_BASE_URL=https://gymops.fitnearn.com/api --dart-define-from-file=secrets.json
	@echo "Done: build/app/outputs/bundle/release/app-release.aab"

run-web-prod:
	@echo "Starting Flutter web pointed at https://gymops.fitnearn.com ..."
	@echo "IMPORTANT: The OAuth callback redirect_uri is hardcoded to localhost:8080"
	flutter run -d chrome --web-port 8080 --dart-define=API_BASE_URL=https://gymops.fitnearn.com/api
