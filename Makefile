.PHONY: gen gen-watch format analyze test build-android-debug build-android-release-arm64 ci

gen:
	dart run build_runner build --delete-conflicting-outputs

gen-watch:
	dart run build_runner watch --delete-conflicting-outputs

format:
	dart format .

analyze:
	dart analyze --fatal-infos

test:
	flutter test

build-android-debug:
	flutter build apk --debug --no-shrink

ci: format gen analyze test build-android-debug

build-android-release-arm64:
	flutter build apk --split-per-abi --target-platform android-arm64
