.PHONY: gen gen-watch format analyze test build-android-debug ci

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
